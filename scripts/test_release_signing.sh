#!/usr/bin/env bash
# Tests for the release signing tools, using a disposable test key in a
# temporary GNUPGHOME. This is NOT an owner release key and is deleted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/bnb-signing-test-XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export GNUPGHOME="$TMP/gnupg"
mkdir -m 0700 "$GNUPGHOME"
gpg --batch --passphrase '' --quick-generate-key \
  "BNB Test Release <test@example.invalid>" rsa3072 sign 0 >/dev/null 2>&1
FPR="$(gpg --batch --with-colons --fingerprint | awk -F: '$1=="fpr"{print $10; exit}')"
[ -n "$FPR" ]

OUT="$TMP/out"
mkdir -p "$OUT"
DEB="$TMP/bnb-wallet-test-amd64.deb"
printf 'synthetic package\n' >"$DEB"

bash "$ROOT/scripts/sign-release.sh" --deb "$DEB" --key "$FPR" --outdir "$OUT" >/dev/null
SUMS="$OUT/SHA256SUMS"
SIG="$OUT/SHA256SUMS.asc"

bash "$ROOT/scripts/verify-release-signature.sh" \
  --deb "$DEB" --sums "$SUMS" --sig "$SIG" --fingerprint "$FPR" >/dev/null
echo "PASS: valid signature"

if bash "$ROOT/scripts/verify-release-signature.sh" \
  --deb "$DEB" --sums "$SUMS" --sig "$SIG" --fingerprint "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" >/dev/null 2>&1; then
  echo "FAIL: wrong fingerprint accepted" >&2
  exit 1
fi
echo "PASS: wrong fingerprint rejected"

printf 'tampered package\n' >"$DEB"
if bash "$ROOT/scripts/verify-release-signature.sh" \
  --deb "$DEB" --sums "$SUMS" --sig "$SIG" --fingerprint "$FPR" >/dev/null 2>&1; then
  echo "FAIL: tampered package accepted" >&2
  exit 1
fi
echo "PASS: tampered package rejected"

printf 'synthetic package\n' >"$DEB"
printf '%064d  %s\n' 0 "$(basename "$DEB")" >"$SUMS"
if bash "$ROOT/scripts/verify-release-signature.sh" \
  --deb "$DEB" --sums "$SUMS" --sig "$SIG" --fingerprint "$FPR" >/dev/null 2>&1; then
  echo "FAIL: tampered checksum manifest accepted" >&2
  exit 1
fi
echo "PASS: tampered checksum manifest rejected"

if bash "$ROOT/scripts/verify-release-signature.sh" \
  --deb "$DEB" --sums "$SUMS" --sig "$TMP/missing.asc" --fingerprint "$FPR" >/dev/null 2>&1; then
  echo "FAIL: missing signature accepted" >&2
  exit 1
fi
echo "PASS: missing signature rejected"

if bash "$ROOT/scripts/sign-release.sh" --deb "$DEB" --key "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" --outdir "$OUT" >/dev/null 2>&1; then
  echo "FAIL: unknown signing key accepted" >&2
  exit 1
fi
echo "PASS: unknown signing key rejected"

echo "Release signing tests: PASS"
