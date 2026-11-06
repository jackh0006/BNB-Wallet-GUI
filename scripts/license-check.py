#!/usr/bin/env python3
"""Fail closed when a locked dependency has no locally available license text.

This intentionally performs an inventory check rather than pretending that an
automated tool can decide every licence obligation.  It covers the exact Dart
and npm trees used by the release, and emits the package(s) that need human
review if their installed archive has no licence material.
"""
import json
import os
import re
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PUB_CACHE = Path(os.environ.get("PUB_CACHE", Path.home() / ".pub-cache"))
_flutter_bin = shutil.which("flutter")
FLUTTER_ROOT = Path(
    os.environ.get(
        "FLUTTER_ROOT",
        Path(_flutter_bin).resolve().parent.parent if _flutter_bin else "/opt/flutter",
    )
)
SDK_PACKAGES = {
    "flutter",
    "flutter_localizations",
    "flutter_test",
    "flutter_web_plugins",
    "sky_engine",
}


def dart_packages() -> list[tuple[str, str]]:
    lock = (ROOT / "pubspec.lock").read_text(encoding="utf-8")
    entries = re.findall(
        r"^  ([A-Za-z0-9_]+):\n(?:    .*\n)*?    version: [\"']?([^\"'\n]+)",
        lock,
        flags=re.MULTILINE,
    )
    if not entries:
        raise ValueError("no Dart packages found in pubspec.lock")
    return entries


def has_license(directory: Path) -> bool:
    return any(
        candidate.is_file()
        for candidate in directory.iterdir()
        if candidate.name.lower().startswith(("license", "copying", "notice"))
    )


def main() -> int:
    args = set(sys.argv[1:])
    if not args.issubset({"--dart-only", "--npm-only"}) or len(args) > 1:
        print("usage: license-check.py [--dart-only|--npm-only]", file=sys.stderr)
        return 2
    check_dart = "--npm-only" not in args
    check_npm = "--dart-only" not in args
    missing: list[str] = []
    dart_count = 0
    for name, version in dart_packages() if check_dart else []:
        # SDK packages have no hosted archive; their licences are part of the
        # installed Flutter/Dart SDK and are not represented in PUB_CACHE.
        if name in SDK_PACKAGES:
            if not (FLUTTER_ROOT / "LICENSE").is_file():
                missing.append(f"Flutter SDK {name}@{version} (SDK LICENSE missing)")
            else:
                dart_count += 1
            continue
        location = PUB_CACHE / "hosted" / "pub.dev" / f"{name}-{version}"
        if not location.is_dir():
            missing.append(f"Dart {name}@{version} (not installed)")
        elif not has_license(location):
            missing.append(f"Dart {name}@{version} (no LICENSE/COPYING/NOTICE)")
        else:
            dart_count += 1

    npm_lock = json.loads((ROOT / "verification" / "package-lock.json").read_text())
    npm_count = 0
    for package_path, entry in npm_lock.get("packages", {}).items() if check_npm else []:
        if not package_path.startswith("node_modules/"):
            continue
        location = ROOT / "verification" / package_path
        name = package_path.removeprefix("node_modules/")
        version = entry.get("version", "unknown")
        if not location.is_dir():
            missing.append(f"npm {name}@{version} (not installed)")
        elif not has_license(location):
            missing.append(f"npm {name}@{version} (no LICENSE/COPYING/NOTICE)")
        else:
            npm_count += 1

    if missing:
        print("FAIL licence inventory is incomplete:", file=sys.stderr)
        print("\n".join(missing), file=sys.stderr)
        return 1
    scopes = []
    if check_dart:
        scopes.append(f"{dart_count} Dart")
    if check_npm:
        scopes.append(f"{npm_count} npm")
    print("Licence inventory: license text found for " + " and ".join(scopes) +
          " locked packages. Compatibility obligations still require release-owner review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
