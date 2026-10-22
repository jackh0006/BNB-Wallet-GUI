#!/usr/bin/env bash
# Build a signed Android arm64 release APK of BNB Wallet GUI
# Output: /home/mhh06/Downloads/BNB Wallet/bnb-wallet-1.0.2-android-arm64.apk
# plus .sha256 and .asc signatures

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="/home/mhh06/Downloads/BNB Wallet"
VERSION="1.0.5"
APK="$OUTDIR/bnb-wallet-${VERSION}-android-arm64.apk"
KEYSTORE="$ROOT/scripts/release.keystore"
KEY_ALIAS="bnbwallet"
KEY_PASS="BnbWalletRelease-2026-$(whoami)"
STORE_PASS="$KEY_PASS"

mkdir -p "$OUTDIR"

echo "[1/4] Building release APK (android-arm64) ..."
cd "$ROOT"
flutter build apk --release --target-platform android-arm64

UNSIGNED=$(find build/app/outputs/flutter-apk -name '*.apk' | head -1)
if [ -z "$UNSIGNED" ]; then
  echo "ERROR: release APK not found" >&2
  exit 1
fi
echo "Unsigned APK: $UNSIGNED"

echo "[2/4] Ensuring release keystore exists ..."
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA -keysize 2048 -sigalg SHA256withRSA \
    -validity 10000 \
    -storepass "$STORE_PASS" -keypass "$KEY_PASS" \
    -dname "CN=jackh0006,O=BNB Wallet,emailAddress=jackh109867@gmail.com,C=US" \
    -noprompt >/dev/null 2>&1
fi

echo "[3/4] Signing with apksigner (v3 scheme) ..."
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$HOME/Android/Sdk/build-tools/36.0.0}"
APKSIGNER="$ANDROID_BUILD_TOOLS/apksigner"
"$APKSIGNER" sign \
  --ks "$KEYSTORE" \
  --ks-key-alias "$KEY_ALIAS" \
  --ks-pass "pass:$STORE_PASS" \
  --key-pass "pass:$KEY_PASS" \
  --min-sdk-version 29 \
  --v3-signing-enabled true \
  --v4-signing-enabled false \
  --out "$APK" \
  "$UNSIGNED"

"$ANDROID_BUILD_TOOLS/zipalign" -c -p 4 "$APK" >/dev/null
echo "[4/4] Verifying signatures ..."
"$APKSIGNER" verify --print-certs "$APK" >/dev/null
"$APKSIGNER" verify "$APK" >/dev/null

sha256sum "$APK" > "$APK.sha256"
gpg --batch --yes --digest-algo SHA256 \
  --default-key "jackh0006 <jackh109867@gmail.com>" \
  --detach-sign --armor "$APK"

echo "Done: $APK"
echo "      $APK.sha256"
echo "      $APK.asc"