#!/usr/bin/env bash
# Build the same commit twice in two clean worktrees and compare deterministic
# archives of the Linux release bundle.
#
# This is deliberately slow and is not part of every PR. Run it on a release
# candidate with enough disk and time. A mismatch is a real result: record it
# as NOT REPRODUCIBLE rather than hiding it. Flutter/Dart AOT output is not
# guaranteed to be bit-reproducible across paths or toolchain builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMIT="${1:-$(git -C "$ROOT" rev-parse HEAD)}"
WORK="$(mktemp -d /tmp/bnb-repro-XXXXXX)"
cleanup() {
  git -C "$ROOT" worktree remove --force "$WORK/a" 2>/dev/null || true
  git -C "$ROOT" worktree remove --force "$WORK/b" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "Reproducibility check for $COMMIT"
git -C "$ROOT" worktree add --detach "$WORK/a" "$COMMIT" >/dev/null
git -C "$ROOT" worktree add --detach "$WORK/b" "$COMMIT" >/dev/null

build_and_archive() {
  local dir="$1"
  local out="$2"
  (
    cd "$dir"
    flutter pub get >/dev/null
    flutter build linux --release >/dev/null
    tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
      --numeric-owner -czf "$out" -C build/linux/x64/release/bundle .
  )
}

echo "[1/3] Building copy A ..."
build_and_archive "$WORK/a" "$WORK/a.tar.gz"
echo "[2/3] Building copy B ..."
build_and_archive "$WORK/b" "$WORK/b.tar.gz"

echo "[3/3] Comparing ..."
A="$(sha256sum "$WORK/a.tar.gz" | cut -d' ' -f1)"
B="$(sha256sum "$WORK/b.tar.gz" | cut -d' ' -f1)"
echo "A: $A"
echo "B: $B"

if [ "$A" = "$B" ]; then
  echo "REPRODUCIBLE: identical archive hash"
  exit 0
fi

echo "NOT REPRODUCIBLE: archive hashes differ" >&2
mkdir -p "$WORK/extract-a" "$WORK/extract-b"
tar -xzf "$WORK/a.tar.gz" -C "$WORK/extract-a"
tar -xzf "$WORK/b.tar.gz" -C "$WORK/extract-b"
diff -rq "$WORK/extract-a" "$WORK/extract-b" >&2 || true
echo "Record this as NOT REPRODUCIBLE; do not claim reproducible builds." >&2
exit 1
