#!/usr/bin/env python3
"""
End-to-end data pipeline deployment:
1) Upload employee docs to Blob Storage
2) Process docs with Azure AI Document Intelligence
3) Store parsing output in Cosmos DB
4) Build/update Azure AI Search indexes and push chunked docs

Requirements:
  pip install azure-storage-blob azure-cosmos azure-search-documents requests

Auth:
  - Storage/Search/Cosmos use account keys pulled from env vars
  - Document Intelligence uses Entra bearer token from: az account get-access-token --resource https://cognitiveservices.azure.com
"""

from __future__ import annotations

import base64
import argparse
import json
import os
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import requests
from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import HttpResponseError
from azure.cosmos import CosmosClient, PartitionKey
from azure.cosmos.exceptions import CosmosHttpResponseError
from azure.identity import AzureCliCredential, DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    HnswAlgorithmConfiguration,
    SearchField,
    SearchFieldDataType,
    SearchIndex,
    SearchableField,
    SemanticConfiguration,
    SemanticField,
    SemanticPrioritizedFields,
    SemanticSearch,
    SimpleField,
    VectorSearch,
    VectorSearchProfile,
)
from azure.storage.blob import BlobServiceClient

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "data"
EMP_DIR = DATA_DIR / "employees"
SERVICE_CFG = REPO_ROOT / "config" / "service-config.json"
ENDPOINTS_CFG = REPO_ROOT / "config" / "endpoints.json"

DOC_RESULTS_FILE = DATA_DIR / "document_intelligence_results.json"
PARSED_FILE = DATA_DIR / "parsed_documents_cosmosdb.json"

# Extensions that are usually accepted by prebuilt-layout. Others are handled via fallback parsing.
DOCINTEL_SUPPORTED_EXTENSIONS = {".pdf", ".docx", ".xlsx", ".pptx", ".jpg", ".jpeg", ".png", ".tif", ".tiff", ".bmp"}


@dataclass
class Config:
    storage_account: str
    storage_key: str | None
    storage_account_url: str
    storage_container: str
    cosmos_endpoint: str
    cosmos_key: str | None
    cosmos_db: str
    cosmos_container: str
    search_endpoint: str
    search_key: str
    search_json_index: str
    search_doc_index: str
    docintel_endpoint: str
    docintel_api_version: str


def load_cfg() -> Config:
    with SERVICE_CFG.open("r", encoding="utf-8") as f:
        cfg = json.load(f)
    with ENDPOINTS_CFG.open("r", encoding="utf-8") as f:
        endpoints_cfg = json.load(f)

    configured_blob_endpoint = endpoints_cfg.get("azure", {}).get("blobStorageEndpoint", "")
    endpoint_account_name = ""
    if configured_blob_endpoint:
        endpoint_account_name = configured_blob_endpoint.replace("https://", "").split(".")[0]

    account_name = os.environ.get("AZ_STORAGE_ACCOUNT") or endpoint_account_name
    if not account_name:
        raise RuntimeError("Unable to resolve storage account name from env or config/endpoints.json")

    configured_account_url = os.environ.get("AZ_STORAGE_ACCOUNT_URL")
    if not configured_account_url:
        configured_account_url = configured_blob_endpoint or f"https://{account_name}.blob.core.windows.net"

    # Keep the public blob FQDN for TLS while letting Private DNS resolve it to the PE IP.
    configured_account_url = configured_account_url.replace(
        ".privatelink.blob.core.windows.net", ".blob.core.windows.net"
    ).rstrip("/")

    return Config(
        storage_account=account_name,
        storage_key=os.environ.get("AZ_STORAGE_KEY"),
        storage_account_url=configured_account_url,
        storage_container=cfg["documentIntelligence"]["storageContainer"],
        cosmos_endpoint=cfg["cosmosDb"]["endpoint"],
        cosmos_key=os.environ.get("AZ_COSMOS_KEY"),
        cosmos_db=cfg["cosmosDb"]["databaseName"],
        cosmos_container=cfg["cosmosDb"]["containers"]["documentParsing"],
        search_endpoint=cfg["aiSearch"]["endpoint"],
        search_key=os.environ["AZ_SEARCH_ADMIN_KEY"],
        search_json_index=os.environ.get("AZ_SEARCH_JSON_INDEX", cfg["aiSearch"].get("jsonIndexName", cfg["aiSearch"]["indexName"])),
        search_doc_index=os.environ.get("AZ_SEARCH_DOC_INDEX", cfg["aiSearch"].get("docIndexName", cfg["aiSearch"]["indexName"])),
        docintel_endpoint=cfg["documentIntelligence"]["endpoint"].rstrip("/"),
        docintel_api_version=cfg["documentIntelligence"]["apiVersion"],
    )


