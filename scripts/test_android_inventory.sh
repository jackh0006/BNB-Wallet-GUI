#!/usr/bin/env bash
# Test the Android inventory tool with a disposable synthetic keystore.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/bnb-android-inventory-XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

KS="$TMP/test-release.jks"
keytool -genkeypair -alias test-release -keyalg RSA -keysize 2048 \
  -validity 1 -storepass testpass -keypass testpass \
  -dname 'CN=BNB Test Signer, O=Test, C=XX' -keystore "$KS" >/dev/null 2>&1

OUT="$(BNB_STORE_PASS=testpass bash "$ROOT/scripts/inventory-android-signers.sh" --keystore "$KS")"
printf '%s\n' "$OUT"
FPR="$(printf '%s\n' "$OUT" | awk '{print $3}' | head -1)"
[[ "$FPR" =~ ^[0-9a-f]{64}$ ]] || { echo "FAIL: no 64-hex fingerprint" >&2; exit 1; }
if printf '%s\n' "$OUT" | grep -q 'testpass'; then
  echo "FAIL: password leaked into output" >&2
  exit 1
fi
echo "PASS: Android signer inventory"
