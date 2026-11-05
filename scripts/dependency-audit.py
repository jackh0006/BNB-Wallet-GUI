#!/usr/bin/env python3
"""Fail CI when pub.dev reports a resolved package affected by an advisory.

The Dart SDK's `pub outdated --json` response includes
`isCurrentAffectedByAdvisory` for each package it reports.  This script keeps
the policy small and reproducible: it changes neither pubspec nor the lockfile
and it fails closed if the command's JSON cannot be obtained or understood.
"""
import json
import subprocess
import sys


def main() -> int:
    result = subprocess.run(
        ["dart", "pub", "outdated", "--json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("FAIL dependency metadata query failed", file=sys.stderr)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        return 1
    try:
        packages = json.loads(result.stdout).get("packages", [])
    except (AttributeError, json.JSONDecodeError) as error:
        print(f"FAIL dependency metadata was not valid JSON: {error}", file=sys.stderr)
        return 1
    affected = [
        package.get("package", "<unnamed>")
        for package in packages
        if package.get("isCurrentAffectedByAdvisory") is True
    ]
    if affected:
        print("FAIL resolved packages affected by advisories: " + ", ".join(affected))
        return 1
    print("Dependency advisory audit: no current pub.dev advisory flags reported.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