def get_docintel_token() -> str:
    az_exe = shutil.which("az") or shutil.which("az.cmd") or "az"
    cmd = [
        az_exe,
        "account",
        "get-access-token",
        "--resource",
        "https://cognitiveservices.azure.com",
        "--query",
        "accessToken",
        "-o",
        "tsv",
    ]
    token = subprocess.check_output(cmd, text=True).strip()
    if not token:
        raise RuntimeError("Unable to acquire Document Intelligence AAD token")
    return token


def iter_documents() -> List[Path]:
    allowed = {".pdf", ".docx", ".pptx", ".xlsx", ".txt", ".md", ".csv", ".eml", ".one"}
    docs: List[Path] = []
    for p in EMP_DIR.rglob("*"):
        if p.is_file() and p.suffix.lower() in allowed:
            docs.append(p)
    return docs


def is_docintel_candidate(path: Path) -> bool:
    return path.suffix.lower() in DOCINTEL_SUPPORTED_EXTENSIONS


def upload_to_blob(cfg: Config, docs: List[Path]) -> Dict[str, str]:
    account_url = cfg.storage_account_url
    service = BlobServiceClient(account_url=account_url, credential=cfg.storage_key or DefaultAzureCredential())
    container = service.get_container_client(cfg.storage_container)
    try:
        container.create_container()
    except Exception:
        pass

    blob_urls: Dict[str, str] = {}
    for p in docs:
        rel = p.relative_to(EMP_DIR).as_posix()
        try:
            with p.open("rb") as f:
                container.upload_blob(name=rel, data=f, overwrite=True)
            blob_urls[str(p)] = f"{account_url}/{cfg.storage_container}/{rel}"
            continue
        except Exception as ex:
            msg = str(ex)
            # Retry with Azure CLI identity when key auth is blocked or insufficient.
            if "KeyBasedAuthenticationNotPermitted" in msg or "AuthorizationFailure" in msg:
                try:
                    service = BlobServiceClient(account_url=account_url, credential=AzureCliCredential())
                    container = service.get_container_client(cfg.storage_container)
                    with p.open("rb") as f:
                        container.upload_blob(name=rel, data=f, overwrite=True)
                    blob_urls[str(p)] = f"{account_url}/{cfg.storage_container}/{rel}"
                    continue
                except Exception as inner_ex:
                    print(f"WARN blob upload failed for {rel}: {inner_ex}")
            else:
                print(f"WARN blob upload failed for {rel}: {ex}")

            # Continue pipeline using local reference when blob upload is unavailable.
            blob_urls[str(p)] = f"local://{rel}"
    return blob_urls


def _submit_with_retry(url: str, headers: dict, payload: bytes, max_attempts: int = 6) -> requests.Response:
    delay = 1.0
    for attempt in range(1, max_attempts + 1):
        resp = requests.post(url, headers=headers, data=payload, timeout=120)
        if resp.status_code != 429:
            return resp

        retry_after = resp.headers.get("Retry-After")
        wait = float(retry_after) if retry_after and retry_after.isdigit() else delay
        print(f"WARN doc intel submit throttled (attempt {attempt}/{max_attempts}); sleeping {wait:.1f}s")
        time.sleep(wait)
        delay = min(delay * 2, 30)

    return resp


