#!/usr/bin/env bash
# Fail the build if high-signal secret material is present in tracked files.
#
# This is deliberately conservative: it looks for artifacts that must never be
# committed (private key blocks, Android keystores, hardcoded credentials), not
# for every occurrence of the words "password" or "secret" in documentation.
set -euo pipefail

scan_history=false
if [[ "${1:-}" == "--history" ]]; then
  scan_history=true
elif [[ "$#" -ne 0 ]]; then
  echo "Usage: $0 [--history]" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

fail=0
report() {
  echo "::error file=$1::$2" >&2
  fail=1
}

# 1. Keystores and private key material must never be tracked.
while IFS= read -r -d '' file; do
  report "$file" "secret-bearing file is tracked by git"
done < <(git ls-files -z | grep -zE '\.(jks|keystore|p12|pfx|pem|key)$' || true)

# 2. PEM private key blocks inside tracked text files. Public certificates and
#    SBOM checksum manifests are fine; BEGIN PRIVATE KEY never is.
while IFS= read -r file; do
  if git show ":$file" | grep -qE -- '-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----'; then
    report "$file" "PEM private key block"
  fi
done < <(git ls-files | grep -vE '^(docs/SBOM\.json|verification/package-lock\.json)$')

# 3. Known leaked release credential. This is deliberately a current-tree
# scan: documentation must describe the historical exposure without embedding
# the matching secret-shaped string.
if git grep -nI -E 'BnbWalletRelease-[0-9]{4}' -- . >/dev/null 2>&1; then
  report "current tree" "old hardcoded release keystore password pattern"
fi

# 4. Android signing config with inline credentials.
if git grep -nI -E '(storePassword|keyPassword)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']+' -- . >/dev/null 2>&1; then
  report "android signing config" "inline storePassword/keyPassword"
fi

# 5. 32-byte hex private keys assigned to a suspicious identifier.
if git grep -nI -E '(privateKey|secretKey|seedPhrase)[[:space:]]*[:=][[:space:]]*["'"'"'](0x)?[0-9a-fA-F]{64}["'"'"']' -- . >/dev/null 2>&1; then
  report "source" "hardcoded 32-byte private key"
fi

if [ "$fail" -ne 0 ]; then
  echo "Secret scan failed. Rotate any exposed credential; do not just delete the line." >&2
  exit 1
fi

if "$scan_history"; then
  # Never print matching blob contents: history is public and the credential
  # is compromised, but CI output must not amplify it. Commit IDs establish
  # evidence for the required operational rotation.
  historical_keystore=false
  historical_credential=false
  # Do not pipe to grep -q under pipefail: grep can exit early, leaving git
  # with SIGPIPE and producing a false negative.  Both queries emit commit
  # IDs only, never historical file contents or credential-shaped text.
  if [[ -n "$(git log --all --format='%H' -- scripts/release.keystore)" ]]; then
    historical_keystore=true
  fi
  if [[ -n "$(git log --all --format='%H' -G 'storePassword|keyPassword|BnbWalletRelease' -- scripts/build-apk.sh)" ]]; then
    historical_credential=true
  fi
  if "$historical_keystore" || "$historical_credential"; then
    # This is an inventory/reporting mode, not a current-tree gate.  The
    # public-history finding is expected until an authorized history rewrite
    # (which is explicitly out of scope) and must not be mistaken for proof
    # that the exposed credential has been rotated or invalidated.
    echo "Historical secret scan: Android signing material or credential pattern found in public history; current credential validity and rotation status are unknown." >&2
  else
    echo "Historical secret scan: no matching Android signing material or credential pattern found." >&2
  fi
fi

echo "Secret scan: current tree has no tracked keystores, private key blocks, or known leaked credentials."
