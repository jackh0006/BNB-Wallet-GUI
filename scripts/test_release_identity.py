#!/usr/bin/env python3
"""Negative tests for scripts/check_release_identity.py.

Each test starts from a valid copied evidence set, applies one defect, and
requires the validator to reject it. A validator that accepts any of these is
not fail-closed.
"""
from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

import check_release_identity as identity

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    "pubspec.yaml",
    "release/manifest.json",
    "release/evidence.json",
    "release/reproducibility.json",
    "release/package-smoke.json",
    "docs/SBOM.json",
    "docs/testing/test-inventory.json",
    "docs/releases/1.0.10.md",
    "docs/releases/1.1.0.md",
]


class IdentityNegativeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = Path(tempfile.mkdtemp(prefix="bnb-identity-test-"))
        for name in FILES:
            source = ROOT / name
            target = self.temp / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    def tearDown(self) -> None:
        shutil.rmtree(self.temp, ignore_errors=True)

    def read(self, name: str) -> dict:
        return json.loads((self.temp / name).read_text(encoding="utf-8"))

    def write(self, name: str, data: dict | str) -> None:
        path = self.temp / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(data, str):
            path.write_text(data, encoding="utf-8")
        else:
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

    def assert_rejected(self) -> None:
        errors = identity.validate(self.temp, None, skip_git=True)
        self.assertTrue(errors, "validator accepted an invalid identity")

    def test_valid_baseline_passes(self) -> None:
        self.assertEqual(identity.validate(self.temp, None, skip_git=True), [])

    def test_missing_required_check(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checks"] = [
            c for c in evidence["checks"] if c["id"] != "full-test-suite"
        ]
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_failed_check(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checks"][0]["exitCode"] = 1
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_duplicate_check(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checks"].append(dict(evidence["checks"][0]))
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_malformed_commit(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checksCommit"] = "not-a-commit"
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_missing_identity_note_when_commits_differ(self) -> None:
        evidence = self.read("release/evidence.json")
        evidence["checksCommit"] = "1" * 40
        evidence.pop("identityNote", None)
        self.write("release/evidence.json", evidence)
        self.assert_rejected()

    def test_stale_sbom_hash(self) -> None:
        manifest = self.read("release/manifest.json")
        manifest["sbom"]["sha256"] = "0" * 64
        self.write("release/manifest.json", manifest)
        self.assert_rejected()

    def test_stale_inventory_hash(self) -> None:
        manifest = self.read("release/manifest.json")
        manifest["tests"]["sha256"] = "0" * 64
        self.write("release/manifest.json", manifest)
        self.assert_rejected()

    def test_version_mismatch(self) -> None:
        manifest = self.read("release/manifest.json")
        manifest["version"] = "9.9.9+1"
        self.write("release/manifest.json", manifest)
        self.assert_rejected()

    def test_missing_evidence(self) -> None:
        (self.temp / "release/evidence.json").unlink()
        self.assert_rejected()

    def test_invalid_json(self) -> None:
        (self.temp / "release/manifest.json").write_text("{not json", encoding="utf-8")
        self.assert_rejected()

    def test_artifact_hash_mismatch(self) -> None:
        artifact = self.temp / "artifact.deb"
        artifact.write_bytes(b"not the real package")
        self.assert_rejected_with_artifact(artifact)

    def assert_rejected_with_artifact(self, artifact: Path) -> None:
        errors = identity.validate(self.temp, artifact, skip_git=True)
        self.assertTrue(errors, "validator accepted a mismatched artifact hash")


if __name__ == "__main__":
    unittest.main(verbosity=2)