def _poll_with_retry(op_loc: str, headers: dict, max_polls: int = 160) -> dict:
    delay = 2.0
    for _ in range(max_polls):
        r = requests.get(op_loc, headers=headers, timeout=60)
        if r.status_code == 429:
            retry_after = r.headers.get("Retry-After")
            wait = float(retry_after) if retry_after and retry_after.isdigit() else delay
            print(f"WARN doc intel poll throttled; sleeping {wait:.1f}s")
            time.sleep(wait)
            delay = min(delay * 1.5, 30)
            continue

        r.raise_for_status()
        payload = r.json()
        status = payload.get("status")
        if status == "succeeded":
            return payload
        if status == "failed":
            raise RuntimeError("Doc Intel analysis failed")
        time.sleep(2)

    raise TimeoutError("Doc Intel polling timeout")


def analyze_document(cfg: Config, token: str, path: Path) -> dict:
    url = (
        f"{cfg.docintel_endpoint}/documentintelligence/documentModels/prebuilt-layout:analyze"
        f"?api-version={cfg.docintel_api_version}"
    )
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/octet-stream",
    }
    with path.open("rb") as f:
        resp = _submit_with_retry(url, headers, f.read())
    resp.raise_for_status()

    op_loc = resp.headers.get("operation-location")
    if not op_loc:
        raise RuntimeError(f"Missing operation-location for {path}")

    poll_headers = {"Authorization": f"Bearer {token}"}
    try:
        return _poll_with_retry(op_loc, poll_headers)
    except TimeoutError:
        raise TimeoutError(f"Doc Intel polling timeout for {path}")


def normalize_doc_result(path: Path, blob_url: str, payload: dict) -> dict:
    analyze = payload.get("analyzeResult", {})
    paragraphs = analyze.get("paragraphs", [])
    text = "\n".join(str(p.get("content", "")) for p in paragraphs if p.get("content"))
    text = text.strip()

    parts = path.relative_to(EMP_DIR).as_posix().split("/")
    employee_id = parts[0] if parts else "UNKNOWN"

    doc_id = f"DOC-{employee_id}-{path.stem}"
    return {
        "id": doc_id,
        "documentId": doc_id,
        "employeeId": employee_id,
        "fileName": path.name,
        "format": path.suffix.lower().lstrip("."),
        "blobUrl": blob_url,
        "extractedText": text[:200000],
        "paragraphCount": len(paragraphs),
        "tableCount": len(analyze.get("tables", [])),
        "language": (analyze.get("languages", [{}])[0].get("locale") if analyze.get("languages") else "unknown"),
        "confidence": 0.9,
    }


def fallback_normalize_doc(path: Path, blob_url: str, reason: str) -> dict:
    parts = path.relative_to(EMP_DIR).as_posix().split("/")
    employee_id = parts[0] if parts else "UNKNOWN"
    doc_id = f"DOC-{employee_id}-{path.stem}"

    text = ""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore").strip()
    except Exception:
        text = ""

    if not text:
        # Keep a small payload for binary formats where text extraction fails.
        text = f"Binary document placeholder for {path.name}. Parse fallback reason: {reason}"

    return {
        "id": doc_id,
        "documentId": doc_id,
        "employeeId": employee_id,
        "fileName": path.name,
        "format": path.suffix.lower().lstrip("."),
        "blobUrl": blob_url,
        "extractedText": text[:200000],
        "paragraphCount": 0,
        "tableCount": 0,
        "language": "unknown",
        "confidence": 0.0,
        "parseFallback": True,
        "parseError": reason[:1000],
    }


