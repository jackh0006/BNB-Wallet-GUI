#!/usr/bin/env bash
# Verify an APK's signing certificate against an approved fingerprint and a
# denylist of compromised fingerprints. Prints fingerprints only; never reads,
# prints, or copies private key material.
#
# Usage:
#   scripts/verify-android-signer.sh <apk> [--allow <sha256>]... \
#       [--deny <file>] [--require-deny]
#
# Exit codes:
#   0  signature verified and the certificate is not denied (and, when --allow
#      is supplied, exactly matches one allowed fingerprint)
#   1  verification failed, signer denied, signer not allowed, or the denylist
#      is missing/empty when it is required
#   2  usage error
set -euo pipefail

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

APK=""
DENY_FILE=""
REQUIRE_DENY=false
declare -a ALLOW=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --allow)
      [ "$#" -ge 2 ] || usage
      ALLOW+=("${2,,}")
      shift 2
      ;;
    --deny)
      [ "$#" -ge 2 ] || usage
      DENY_FILE="$2"
      shift 2
      ;;
    --require-deny)
      REQUIRE_DENY=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage
      ;;
    *)
      if [ -n "$APK" ]; then
        echo "ERROR: only one APK may be supplied." >&2
        exit 2
      fi
      APK="$1"
      shift
      ;;
  esac
done

[ -n "$APK" ] || usage
[ -f "$APK" ] || { echo "ERROR: APK not found: $APK" >&2; exit 1; }

normalize() {
  printf '%s' "$1" | tr -d ':' | tr '[:upper:]' '[:lower:]'
}

is_sha256() {
  [[ "$1" =~ ^[0-9a-f]{64}$ ]]
}

ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$HOME/Android/Sdk/build-tools/36.0.0}"
APKSIGNER="$ANDROID_BUILD_TOOLS/apksigner"

FINGERPRINTS=""
if [ -x "$APKSIGNER" ]; then
  "$APKSIGNER" verify "$APK" >/dev/null
  FINGERPRINTS="$("$APKSIGNER" verify --print-certs "$APK" |
    sed -n 's/^Signer #1 certificate SHA-256 digest: //p' |
    while IFS= read -r line; do normalize "$line"; echo; done)"
else
  # Fallback for a v1/JAR-signed artifact: read the public certificate from
  # META-INF.  A v2/v3-only APK has no such entry, so this path fails closed.
  CERT_FILE="$(mktemp)"
  trap 'rm -f "$CERT_FILE"' EXIT
  if ! unzip -p "$APK" 'META-INF/*.RSA' >"$CERT_FILE" 2>/dev/null || [ ! -s "$CERT_FILE" ]; then
    echo "ERROR: apksigner is unavailable and no v1 certificate was found." >&2
    echo "Install Android build-tools and set ANDROID_BUILD_TOOLS." >&2
    exit 1
  fi
  FINGERPRINTS="$(keytool -printcert -file "$CERT_FILE" |
    sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' |
    while IFS= read -r line; do normalize "$line"; echo; done)"
fi

if [ -z "$FINGERPRINTS" ]; then
  echo "ERROR: could not read a signer certificate fingerprint." >&2
  exit 1
fi

if [ "$REQUIRE_DENY" = true ] && [ -z "$DENY_FILE" ]; then
  echo "ERROR: --require-deny needs --deny <file>." >&2
  exit 2
fi

declare -a DENIED=()
if [ -n "$DENY_FILE" ]; then
  if [ ! -f "$DENY_FILE" ]; then
    echo "ERROR: denylist not found: $DENY_FILE" >&2
    exit 1
  fi
  while IFS= read -r raw; do
    line="$(normalize "${raw%%#*}")"
    [ -n "$line" ] || continue
    is_sha256 "$line" || {
      echo "ERROR: malformed denylist entry in $DENY_FILE (expected 64 hex)." >&2
      exit 1
    }
    DENIED+=("$line")
  done <"$DENY_FILE"

  if [ "${#DENIED[@]}" -eq 0 ] && [ "$REQUIRE_DENY" = true ]; then
    echo "ERROR: $DENY_FILE contains no confirmed compromised fingerprints." >&2
    echo "Refusing to approve an Android artifact until the historical signer" >&2
    echo "is denylisted. See docs/security/INCIDENT_2026-11-KEYSTORE.md." >&2
    exit 1
  fi
fi

for actual in $FINGERPRINTS; do
  for denied in "${DENIED[@]:-}"; do
    [ -n "$denied" ] || continue
    if [ "$actual" = "$denied" ]; then
      echo "ERROR: APK is signed by a DENYLISTED certificate: $actual" >&2
      exit 1
    fi
  done
  if [ "${#ALLOW[@]}" -gt 0 ]; then
    matched=false
    for allowed in "${ALLOW[@]}"; do
      is_sha256 "$allowed" || {
        echo "ERROR: --allow expects a 64-character hex SHA-256 fingerprint." >&2
        exit 2
      }
      if [ "$actual" = "$allowed" ]; then matched=true; fi
    done
    if [ "$matched" != true ]; then
      echo "ERROR: APK signer is not in the approved fingerprint list: $actual" >&2
      exit 1
    fi
  fi
  echo "Signer certificate SHA-256: $actual"
done

echo "Android signer verification: PASS"
