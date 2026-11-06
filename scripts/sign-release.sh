#!/usr/bin/env bash
# Sign a release package with an existing owner-controlled GPG key.
#
# This script never generates, imports, or stores a private key. It refuses to
# run unless the requested secret key already exists in the active GNUPGHOME.
#
# Usage:
#   scripts/sign-release.sh --deb <path> --key <fingerprint-or-uid> [--outdir DIR]
set -euo pipefail

DEB=""
KEY=""
OUTDIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --deb) DEB="${2:?}"; shift 2 ;;
    --key) KEY="${2:?}"; shift 2 ;;
    --outdir) OUTDIR="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$DEB" ] || { echo "ERROR: --deb is required" >&2; exit 2; }
[ -n "$KEY" ] || { echo "ERROR: --key is required" >&2; exit 2; }
[ -f "$DEB" ] || { echo "ERROR: package not found: $DEB" >&2; exit 1; }
DEB="$(cd "$(dirname "$DEB")" && pwd)/$(basename "$DEB")"
OUTDIR="${OUTDIR:-$(dirname "$DEB")}"
mkdir -p "$OUTDIR"

if ! gpg --batch --list-secret-keys --with-colons "$KEY" 2>/dev/null | grep -q '^sec:'; then
  echo "ERROR: no secret key matches '$KEY' in this GNUPGHOME." >&2
  echo "This script never creates or imports a signing key." >&2
  exit 1
fi

# Refuse an ambiguous selector: exactly one primary secret key must match.
mapfile -t FINGERPRINTS < <(
  gpg --batch --list-secret-keys --with-colons --fingerprint "$KEY" 2>/dev/null |
    awk -F: '$1=="fpr"{print $10}'
)
if [ "${#FINGERPRINTS[@]}" -ne 1 ]; then
  echo "ERROR: selector matched ${#FINGERPRINTS[@]} keys; specify one fingerprint." >&2
  exit 1
fi
FPR="${FINGERPRINTS[0]}"
if [[ ! "$FPR" =~ ^[0-9A-Fa-f]{40}$ ]]; then
  echo "ERROR: could not resolve a 40-hex fingerprint." >&2
  exit 1
fi

SUMS="$OUTDIR/SHA256SUMS"
SIG="$OUTDIR/SHA256SUMS.asc"
(
  cd "$(dirname "$DEB")"
  sha256sum "$(basename "$DEB")" >"$SUMS"
)
gpg --batch --yes --armor --detach-sign --local-user "$FPR" \
  --output "$SIG" "$SUMS"
gpg --batch --verify "$SIG" "$SUMS" >/dev/null

echo "Signed checksum manifest: $SIG"
echo "Package: $DEB"
echo "SHA256SUMS: $SUMS"
echo "Signing fingerprint: $FPR"
echo "Verify with: scripts/verify-release-signature.sh --deb \"$DEB\" --sums \"$SUMS\" --sig \"$SIG\" --fingerprint \"$FPR\""
