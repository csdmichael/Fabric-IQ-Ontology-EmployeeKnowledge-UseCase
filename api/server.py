from __future__ import annotations

import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = REPO_ROOT / "config"
DATA_DIR = REPO_ROOT / "data"

JSON_ROUTES = {
    "/api/config/endpoints": CONFIG_DIR / "endpoints.json",
    "/api/employees": DATA_DIR / "employees.json",
    "/api/digital-assets": DATA_DIR / "digital_assets.json",
    "/api/emails": DATA_DIR / "emails.json",
    "/api/org-hierarchy": DATA_DIR / "org_hierarchy.json",
    "/api/projects": DATA_DIR / "projects.json",
    "/api/contributions": DATA_DIR / "contributions.json",
    "/api/powerbi-reports": DATA_DIR / "powerbi_reports.json",
    "/api/parsed-documents": DATA_DIR / "parsed_documents_cosmosdb.json",
}


def _load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def _apply_filters(payload: object, query: dict[str, list[str]]) -> object:
    if not isinstance(payload, list):
        return payload

    department = (query.get("department") or [None])[0]
    employee_id = (query.get("employeeId") or [None])[0]
    if not department and not employee_id:
        return payload

    filtered = payload
    if department:
        filtered = [
            item
            for item in filtered
            if isinstance(item, dict) and str(item.get("department", "")).lower() == department.lower()
        ]
    if employee_id:
        filtered = [
            item
            for item in filtered
            if isinstance(item, dict) and str(item.get("employeeId", "")).lower() == employee_id.lower()
        ]
    return filtered


def _summary() -> dict[str, object]:
    employees = _load_json(DATA_DIR / "employees.json")
    contributions = _load_json(DATA_DIR / "contributions.json")
    projects = _load_json(DATA_DIR / "projects.json")
    reports = _load_json(DATA_DIR / "powerbi_reports.json")
    assets = _load_json(DATA_DIR / "digital_assets.json")
    parsed = _load_json(DATA_DIR / "parsed_documents_cosmosdb.json")

    return {
        "employees": len(employees) if isinstance(employees, list) else 0,
        "contributions": len(contributions) if isinstance(contributions, list) else 0,
        "projects": len(projects) if isinstance(projects, list) else 0,
        "powerBiReports": len(reports) if isinstance(reports, list) else 0,
        "digitalAssets": len(assets) if isinstance(assets, list) else 0,
        "parsedDocuments": len(parsed) if isinstance(parsed, list) else 0,
        "timestampUtc": datetime.now(timezone.utc).isoformat(),
    }


class ApiHandler(BaseHTTPRequestHandler):
    server_version = "FabricIQApi/1.0"

    def _send_json(self, status: int, payload: object) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed_url = urlparse(self.path)
        path = parsed_url.path.rstrip("/") or "/"
        query = parse_qs(parsed_url.query)

        if path in {"/", "/health", "/api/health"}:
            self._send_json(
                200,
                {
                    "status": "ok",
                    "service": "fabric-iq-employee-knowledge-api",
                    "timestampUtc": datetime.now(timezone.utc).isoformat(),
                },
            )
            return

        if path == "/api/summary":
            self._send_json(200, _summary())
            return

        target_file = JSON_ROUTES.get(path)
        if not target_file:
            self._send_json(404, {"error": "Not found", "path": path})
            return

        try:
            payload = _load_json(target_file)
            payload = _apply_filters(payload, query)
            self._send_json(200, payload)
        except (OSError, json.JSONDecodeError) as exc:
            self._send_json(500, {"error": "Failed to load data source", "details": str(exc)})


def run(host: str = "0.0.0.0", port: int = 8080) -> None:
    server = ThreadingHTTPServer((host, port), ApiHandler)
    print(f"Fabric IQ API listening on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run()