def upsert_cosmos(cfg: Config, docs: List[dict]):
    # In App Service private-path execution, prefer managed identity first.
    if os.environ.get("WEBSITE_INSTANCE_ID"):
        client = CosmosClient(cfg.cosmos_endpoint, credential=DefaultAzureCredential())
    elif cfg.cosmos_key:
        try:
            client = CosmosClient(cfg.cosmos_endpoint, credential=cfg.cosmos_key)
            # Probe account to fail fast on local-auth-disabled accounts.
            list(client.list_databases())
        except CosmosHttpResponseError as ex:
            if "Local Authorization is disabled" not in str(ex):
                raise
            client = CosmosClient(cfg.cosmos_endpoint, credential=AzureCliCredential())
    else:
        client = CosmosClient(cfg.cosmos_endpoint, credential=AzureCliCredential())

    db = client.create_database_if_not_exists(id=cfg.cosmos_db)
    container = db.create_container_if_not_exists(
        id=cfg.cosmos_container,
        partition_key=PartitionKey(path="/employeeId"),
        offer_throughput=400,
    )
    for d in docs:
        container.upsert_item(d)


def chunk_text(text: str, chunk_size: int = 1200, overlap: int = 200) -> List[str]:
    if not text:
        return []
    chunks: List[str] = []
    i = 0
    while i < len(text):
        chunks.append(text[i : i + chunk_size])
        i += max(1, chunk_size - overlap)
    return chunks


def ensure_search_indexes(cfg: Config):
    idx_client = SearchIndexClient(cfg.search_endpoint, AzureKeyCredential(cfg.search_key))

    vector_search = VectorSearch(
        algorithms=[HnswAlgorithmConfiguration(name="hnsw-config")],
        profiles=[VectorSearchProfile(name="vec-profile", algorithm_configuration_name="hnsw-config")],
    )

    json_fields = [
        SimpleField(name="id", type=SearchFieldDataType.String, key=True),
        SimpleField(name="documentId", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="employeeId", type=SearchFieldDataType.String, filterable=True, facetable=True),
        SearchableField(name="fileName", type=SearchFieldDataType.String),
        SearchableField(name="chunk", type=SearchFieldDataType.String),
        SimpleField(name="chunkIndex", type=SearchFieldDataType.Int32, filterable=True),
        SimpleField(name="format", type=SearchFieldDataType.String, filterable=True, facetable=True),
        SearchField(
            name="chunkVector",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=1536,
            vector_search_profile_name="vec-profile",
        ),
    ]

    doc_fields = [
        SimpleField(name="id", type=SearchFieldDataType.String, key=True),
        SimpleField(name="documentId", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="employeeId", type=SearchFieldDataType.String, filterable=True, facetable=True),
        SearchableField(name="fileName", type=SearchFieldDataType.String),
        SearchableField(name="extractedText", type=SearchFieldDataType.String),
        SimpleField(name="format", type=SearchFieldDataType.String, filterable=True, facetable=True),
        SimpleField(name="confidence", type=SearchFieldDataType.Double, filterable=True),
    ]

    json_index = SearchIndex(
        name=cfg.search_json_index,
        fields=json_fields,
        vector_search=vector_search,
        semantic_search=SemanticSearch(
            configurations=[
                SemanticConfiguration(
                    name="default",
                    prioritized_fields=SemanticPrioritizedFields(
                        content_fields=[SemanticField(field_name="chunk")]
                    ),
                )
            ]
        ),
    )

    doc_index = SearchIndex(name=cfg.search_doc_index, fields=doc_fields)

    for idx in (json_index, doc_index):
        try:
            idx_client.create_or_update_index(idx)
        except Exception as ex:
            raise RuntimeError(f"Failed to create/update index {idx.name}: {ex}") from ex


def fake_vector(text: str) -> List[float]:
    # Deterministic lightweight placeholder vector for demo indexing.
    seed = sum(text.encode("utf-8")) % 997
    out: List[float] = []
    v = seed / 997.0
    for _ in range(1536):
        v = (v * 1.61803398875) % 1.0
        out.append(v)
    return out


