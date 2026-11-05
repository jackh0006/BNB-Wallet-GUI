#!/usr/bin/env python3
"""Require a version-specific release evidence record for the source version."""

from pathlib import Path
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

print(f"release evidence OK: source {version} -> {record.relative_to(ROOT)}")
