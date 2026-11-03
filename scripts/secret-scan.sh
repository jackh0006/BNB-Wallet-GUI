#!/usr/bin/env bash
# Fail the build if high-signal secret material is present in tracked files.
#
# This is deliberately conservative: it looks for artifacts that must never be
# committed (private key blocks, Android keystores, hardcoded credentials), not
# for every occurrence of the words "password" or "secret" in documentation.
set -euo pipefail

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

# 3. Known leaked release credential from v1.0.2–v1.0.5.
if git grep -nI -E 'BnbWalletRelease-[0-9]{4}' -- . >/dev/null 2>&1; then
  report "history/current tree" "old hardcoded release keystore password"
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

echo "Secret scan: no tracked keystores, private key blocks, or known leaked credentials."
