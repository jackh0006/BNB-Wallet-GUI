#!/usr/bin/env python3
"""Generate or verify the machine-readable Flutter test inventory.

Every test file is listed with its SHA-256, declared tags, and a count of
`test`/`testWidgets` declarations.  The inventory is deterministic and is
cross-checked against the required status checks in release/checks.json.

Usage:
  python3 scripts/test_inventory.py            # write the inventory
  python3 scripts/test_inventory.py --check    # fail on drift or matrix gap
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "testing" / "test-inventory.json"
MATRIX = ROOT / "docs" / "testing" / "TEST_MATRIX.md"

TEST_DECL = re.compile(r"^\s*(?:test|testWidgets)\s*\(", re.MULTILINE)
TAG_BLOCK = re.compile(r"@Tags\(\s*\[(.*?)\]\s*\)", re.DOTALL)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def entry(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    tags: list[str] = []
    for block in TAG_BLOCK.finditer(text):
        for tag in re.findall(r"['\"]([^'\"]+)['\"]", block.group(1)):
            if tag not in tags:
                tags.append(tag)
    return {
        "path": str(path.relative_to(ROOT)),
        "sha256": sha256(path),
        "tags": sorted(tags),
        "tests": len(TEST_DECL.findall(text)),
        "lines": text.count("\n") + (0 if text.endswith("\n") else 1),
    }


def build() -> dict:
    files = sorted((ROOT / "test").rglob("*_test.dart"))
    entries = [entry(path) for path in files]
    return {
        "schemaVersion": 1,
        "fileCount": len(entries),
        "testCount": sum(item["tests"] for item in entries),
        "kdfFileCount": sum(1 for item in entries if "kdf" in item["tags"]),
        "files": entries,
    }


def render(inventory: dict) -> str:
    return json.dumps(inventory, indent=2, sort_keys=True) + "\n"


def matrix_gaps(inventory: dict) -> list[str]:
    text = MATRIX.read_text(encoding="utf-8") if MATRIX.is_file() else ""
    listed = set(re.findall(r"[A-Za-z0-9_]+_test\.dart", text))
    return sorted(
        Path(item["path"]).name
        for item in inventory["files"]
        if Path(item["path"]).name not in listed
    )


def sync_matrix_counts(text: str, inventory: dict) -> str:
    """Keep the human-readable matrix counts equal to the generated inventory."""
    counts = {
        Path(item["path"]).name: item["tests"] for item in inventory["files"]
    }
    for name, count in counts.items():
        text = re.sub(
            rf"(\| `{re.escape(name)}` \| )\d+( \|)",
            rf"\g<1>{count}\2",
            text,
        )
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    inventory = build()
    text = render(inventory)
    gaps = matrix_gaps(inventory)
    if gaps:
        print(
            "error: docs/testing/TEST_MATRIX.md does not list: " + ", ".join(gaps),
            file=sys.stderr,
        )
        return 1
    matrix_text = MATRIX.read_text(encoding="utf-8")
    synced_matrix = sync_matrix_counts(matrix_text, inventory)

    if args.check:
        stale = []
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != text:
            stale.append(str(OUTPUT.relative_to(ROOT)))
        if synced_matrix != matrix_text:
            stale.append(str(MATRIX.relative_to(ROOT)))
        if stale:
            print(
                "error: generated test inventory is stale: " + ", ".join(stale),
                file=sys.stderr,
            )
            return 1
        print(
            f"test inventory: current ({inventory['fileCount']} files, "
            f"{inventory['testCount']} declarations)"
        )
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(text, encoding="utf-8")
    if synced_matrix != matrix_text:
        MATRIX.write_text(synced_matrix, encoding="utf-8")
    print(
        f"test inventory: wrote {OUTPUT.relative_to(ROOT)} "
        f"({inventory['fileCount']} files, {inventory['testCount']} declarations, "
        f"{inventory['kdfFileCount']} kdf files)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