def push_search_docs(cfg: Config, docs: List[dict]):
    json_client = SearchClient(cfg.search_endpoint, cfg.search_json_index, AzureKeyCredential(cfg.search_key))
    doc_client = SearchClient(cfg.search_endpoint, cfg.search_doc_index, AzureKeyCredential(cfg.search_key))

    base_docs = []
    chunk_docs = []

    for d in docs:
        base_docs.append(
            {
                "id": d["id"],
                "documentId": d["documentId"],
                "employeeId": d["employeeId"],
                "fileName": d["fileName"],
                "extractedText": d.get("extractedText", ""),
                "format": d.get("format", ""),
                "confidence": float(d.get("confidence", 0.0)),
            }
        )

        chunks = chunk_text(d.get("extractedText", ""))
        for i, c in enumerate(chunks):
            chunk_docs.append(
                {
                    "id": f"{d['id']}-chunk-{i}",
                    "documentId": d["documentId"],
                    "employeeId": d["employeeId"],
                    "fileName": d["fileName"],
                    "chunk": c,
                    "chunkIndex": i,
                    "format": d.get("format", ""),
                    "chunkVector": fake_vector(c),
                }
            )

    if base_docs:
        doc_client.upload_documents(base_docs)
    if chunk_docs:
        # Batch in chunks to avoid payload limits
        step = 500
        for i in range(0, len(chunk_docs), step):
            json_client.upload_documents(chunk_docs[i : i + step])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Deploy and populate AI data pipeline")
    parser.add_argument(
        "--max-docs",
        type=int,
        default=0,
        help="Optional cap on number of documents to process (0 means all)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    cfg = load_cfg()

    docs = iter_documents()
    if args.max_docs and args.max_docs > 0:
        docs = docs[: args.max_docs]
    if not docs:
        print("No input documents found under data/employees")
        return 1

    print(f"Discovered documents: {len(docs)}")

    blob_urls = upload_to_blob(cfg, docs)
    print(f"Uploaded to blob: {len(blob_urls)}")

    token = get_docintel_token()

    results: List[dict] = []
    normalized: List[dict] = []

    for idx, p in enumerate(docs, start=1):
        try:
            if not is_docintel_candidate(p):
                raise RuntimeError(f"unsupported-format-for-docintel:{p.suffix.lower()}")
            payload = analyze_document(cfg, token, p)
            results.append(payload)
            normalized.append(normalize_doc_result(p, blob_urls[str(p)], payload))
            if idx % 20 == 0:
                print(f"Processed with Doc Intelligence: {idx}/{len(docs)}")
        except Exception as ex:
            print(f"WARN doc intel failed for {p.name}: {ex}")
            normalized.append(fallback_normalize_doc(p, blob_urls[str(p)], str(ex)))

    DOC_RESULTS_FILE.write_text(json.dumps(results, indent=2), encoding="utf-8")
    PARSED_FILE.write_text(json.dumps(normalized, indent=2), encoding="utf-8")
    print(f"Saved results: {DOC_RESULTS_FILE}")
    print(f"Saved parsed docs: {PARSED_FILE}")

    cosmos_upsert_ok = True
    try:
        upsert_cosmos(cfg, normalized)
        print(f"Cosmos upsert complete: {len(normalized)} items")
    except Exception as ex:
        cosmos_upsert_ok = False
        print(f"WARN cosmos upsert failed: {ex}")

    ensure_search_indexes(cfg)
    push_search_docs(cfg, normalized)
    print("AI Search index build complete")
    print(f"  JSON chunk index: {cfg.search_json_index}")
    print(f"  Document index:   {cfg.search_doc_index}")
    print(f"  Cosmos upsert:    {'ok' if cosmos_upsert_ok else 'failed'}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
