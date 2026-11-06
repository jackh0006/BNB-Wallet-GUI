#!/usr/bin/env python3
"""Security mutation check.

Copies the repository to a disposable directory, breaks one security-critical
check at a time, and requires the targeted test to fail. A mutation that
survives is a test-coverage defect, not a pass.

Nothing is written to the working repository. The temporary copy is removed.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Mutation:
    name: str
    file: str
    old: str
    new: str
    test: str


MUTATIONS = [
    Mutation(
        "chain-id-bypass",
        "lib/rpc_service.dart",
        "if (chain.toInt() != chainId) {",
        "if (false) {",
        "test/rpc_adversarial_test.dart",
    ),
    Mutation(
        "trailing-calldata",
        "lib/send_intent.dart",
        "hex.length != 8 + 64 + 64",
        "hex.length < 8 + 64 + 64",
        "test/send_intent_test.dart",
    ),
    Mutation(
        "zero-address",
        "lib/cold_tx_codec.dart",
        "if (toBytes.every((b) => b == 0)) {",
        "if (false) {",
        "test/cold_tx_codec_test.dart",
    ),
    Mutation(
        "vault-header-policy",
        "lib/vault.dart",
        "if (memory != _memoryKiB ||\n        iterations != _iterations ||\n        parallelism != _parallelism) {",
        "if (false) {",
        "test/vault_header_validation_test.dart",
    ),
    Mutation(
        "low-s-signature",
        "lib/cold_tx_codec.dart",
        "if (s <= BigInt.zero || s > _halfN) {",
        "if (false) {",
        "test/cold_tx_codec_test.dart",
    ),
]


def copy_source(destination: Path) -> None:
    ignore = shutil.ignore_patterns(
        ".git", "build", ".dart_tool", "node_modules", ".gradle", "dist"
    )
    shutil.copytree(ROOT, destination, ignore=ignore)


def run(command: list[str], cwd: Path, timeout: int) -> tuple[int, str]:
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.returncode, (result.stdout + result.stderr)[-4000:]
    except subprocess.TimeoutExpired:
        return 124, "timeout"


def main() -> int:
    work = Path(tempfile.mkdtemp(prefix="bnb-mutation-"))
    source = work / "repo"
    killed = 0
    survived = 0
    invalid = 0
    try:
        copy_source(source)
        code, output = run(["flutter", "pub", "get"], source, 300)
        if code != 0:
            print("mutation setup failed: flutter pub get", file=sys.stderr)
            print(output, file=sys.stderr)
            return 2

        for mutation in MUTATIONS:
            path = source / mutation.file
            original = path.read_text(encoding="utf-8")
            if mutation.old not in original:
                print(f"[INVALID] {mutation.name}: pattern not found in {mutation.file}")
                invalid += 1
                continue
            path.write_text(original.replace(mutation.old, mutation.new, 1), encoding="utf-8")
            code, output = run(
                ["flutter", "test", "--concurrency=1", mutation.test],
                source,
                600,
            )
            path.write_text(original, encoding="utf-8")
            if code != 0:
                killed += 1
                print(f"[KILLED] {mutation.name} -> {mutation.test} exit {code}")
            else:
                survived += 1
                print(f"[SURVIVED] {mutation.name} -> {mutation.test}")
                print(output, file=sys.stderr)

        total = killed + survived
        print(f"\nmutations attempted: {len(MUTATIONS)}")
        print(f"mutations killed: {killed}")
        print(f"mutations survived: {survived}")
        print(f"mutations invalid: {invalid}")
        if total:
            print(f"mutation score: {killed}/{total} = {killed / total:.1%}")
        if survived or invalid:
            return 1
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
