#!/usr/bin/env bash
# Verify a release checksum manifest and its detached GPG signature.
#
# Usage:
#   scripts/verify-release-signature.sh --deb <path> --sums <SHA256SUMS> \
#     --sig <SHA256SUMS.asc> --fingerprint <40-hex>
#
# With GNUPGHOME pointing at a trusted keyring containing the owner's public
# key. Missing or ambiguous inputs fail closed.
set -euo pipefail

DEB=""; SUMS=""; SIG=""; EXPECTED=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --deb) DEB="${2:?}"; shift 2 ;;
    --sums) SUMS="${2:?}"; shift 2 ;;
    --sig) SIG="${2:?}"; shift 2 ;;
    --fingerprint) EXPECTED="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for value in "$DEB" "$SUMS" "$SIG" "$EXPECTED"; do
  [ -n "$value" ] || { echo "ERROR: --deb, --sums, --sig and --fingerprint are required" >&2; exit 2; }
done
for file in "$DEB" "$SUMS" "$SIG"; do
  [ -f "$file" ] || { echo "ERROR: missing file: $file" >&2; exit 1; }
done
EXPECTED="$(printf '%s' "$EXPECTED" | tr -d ':' | tr '[:lower:]' '[:upper:]')"
if [[ ! "$EXPECTED" =~ ^[0-9A-F]{40}$ ]]; then
  echo "ERROR: --fingerprint must be a 40-hex fingerprint" >&2
  exit 2
fi

# Exactly one checksum line, naming this package.
if [ "$(wc -l <"$SUMS")" -ne 1 ]; then
  echo "ERROR: SHA256SUMS must contain exactly one line" >&2
  exit 1
fi
if ! grep -q " $(basename "$DEB")$" "$SUMS"; then
  echo "ERROR: SHA256SUMS does not name $(basename "$DEB")" >&2
  exit 1
fi

STATUS="$(gpg --batch --status-fd 1 --verify "$SIG" "$SUMS" 2>/dev/null || true)"
if ! printf '%s\n' "$STATUS" | grep -q '^\[GNUPG:\] VALIDSIG '; then
  echo "ERROR: signature did not verify" >&2
  exit 1
fi
for failure in BADSIG ERRSIG NO_PUBKEY REVKEYSIG EXPKEYSIG EXPSIG; do
  if printf '%s\n' "$STATUS" | grep -q "\[GNUPG:\] $failure"; then
    echo "ERROR: GPG reported $failure" >&2
    exit 1
  fi
done
ACTUAL="$(printf '%s\n' "$STATUS" | awk '/^\[GNUPG:\] VALIDSIG /{print $3; exit}' | tr '[:lower:]' '[:upper:]')"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "ERROR: signer fingerprint mismatch: expected $EXPECTED, got $ACTUAL" >&2
  exit 1
fi

(
  cd "$(dirname "$DEB")"
  sha256sum --check --strict "$SUMS"
)

echo "Signature: PASS ($ACTUAL)"
echo "Package hash: PASS"
