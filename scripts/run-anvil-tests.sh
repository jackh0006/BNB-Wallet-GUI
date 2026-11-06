#!/usr/bin/env bash
# Run the real-EVM integration suite against a local Anvil chain.
#
# Anvil is intentionally pinned in CI to the version verified for this
# repository. The test accounts are Anvil's public deterministic development
# accounts; no real funds or wallet secrets are used.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${ANVIL_PORT:-8545}"
URL="http://127.0.0.1:${PORT}"
LOG="${ANVIL_LOG:-/tmp/bnb-anvil.log}"

command -v anvil >/dev/null 2>&1 || {
  echo "ERROR: anvil not found. Install Foundry and add it to PATH." >&2
  exit 2
}

anvil --version | head -1
anvil --chain-id 97 --host 127.0.0.1 --port "$PORT" --silent >"$LOG" 2>&1 &
PID=$!
cleanup() {
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
}
trap cleanup EXIT

ready=false
for _ in $(seq 1 100); do
  if curl -fsS -X POST -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
    "$URL" 2>/dev/null | grep -q '"result":"0x61"'; then
    ready=true
    break
  fi
  sleep 0.1
done
if [ "$ready" != true ]; then
  echo "ERROR: Anvil did not become ready; log:" >&2
  tail -30 "$LOG" >&2 || true
  exit 1
fi

echo "Anvil ready at $URL (chain 97)"
ANVIL_URL="$URL" flutter test --tags integration test/integration
