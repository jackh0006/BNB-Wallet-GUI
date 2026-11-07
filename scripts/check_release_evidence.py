#!/usr/bin/env python3
"""Require a version-specific release evidence record for the source version."""

from pathlib import Path
import json
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
match = re.search(r"^version:\s*([^\s#]+)", pubspec, re.MULTILINE)
if not match:
    sys.exit("error: pubspec.yaml has no version")

version = match.group(1)
release_version = version.split("+", 1)[0]
record = ROOT / "docs" / "releases" / f"{release_version}.md"
if not record.is_file():
    sys.exit(f"error: missing release evidence record: {record.relative_to(ROOT)}")

text = record.read_text(encoding="utf-8")
if f"Source version: `{version}`" not in text:
    sys.exit(
        f"error: {record.relative_to(ROOT)} must identify Source version: `{version}`"
    )

if "| Check | Result | Evidence |" not in text:
    sys.exit(f"error: {record.relative_to(ROOT)} lacks the required test-result table")

sbom_path = ROOT / "docs" / "SBOM.json"
try:
    sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    sys.exit(f"error: cannot read {sbom_path.relative_to(ROOT)}: {error}")
if sbom.get("bomFormat") != "CycloneDX":
    sys.exit("error: docs/SBOM.json is not CycloneDX")
if not re.fullmatch(
    r"urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
    str(sbom.get("serialNumber") or ""),
):
    sys.exit("error: docs/SBOM.json lacks a valid CycloneDX serialNumber URN")
if not sbom.get("specVersion"):
    sys.exit("error: docs/SBOM.json lacks specVersion")

print(f"release evidence OK: source {version} -> {record.relative_to(ROOT)}")
