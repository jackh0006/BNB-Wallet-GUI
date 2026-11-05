#!/usr/bin/env bash
# Build a signed Android arm64 release APK of BNB Wallet GUI.
#
# Signing material is NEVER stored in this repository. The caller must provide
# an existing keystore and its credentials through the environment:
#
#   BNB_KEYSTORE   absolute or relative path to a .jks/.keystore file
#   BNB_KEY_ALIAS  key alias inside that keystore
#   BNB_STORE_PASS keystore password
#   BNB_KEY_PASS   key password (may equal BNB_STORE_PASS)
#   BNB_EXPECTED_SIGNER_SHA256 SHA-256 certificate digest of the approved,
#                              rotated Android release signer (64 hex digits)
#
# Optional:
#   BNB_VERSION    version string used in the output filename (default: from pubspec.yaml)
#   BNB_OUTDIR     output directory (default: ./dist)
#   BNB_GPG_KEY    GPG key id for the detached signature (default: skip signing)
#
# The keystore is not generated here. A missing keystore is a hard error:
# silently minting a new signing identity would produce an APK that cannot be
# upgraded over previous installs and would hide a lost release key.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${BNB_KEYSTORE:?BNB_KEYSTORE must point to a release keystore (never commit it)}"
: "${BNB_KEY_ALIAS:?BNB_KEY_ALIAS is required}"
: "${BNB_STORE_PASS:?BNB_STORE_PASS is required}"
: "${BNB_KEY_PASS:?BNB_KEY_PASS is required}"
: "${BNB_EXPECTED_SIGNER_SHA256:?BNB_EXPECTED_SIGNER_SHA256 is required (the approved release signer certificate SHA-256)}"

EXPECTED_SIGNER="${BNB_EXPECTED_SIGNER_SHA256,,}"
if [[ ! "$EXPECTED_SIGNER" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: BNB_EXPECTED_SIGNER_SHA256 must be a 64-character hex digest." >&2
  exit 1
fi

if [[ ! -f "$BNB_KEYSTORE" ]]; then
  echo "ERROR: keystore not found: $BNB_KEYSTORE" >&2
  echo "Provide an existing release keystore. This script never creates one." >&2
  exit 1
fi

case "$BNB_KEYSTORE" in
  "$ROOT"/*)
    if git ls-files --error-unmatch "${BNB_KEYSTORE#"$ROOT"/}" >/dev/null 2>&1; then
      echo "ERROR: the keystore is tracked by git. Remove it from the index and rotate the key." >&2
      exit 1
    fi
    ;;
esac

VERSION="${BNB_VERSION:-$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -1)}"
VERSION="${VERSION:-0.0.0}"
OUTDIR="${BNB_OUTDIR:-$ROOT/dist}"
APK="$OUTDIR/bnb-wallet-${VERSION}-android-arm64.apk"

mkdir -p "$OUTDIR"

echo "[1/4] Building release APK (android-arm64) ..."
flutter build apk --release --target-platform android-arm64

UNSIGNED=$(find build/app/outputs/flutter-apk -name '*.apk' | head -1)
if [ -z "$UNSIGNED" ]; then
  echo "ERROR: release APK not found" >&2
  exit 1
fi
echo "Unsigned APK: $UNSIGNED"

echo "[2/4] Signing with apksigner (v3 scheme) ..."
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$HOME/Android/Sdk/build-tools/36.0.0}"
APKSIGNER="$ANDROID_BUILD_TOOLS/apksigner"
ZIPALIGN="$ANDROID_BUILD_TOOLS/zipalign"
if [ ! -x "$APKSIGNER" ] || [ ! -x "$ZIPALIGN" ]; then
  echo "ERROR: Android build-tools not found under $ANDROID_BUILD_TOOLS" >&2
  echo "Set ANDROID_BUILD_TOOLS to a directory containing apksigner and zipalign." >&2
  exit 1
fi

# Credentials are passed as env: references, so passwords do not appear in the
# process list or shell history.
"$APKSIGNER" sign \
  --ks "$BNB_KEYSTORE" \
  --ks-key-alias "$BNB_KEY_ALIAS" \
  --ks-pass env:BNB_STORE_PASS \
  --key-pass env:BNB_KEY_PASS \
  --min-sdk-version 29 \
  --v3-signing-enabled true \
  --v4-signing-enabled false \
  --out "$APK" \
  "$UNSIGNED"

"$ZIPALIGN" -c -p 4 "$APK" >/dev/null
echo "[3/4] Verifying signatures ..."
CERT_INFO="$("$APKSIGNER" verify --print-certs "$APK")"
"$APKSIGNER" verify "$APK" >/dev/null
ACTUAL_SIGNER="$(printf '%s\n' "$CERT_INFO" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | tr -d ':' | tr '[:upper:]' '[:lower:]')"
if [[ "$ACTUAL_SIGNER" != "$EXPECTED_SIGNER" ]]; then
  echo "ERROR: APK signer certificate does not match BNB_EXPECTED_SIGNER_SHA256." >&2
  echo "Refusing to emit an artifact signed by an unapproved key." >&2
  exit 1
fi

sha256sum "$APK" > "$APK.sha256"
echo "[4/4] Done"
if [ -n "${BNB_GPG_KEY:-}" ]; then
  gpg --batch --yes --digest-algo SHA256 \
    --default-key "$BNB_GPG_KEY" \
    --detach-sign --armor "$APK"
  echo "      $APK.asc"
else
  echo "      (no GPG key supplied; set BNB_GPG_KEY for a detached signature)"
fi

echo "APK:    $APK"
echo "SHA256: $APK.sha256"
echo "Signer certificate SHA-256: $ACTUAL_SIGNER"
