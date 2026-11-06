#!/usr/bin/env python3
"""Fail if X Wallet introduces a paid gate, subscription, ads, or payment SDK.

This is a lightweight policy check, not a financial audit. Donation links are
allowed and must stay out of transaction confirmation screens.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = [
    r"\bsubscription\b",
    r"\bpaywall\b",
    r"\bpremium\b",
    r"\bpaid plan\b",
    r"\bin-app purchase\b",
    r"\bstripe\b",
    r"\bpaypal\b",
    r"\bgoogle play billing\b",
    r"\badmob\b",
    r"\badsense\b",
]
ALLOW = {
    "lib/tor_manager.dart",  # StreamSubscription, not a paid subscription
    "scripts/check_free_product.py",  # this file contains the search terms
}
SKIP_DIRS = {".git", "build", ".dart_tool", "node_modules", ".gradle", "dist", "ephemeral"}
SKIP_SUFFIXES = {".png", ".jpg", ".jpeg", ".ico", ".so", ".deb", ".lock", ".pyc"}


def main() -> int:
    errors = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        if path.suffix.lower() in SKIP_SUFFIXES:
            continue
        if str(rel) in ALLOW:
            continue
        if str(rel).startswith(("docs/", "DONATE.md", "README.md")):
            # Documentation may describe donations or explicitly deny paid
            # features; the code/package boundary is what matters.
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for pattern in PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                errors.append(f"{rel}: monetization term {pattern}")
    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8", errors="ignore")
    if "GNU AFFERO GENERAL PUBLIC LICENSE" not in license_text:
        errors.append("LICENSE is not the expected AGPL text")
    if errors:
        for error in errors:
            print(f"FREE-USE FAIL: {error}", file=sys.stderr)
        return 1
    print("Free-use policy: PASS (no subscription/paywall/ad SDK; AGPL present)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
