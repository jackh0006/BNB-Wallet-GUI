#!/usr/bin/env python3
"""Require every Flutter test file to be named in the public test matrix."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
matrix = ROOT / "docs" / "testing" / "TEST_MATRIX.md"
test_files = {path.name for path in (ROOT / "test").rglob("*_test.dart")}
listed = set(re.findall(r"[A-Za-z0-9_]+_test\.dart", matrix.read_text(encoding="utf-8")))
missing = sorted(test_files - listed)

if missing:
    sys.exit(
        "error: TEST_MATRIX.md must list every test file; missing: "
        + ", ".join(missing)
    )

print(f"test inventory OK: {len(test_files)} Flutter test files are listed")
