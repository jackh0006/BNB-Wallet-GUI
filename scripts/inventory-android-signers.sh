#!/usr/bin/env bash
# Inventory public Android signing certificate fingerprints from keystores and
# APKs. Prints filenames and public SHA-256 fingerprints only; never prints
# passwords, private keys, or keystore contents.
#
# Usage:
#   BNB_STORE_PASS=... scripts/inventory-android-signers.sh --keystore <file>
#   scripts/inventory-android-signers.sh --apk <file>
set -euo pipefail

normalize() {
  printf '%s' "$1" | tr -d ':' | tr '[:upper:]' '[:lower:]'
}

is_sha256() { [[ "$1" =~ ^[0-9a-f]{64}$ ]]; }

keystores=()
apks=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --keystore) keystores+=("${2:?}"); shift 2 ;;
    --apk) apks+=("${2:?}"); shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ "${#keystores[@]}" -gt 0 ] || [ "${#apks[@]}" -gt 0 ] || {
  echo "ERROR: provide at least one --keystore or --apk" >&2
  exit 2
}

for ks in "${keystores[@]}"; do
  [ -f "$ks" ] || { echo "ERROR: keystore not found: $ks" >&2; exit 1; }
  args=(-list -v -keystore "$ks")
  if [ -n "${BNB_STORE_PASS:-}" ]; then
    args+=(-storepass:env BNB_STORE_PASS)
  fi
  out="$(keytool "${args[@]}" 2>/dev/null || true)"
  if [ -z "$out" ]; then
    echo "ERROR: could not read keystore (missing password or corrupt): $ks" >&2
    exit 1
  fi
  printf '%s\n' "$out" |
    sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' |
    while IFS= read -r line; do
      fpr="$(normalize "$line")"
      if is_sha256 "$fpr"; then
        echo "KEYSTORE $ks $fpr"
      fi
    done
done

for apk in "${apks[@]}"; do
  [ -f "$apk" ] || { echo "ERROR: APK not found: $apk" >&2; exit 1; }
  build_tools="${ANDROID_BUILD_TOOLS:-$HOME/Android/Sdk/build-tools/36.0.0}"
  apksigner="$build_tools/apksigner"
  if [ -x "$apksigner" ]; then
    "$apksigner" verify --print-certs "$apk" |
      sed -n 's/^Signer #1 certificate SHA-256 digest: //p' |
      while IFS= read -r line; do
        fpr="$(normalize "$line")"
        is_sha256 "$fpr" && echo "APK $apk $fpr"
      done
  else
    cert="$(
      unzip -p "$apk" 'META-INF/*.RSA' 2>/dev/null |
        keytool -printcert 2>/dev/null |
        sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' |
        head -1
    )"
    fpr="$(normalize "${cert:-}")"
    if is_sha256 "$fpr"; then
      echo "APK $apk $fpr"
    else
      echo "ERROR: could not read APK signer: $apk" >&2
      exit 1
    fi
  fi
done
