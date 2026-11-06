#!/usr/bin/env python3
"""Run one release check and append its result to release/checks.json.

Usage:
  python3 scripts/record_check.py --id full-test-suite -- bash scripts/test-suite.sh
  python3 scripts/record_check.py --id static-analysis --log /tmp/analyze.log \
      -- flutter analyze --no-pub

The record is bound to the current commit.  A check that did not finish is
recorded with its real non-zero exit code; it is never inferred from silence.
Timestamps and durations are evidence, not a generated document, so they are
allowed to vary between runs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECKS = ROOT / "release" / "checks.json"


def command_output(*args: str) -> str:
    try:
        return subprocess.check_output(args, cwd=ROOT, text=True, stderr=subprocess.STDOUT).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def sha256_file(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load() -> dict:
    try:
        data = json.loads(CHECKS.read_text(encoding="utf-8"))
    except FileNotFoundError:
        data = {}
    data.setdefault("schemaVersion", 1)
    data.setdefault("checks", [])
    return data


def write(data: dict) -> None:
    CHECKS.parent.mkdir(parents=True, exist_ok=True)
    temporary = CHECKS.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(CHECKS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--log", default=None)
    parser.add_argument("--optional", action="store_true", help="not required for a verified release")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("error: no command supplied after --", file=sys.stderr)
        return 2

    commit = command_output("git", "rev-parse", "HEAD")
    started = datetime.now(timezone.utc)
    watch = time.monotonic()
    log_path = Path(args.log) if args.log else None
    if log_path:
        log_path.parent.mkdir(parents=True, exist_ok=True)

    display = " ".join(shlex.quote(part) for part in command)
    print(f"==> check {args.id}: {display}", flush=True)
    with subprocess.Popen(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    ) as process:
        assert process.stdout is not None
        log_handle = log_path.open("w", encoding="utf-8") if log_path else None
        try:
            for line in process.stdout:
                sys.stdout.write(line)
                sys.stdout.flush()
                if log_handle:
                    log_handle.write(line)
        finally:
            if log_handle:
                log_handle.close()
        exit_code = process.wait()

    finished = datetime.now(timezone.utc)
    duration = round(time.monotonic() - watch, 3)
    record = {
        "id": args.id,
        "commit": commit,
        "command": " ".join(command),
        "exitCode": exit_code,
        "durationSeconds": duration,
        "startedAt": started.isoformat().replace("+00:00", "Z"),
        "finishedAt": finished.isoformat().replace("+00:00", "Z"),
        "required": not bool(args.optional),
        "log": (
            str(log_path.resolve().relative_to(ROOT))
            if log_path and log_path.resolve().is_relative_to(ROOT)
            else (str(log_path.resolve()) if log_path else None)
        ),
        "logSha256": sha256_file(log_path) if log_path else None,
        "machine": {
            "os": platform.platform(),
            "kernel": platform.release(),
            "architecture": platform.machine(),
            "cpuCount": os.cpu_count(),
            "memoryBytes": os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
            if hasattr(os, "sysconf")
            else None,
        },
        "toolchain": {
            "flutter": command_output("flutter", "--version").splitlines()[0]
            if command_output("flutter", "--version")
            else "unknown",
            "dart": command_output("dart", "--version"),
        },
    }

    data = load()
    data["checks"] = [
        item
        for item in data["checks"]
        if not (item.get("id") == args.id and item.get("commit") == commit)
    ]
    data["checks"].append(record)
    data["checks"].sort(key=lambda item: (item.get("commit", ""), item.get("id", "")))
    write(data)

    print(f"<== check {args.id}: exit {exit_code} in {duration}s", flush=True)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
