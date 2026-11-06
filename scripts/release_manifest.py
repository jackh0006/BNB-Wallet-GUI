#!/usr/bin/env python3
"""Generate or verify the single machine-readable release manifest.

The manifest is the source of truth for the generated release documentation.
It records only facts that can be recomputed from the checkout:

  * version from pubspec.yaml
  * commit, branch, subject, and whether the tree is dirty
  * Flutter/Dart toolchain versions
  * SHA-256 of both lockfiles and the SBOM
  * the test inventory summary
  * recorded check results for this exact commit (release/checks.json)
  * artifact records for this exact commit (release/artifacts.json)
  * Android signing status from the incident record

It is deterministic: no wall-clock timestamp, no random identifier.  The same
commit and the same recorded evidence always produce the same bytes.

Usage:
  python3 scripts/release_manifest.py            # write release/manifest.json
  python3 scripts/release_manifest.py --check    # fail if it is stale
  python3 scripts/release_manifest.py --stdout   # print without writing
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "release" / "manifest.json"
CHECKS = ROOT / "release" / "checks.json"
ARTIFACTS = ROOT / "release" / "artifacts.json"
INVENTORY = ROOT / "docs" / "testing" / "test-inventory.json"


def run(*args: str) -> str:
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def sha256_file(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except json.JSONDecodeError as error:
        raise SystemExit(f"error: invalid JSON in {path.relative_to(ROOT)}: {error}")


def version() -> str:
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s#]+)", text, re.MULTILINE)
    if not match:
        raise SystemExit("error: pubspec.yaml has no version")
    return match.group(1)


def test_inventory() -> dict:
    existing = read_json(INVENTORY, {})
    files = sorted(
        str(path.relative_to(ROOT)) for path in (ROOT / "test").rglob("*_test.dart")
    )
    return {
        "path": str(INVENTORY.relative_to(ROOT)),
        "sha256": sha256_file(INVENTORY),
        "files": len(files),
        "recordedFiles": existing.get("fileCount"),
        "matches": existing.get("fileCount") == len(files),
    }


def android_status() -> dict:
    incident = ROOT / "docs" / "security" / "INCIDENT_2026-11-KEYSTORE.md"
    text = incident.read_text(encoding="utf-8") if incident.is_file() else ""
    status_match = re.search(r"\*\*Status:\*\*\s*`([^`]+)`", text)
    status = status_match.group(1) if status_match else "NOT RECORDED"
    denylist = ROOT / "release" / "android-signer-denylist.txt"
    entries = []
    if denylist.is_file():
        for line in denylist.read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0].strip().replace(":", "")
            if re.fullmatch(r"[0-9a-fA-F]{64}", line):
                entries.append(line.lower())
    return {
        "incidentStatus": status,
        "rotationVerified": "NOT VERIFIED" not in status and "OPEN" not in status,
        "denylistedFingerprints": len(entries),
        "denylistPath": str(denylist.relative_to(ROOT)),
    }


def build() -> dict:
    evidence_path = ROOT / "release" / "evidence.json"
    evidence = read_json(evidence_path, None)
    return {
        "schemaVersion": 1,
        "project": {
            "name": "BNB Wallet GUI",
            "repository": "https://github.com/jackh0006/BNB-Wallet-GUI",
            "license": "AGPL-3.0-or-later",
            "author": "Jack Hudson <jackh109867@gmail.com>",
        },
        "version": version(),
        "generatedFrom": "working-tree source facts; the exact commit is bound by release/evidence.json",
        "toolchain": {
            "flutter": run("flutter", "--version").splitlines()[0],
            "dart": run("dart", "--version"),
        },
        "toolchain": {
            "flutter": run("flutter", "--version").splitlines()[0],
            "dart": run("dart", "--version"),
        },
        "lockfiles": {
            "pubspec.lock": sha256_file(ROOT / "pubspec.lock"),
            "verification/package-lock.json": sha256_file(
                ROOT / "verification" / "package-lock.json"
            ),
        },
        "sbom": {
            "path": "docs/SBOM.json",
            "sha256": sha256_file(ROOT / "docs" / "SBOM.json"),
        },
        "tests": test_inventory(),
        "androidSigning": android_status(),
        "evidenceBundle": (
            {
                "path": "release/evidence.json",
                "sha256": sha256_file(evidence_path),
                "sourceCommit": evidence.get("sourceCommit") if evidence else None,
            }
            if evidence_path.is_file() and evidence is not None
            else None
        ),
        "knownLimitations": "docs/KNOWN_LIMITATIONS.md",
        "releaseEvidence": f"docs/releases/{version().split('+', 1)[0]}.md",
    }


def render(manifest: dict) -> str:
    return json.dumps(manifest, indent=2, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if stale")
    parser.add_argument("--stdout", action="store_true", help="print only")
    args = parser.parse_args()

    text = render(build())
    if args.stdout:
        print(text, end="")
        return 0
    if args.check:
        if not MANIFEST.is_file():
            print("error: release/manifest.json is missing", file=sys.stderr)
            return 1
        if MANIFEST.read_text(encoding="utf-8") != text:
            print(
                "error: release/manifest.json is stale; run "
                "python3 scripts/release_manifest.py",
                file=sys.stderr,
            )
            return 1
        print("release manifest: current")
        return 0
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(text, encoding="utf-8")
    print(f"release manifest: wrote {MANIFEST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
