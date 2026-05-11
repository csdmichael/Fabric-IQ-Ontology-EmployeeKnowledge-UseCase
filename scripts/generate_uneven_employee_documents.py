#!/usr/bin/env python3
"""
Generate uneven document volumes per employee and align contribution tiers.

High contributors get many documents, medium contributors get moderate volume,
low contributors get fewer documents. The script updates:
  - data/digital_assets.json
  - data/contributions.json
  - data/employees/<EMPxxx>/* generated files
"""

from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "data"
EMP_DIR = DATA_DIR / "employees"

EMPLOYEES_FILE = DATA_DIR / "employees.json"
CONTRIB_FILE = DATA_DIR / "contributions.json"
ASSETS_FILE = DATA_DIR / "digital_assets.json"

RNG = random.Random(42)

FORMATS = ["txt", "md", "csv", "pdf", "docx", "pptx", "xlsx", "eml", "one"]
ASSET_TYPES = {
    "txt": "note",
    "md": "note",
    "csv": "spreadsheet",
    "pdf": "document",
    "docx": "document",
    "pptx": "presentation",
    "xlsx": "spreadsheet",
    "eml": "email",
    "one": "onenote",
}


@dataclass
class TierRange:
    min_docs: int
    max_docs: int


TIER_RANGES: Dict[str, TierRange] = {
    "star": TierRange(18, 30),
    "average": TierRange(8, 16),
    "low": TierRange(3, 7),
}


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, payload):
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)


def infer_tier(score: float) -> str:
    if score >= 80:
        return "star"
    if score >= 55:
        return "average"
    return "low"


def write_synthetic_file(path: Path, emp_id: str, asset_id: str, fmt: str, dept: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    body = (
        f"Employee: {emp_id}\n"
        f"Asset: {asset_id}\n"
        f"Department: {dept}\n"
        f"Format: {fmt}\n"
        "Knowledge summary: project updates, contributions, lessons learned.\n"
    )

    # Use text content for all generated files in this demo repository.
    path.write_text(body, encoding="utf-8")


def next_asset_seq(existing_assets: List[dict], emp_id: str) -> int:
    max_seq = 0
    prefix = f"AST-{emp_id}-"
    for asset in existing_assets:
        aid = str(asset.get("assetId", ""))
        if aid.startswith(prefix):
            try:
                seq = int(aid.split("-")[-1])
                max_seq = max(max_seq, seq)
            except ValueError:
                continue
    return max_seq + 1


def main() -> int:
    employees = load_json(EMPLOYEES_FILE)
    contributions = load_json(CONTRIB_FILE)
    assets = load_json(ASSETS_FILE)

    contrib_by_emp = {str(c["employeeId"]): c for c in contributions}

    # Remove previously generated synthetic assets (title marker) to keep script idempotent.
    retained_assets: List[dict] = [a for a in assets if not str(a.get("title", "")).startswith("Uneven Synthetic Asset")]

    generated_count = 0
    tier_counts = {"star": 0, "average": 0, "low": 0}

    for emp in employees:
        emp_id = str(emp["employeeId"])
        dept = str(emp.get("department", "Unknown"))

        c = contrib_by_emp.get(emp_id)
        if not c:
            continue

        score = float(c.get("contributionScore", 50))
        tier = infer_tier(score)
        c["tier"] = tier

        r = TIER_RANGES[tier]
        doc_target = RNG.randint(r.min_docs, r.max_docs)
        tier_counts[tier] += 1

        # Keep 1-6 projects skewed by tier for realism.
        if tier == "star":
            c["projectCount"] = max(int(c.get("projectCount", 0)), RNG.randint(5, 8))
            c["codeCommitCount"] = max(int(c.get("codeCommitCount", 0)), RNG.randint(120, 280))
            c["mentoringSessions"] = max(int(c.get("mentoringSessions", 0)), RNG.randint(10, 24))
        elif tier == "average":
            c["projectCount"] = max(int(c.get("projectCount", 0)), RNG.randint(2, 5))
            c["codeCommitCount"] = max(int(c.get("codeCommitCount", 0)), RNG.randint(45, 130))
            c["mentoringSessions"] = max(int(c.get("mentoringSessions", 0)), RNG.randint(3, 10))
        else:
            c["projectCount"] = max(int(c.get("projectCount", 0)), RNG.randint(1, 2))
            c["codeCommitCount"] = max(int(c.get("codeCommitCount", 0)), RNG.randint(5, 45))
            c["mentoringSessions"] = max(int(c.get("mentoringSessions", 0)), RNG.randint(0, 3))

        seq = next_asset_seq(retained_assets, emp_id)
        for _ in range(doc_target):
            fmt = RNG.choice(FORMATS)
            asset_id = f"AST-{emp_id}-{seq:02d}"
            file_name = f"{asset_id}.{fmt}"
            rel = f"{emp_id}/{file_name}"
            out_path = EMP_DIR / emp_id / file_name
            write_synthetic_file(out_path, emp_id, asset_id, fmt, dept)

            retained_assets.append(
                {
                    "assetId": asset_id,
                    "employeeId": emp_id,
                    "assetType": ASSET_TYPES.get(fmt, "document"),
                    "format": fmt,
                    "title": f"Uneven Synthetic Asset {asset_id}",
                    "sourceSystem": "OneDrive",
                    "lastModified": "2026-05-10",
                    "storageRef": {
                        "container": "employee-knowledge-raw",
                        "relativePath": rel,
                        "endpointConfigKey": "blobStorageEndpoint",
                    },
                }
            )
            seq += 1
            generated_count += 1

        # Align assetCount with generated distribution.
        c["assetCount"] = doc_target

    save_json(CONTRIB_FILE, contributions)
    save_json(ASSETS_FILE, retained_assets)

    print("Uneven document generation complete")
    print(f"  Employees by tier: {tier_counts}")
    print(f"  Generated assets: {generated_count}")
    print(f"  Updated: {CONTRIB_FILE}")
    print(f"  Updated: {ASSETS_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
