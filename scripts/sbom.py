#!/usr/bin/env python3
"""SBOM generator (spec §11): reads pubspec.lock and emits a CycloneDX-style
JSON component inventory (direct AND transitive Dart packages, with the
resolved versions and their SHA-256 from the lock file).

Usage: python3 scripts/sbom.py [--lock pubspec.lock] [--out docs/SBOM.json]

Deterministic: no timestamps, no random serial numbers — the same lock file
always yields the same SBOM bytes, so two builds can be compared directly.
"""
import json
import os
import re
import sys

DEFAULT_LOCK = "pubspec.lock"
DEFAULT_OUT = "docs/SBOM.json"


def parse_lock(text: str) -> list:
    """Minimal block-style parser for pubspec.lock: every two-space-indented
    key under `packages:` is one entry; we only keep entries that carry a
    resolved version (top-level keys like `sdks:` are dropped)."""
    packages: list = []
    current = None
    for line in text.splitlines():
        top = re.match(r"^  ([a-zA-Z0-9_]+):$", line)
        if top:
            current = {"name": top.group(1)}
            packages.append(current)
            continue
        if current is None:
            continue
        dependency = re.match(r"^    dependency: (.+)$", line)
        version = re.match(r"^    version: \"?([0-9][^\"?]*)\"?", line)
        sha256 = re.match(r"^      sha256: \"?([0-9a-f]{64})\"?", line)
        url = re.match(r"^      url: \"?([^\"]+)\"?", line)
        if dependency:
            current["dependency"] = dependency.group(1).strip().strip("'\"")
        if version:
            current["version"] = version.group(1).strip().strip("'\"")
        if sha256:
            current["sha256"] = sha256.group(1)
        if url:
            current["source"] = url.group(1)
    return [p for p in packages if p.get("version") and p.get("dependency")]


def component(entry: dict) -> dict:
    out = {
        "type": "library",
        "name": entry["name"],
        "version": entry["version"],
        "purl": f"pkg:dart/{entry['name']}@{entry['version']}",
        "scope": "required",
        "properties": [
            {"name": "dependency_class", "value": entry.get("dependency", "")},
            {"name": "download_source", "value": entry.get("source", "")},
        ],
    }
    if entry.get("sha256"):
        out["hashes"] = [{"alg": "SHA-256", "content": entry["sha256"]}]
    return out


def main() -> int:
    args = sys.argv[1:]
    lock_path = DEFAULT_LOCK
    out_path = DEFAULT_OUT
    if "--lock" in args:
        lock_path = args[args.index("--lock") + 1]
    if "--out" in args:
        out_path = args[args.index("--out") + 1]

    try:
        with open(lock_path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError as error:
        print(f"FAIL cannot read {lock_path}: {error}")
        return 1

    packages = parse_lock(text)
    if not packages:
        print("FAIL no packages resolved in the lock file — run flutter pub get")
        return 1

    direct = [p for p in packages if "direct" in p.get("dependency", "")]
    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "component": {
                "type": "application",
                "name": "bnb_wallet_gui",
                "version": "1.0.5",
                "description": "Local, non-custodial BNB Smart Chain wallet (deb).",
            },
            "properties": [
                {"name": "generated_from", "value": lock_path},
                {"name": "deterministic", "value": "no-timestamp -- same lock, same bytes"},
            ],
        },
        "components": [component(p) for p in packages],
    }

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(sbom, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(
        f"Wrote {out_path}: {len(packages)} packages "
        f"({len(direct)} direct, {len(packages) - len(direct)} transitive)"
    )
    source_epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if source_epoch:
        print("(SOURCE_DATE_EPOCH noted but SBOM is timestamp-free by design)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
