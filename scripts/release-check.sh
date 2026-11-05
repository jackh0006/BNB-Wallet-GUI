#!/usr/bin/env bash
# Linux release gate: checks the source and a signed Debian artifact.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

git diff --exit-code -- pubspec.lock || {
  echo 'ERROR: pubspec.lock has uncommitted changes; review and commit it before release.' >&2
  exit 1
}
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
cd verification && npm ci && node verify.cjs

DEB="${BNB_RELEASE_DEB:?Set BNB_RELEASE_DEB to the release .deb to check}"
[[ -f "$DEB" ]] || { echo "ERROR: package not found: $DEB" >&2; exit 1; }
dpkg-deb --info "$DEB" >/dev/null
[[ -f "$DEB.asc" ]] || { echo 'ERROR: unsigned deb (missing .asc).' >&2; exit 1; }
gpg --verify "$DEB.asc" "$DEB"
SUMS="$(dirname "$DEB")/SHA256SUMS"
[[ -f "$SUMS" ]] || { echo 'ERROR: SHA256SUMS is missing.' >&2; exit 1; }
(cd "$(dirname "$SUMS")" && sha256sum --check "$(basename "$SUMS")")
echo 'Release check: PASS'
