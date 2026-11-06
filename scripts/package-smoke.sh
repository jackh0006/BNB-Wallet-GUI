#!/usr/bin/env bash
# Real package smoke test on Ubuntu: install, launch under Xvfb, upgrade from
# a previous package (optional), uninstall, and check user-data preservation.
#
# This requires root/apt and a disposable machine or CI runner. It is not a
# unit test. A timeout exit of 124 means the GUI stayed alive for the launch
# window; an immediate exit is a failure.
set -euo pipefail

DEB=""
PREVIOUS=""
LAUNCH_SECONDS="${LAUNCH_SECONDS:-20}"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

usage() {
  echo "Usage: $0 --deb <path> [--previous <older.deb>] [--seconds N]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --deb) DEB="${2:?}"; shift 2 ;;
    --previous) PREVIOUS="${2:?}"; shift 2 ;;
    --seconds) LAUNCH_SECONDS="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "$DEB" ] || usage
[ -f "$DEB" ] || { echo "ERROR: package not found: $DEB" >&2; exit 1; }
DEB="$(cd "$(dirname "$DEB")" && pwd)/$(basename "$DEB")"
if [ -n "$PREVIOUS" ]; then
  [ -f "$PREVIOUS" ] || { echo "ERROR: previous package not found: $PREVIOUS" >&2; exit 1; }
  PREVIOUS="$(cd "$(dirname "$PREVIOUS")" && pwd)/$(basename "$PREVIOUS")"
fi

install_pkg() {
  local path="$1"
  $SUDO apt-get install -y --no-install-recommends "$path"
}

echo "== environment =="
# shellcheck source=/dev/null
. /etc/os-release
echo "$PRETTY_NAME"
uname -m

echo "== install prerequisites =="
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq xvfb ca-certificates curl

if [ -n "$PREVIOUS" ]; then
  [ -f "$PREVIOUS" ] || { echo "ERROR: previous package not found: $PREVIOUS" >&2; exit 1; }
  echo "== install previous package =="
  install_pkg "$PREVIOUS"
  dpkg -s bnb-wallet | grep -E '^(Package|Version):'
  # A marker in the per-user data directory must survive the upgrade.
  DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bnb-wallet"
  mkdir -p "$DATA"
  printf 'upgrade-marker-%s\n' "$(date -u +%s)" >"$DATA/.upgrade-marker"
  MARKER="$(cat "$DATA/.upgrade-marker")"
  echo "marker=$MARKER"
else
  MARKER=""
fi

echo "== install candidate =="
install_pkg "$DEB"
dpkg -s bnb-wallet | grep -E '^(Package|Version|Depends):'

if [ -n "$MARKER" ]; then
  DATA="${XDG_DATA_HOME:-$HOME/.local/share}/bnb-wallet"
  [ "$(cat "$DATA/.upgrade-marker" 2>/dev/null || true)" = "$MARKER" ] || {
    echo "ERROR: upgrade did not preserve user data marker" >&2
    exit 1
  }
  echo "upgrade data preservation: PASS"
fi

echo "== launch under Xvfb =="
set +e
xvfb-run -a timeout "${LAUNCH_SECONDS}s" bnb-wallet >/tmp/bnb-wallet-launch.log 2>&1
launch_code=$?
set -e
cat /tmp/bnb-wallet-launch.log || true
if [ "$launch_code" -ne 124 ]; then
  echo "ERROR: wallet exited before the launch window (exit $launch_code)" >&2
  exit 1
fi
echo "launch: PASS (still running after ${LAUNCH_SECONDS}s)"

echo "== uninstall =="
$SUDO apt-get remove -y bnb-wallet
if command -v bnb-wallet >/dev/null 2>&1; then
  echo "ERROR: bnb-wallet binary still present after uninstall" >&2
  exit 1
fi
echo "uninstall: PASS"

echo "== reinstall =="
install_pkg "$DEB"
dpkg -s bnb-wallet | grep -E '^Version:'
echo "reinstall: PASS"

echo "Package smoke: PASS"
