#!/usr/bin/env bash
# Reproducible-build comparison with a documented fixed-path constraint.
#
# Findings from the 2026-11-06 investigation:
#   * libapp.so embeds the absolute dart_plugin_registrant.dart path.
#   * Linux plugin .so files embed the absolute linux/flutter/ephemeral path.
#   * The linker build ID changes with those inputs.
#   * gzip stores a timestamp unless -n is used.
#
# Therefore two builds are compared in the SAME absolute build root, with a
# clean extraction between them, a pinned Flutter/Dart toolchain, and
# timestamp-free gzip. This proves determinism of the source + toolchain under
# that documented constraint. It does NOT prove that two different absolute
# paths produce identical bytes; that is explicitly out of scope and is why
# the path is fixed.
#
# Usage: scripts/reproducibility-check.sh [commit]
#   BNB_REPRO_PATH  build root (default /tmp/bnb-repro-build)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMIT="${1:-$(git -C "$ROOT" rev-parse HEAD)}"
BUILD_ROOT="${BNB_REPRO_PATH:-/tmp/bnb-repro-build}"
WORK="$(mktemp -d /tmp/bnb-repro-compare-XXXXXX)"
trap 'rm -rf "$WORK" "$BUILD_ROOT"' EXIT

if [ -e "$BUILD_ROOT" ]; then
  echo "Refusing to use existing build root: $BUILD_ROOT" >&2
  echo "Set BNB_REPRO_PATH to a non-existent or disposable path." >&2
  exit 1
fi
case "$BUILD_ROOT" in
  /tmp/*|"$ROOT"/build/*) ;;
  *)
    echo "Refusing to create a build root outside /tmp or build/: $BUILD_ROOT" >&2
    exit 1
    ;;
esac

build_once() {
  local out="$1"
  rm -rf "$BUILD_ROOT"
  mkdir -p "$BUILD_ROOT"
  git -C "$ROOT" archive "$COMMIT" | tar -x -C "$BUILD_ROOT"
  (
    cd "$BUILD_ROOT"
    export SOURCE_DATE_EPOCH=0
    flutter pub get >/dev/null
    flutter build linux --release >/dev/null
  )
  # Deterministic archive: sorted entries, fixed mtime/owner, gzip without a
  # timestamp header.
  tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
    --numeric-owner -cf - -C "$BUILD_ROOT/build/linux/x64/release/bundle" . |
    gzip -n >"$out"
  (cd "$BUILD_ROOT/build/linux/x64/release/bundle" &&
    find . -type f -exec sha256sum {} + | sort) >"$out.manifest"
}

echo "Reproducibility comparison for $COMMIT"
echo "Fixed build root: $BUILD_ROOT (required because Flutter embeds it)"

echo "[1/3] Building copy A ..."
build_once "$WORK/a.tar.gz"
rm -rf "$BUILD_ROOT"

echo "[2/3] Building copy B ..."
build_once "$WORK/b.tar.gz"

echo "[3/3] Comparing ..."
A="$(sha256sum "$WORK/a.tar.gz" | cut -d' ' -f1)"
B="$(sha256sum "$WORK/b.tar.gz" | cut -d' ' -f1)"
echo "A: $A"
echo "B: $B"

if cmp -s "$WORK/a.tar.gz.manifest" "$WORK/b.tar.gz.manifest"; then
  echo "File manifests: identical"
else
  echo "File manifests differ:" >&2
  diff "$WORK/a.tar.gz.manifest" "$WORK/b.tar.gz.manifest" >&2 || true
fi

if [ "$A" = "$B" ] && cmp -s "$WORK/a.tar.gz.manifest" "$WORK/b.tar.gz.manifest"; then
  echo "PASS: reproducible at the documented fixed path with pinned toolchain"
  echo "Constraint: two different absolute build paths are NOT guaranteed to match."
  exit 0
fi

echo "FAILED: builds differ even at the fixed path" >&2
echo "Record this as NOT REPRODUCIBLE; do not claim reproducible builds." >&2
exit 1
