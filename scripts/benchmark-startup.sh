#!/usr/bin/env bash
# Measure cold/warm startup and RSS under Xvfb. Requires Xvfb and xdotool.
# This script never invents numbers: if the window does not appear, it fails.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES="${SAMPLES:-5}"
DISPLAY_NUM="${DISPLAY_NUM:-:99}"
APP="${BNB_WALLET_BIN:-}"
if [ -z "$APP" ]; then
  if command -v bnb-wallet >/dev/null 2>&1; then
    APP="$(command -v bnb-wallet)"
  else
    APP="$ROOT/build/linux/x64/release/bundle/bnb_wallet_gui"
  fi
fi
[ -x "$APP" ] || { echo "ERROR: wallet binary not executable: $APP" >&2; exit 1; }
command -v Xvfb >/dev/null || { echo "ERROR: Xvfb not installed" >&2; exit 1; }
command -v xdotool >/dev/null || { echo "ERROR: xdotool not installed" >&2; exit 1; }

Xvfb "$DISPLAY_NUM" -screen 0 1280x800x24 >/tmp/bnb-xvfb.log 2>&1 &
XPID=$!
cleanup() {
  kill "$XPID" 2>/dev/null || true
  wait "$XPID" 2>/dev/null || true
}
trap cleanup EXIT
export DISPLAY="$DISPLAY_NUM"
sleep 1

echo "app=$APP"
echo "samples=$SAMPLES"
echo "display=$DISPLAY"
for i in $(seq 1 "$SAMPLES"); do
  start="$(date +%s%N)"
  "$APP" >/tmp/bnb-benchmark-run.log 2>&1 &
  PID=$!
  if ! timeout 25s xdotool search --sync --onlyvisible --name 'X Wallet' >/dev/null 2>&1; then
    echo "ERROR: window did not appear on sample $i" >&2
    cat /tmp/bnb-benchmark-run.log >&2 || true
    kill "$PID" 2>/dev/null || true
    exit 1
  fi
  end="$(date +%s%N)"
  rss_kib="$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ' || true)"
  elapsed_ms=$(( (end - start) / 1000000 ))
  echo "sample=$i startup_ms=$elapsed_ms rss_kib=${rss_kib:-unknown}"
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  sleep 0.5
done
