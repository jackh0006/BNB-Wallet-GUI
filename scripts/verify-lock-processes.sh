#!/usr/bin/env bash
# Independent-OS-process verification for the production PosixFs flock path.
# Uses stdout/stdin barriers, never sleeps, and exits nonzero on any failure.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

dart_bin="${DART_BIN:-$(command -v dart || true)}"
if [[ -z "$dart_bin" || ! -x "$dart_bin" ]]; then
  echo "Set DART_BIN to the Dart executable used by this Flutter checkout." >&2
  exit 69
fi
helper=("$dart_bin" run tool/lock_process_helper.dart)
lock_dir="$(mktemp -d /tmp/x-wallet-lock.XXXXXX)"
trap 'rm -rf "$lock_dir"' EXIT
chmod 700 "$lock_dir"

start_holder() {
  coproc HOLDER { "${helper[@]}" "$lock_dir" hold; }
  IFS= read -r acquired <&"${HOLDER[0]}"
  IFS=' ' read -r locked holder_pid <&"${HOLDER[0]}"
  [[ "$acquired" == ACQUIRED && "$locked" == LOCKED && "$holder_pid" =~ ^[0-9]+$ ]]
}

start_holder
[[ "$("${helper[@]}" "$lock_dir" try)" == CONTENDED ]]
printf '\n' >&"${HOLDER[1]}"
wait "$HOLDER_PID"
[[ "$("${helper[@]}" "$lock_dir" try)" == ACQUIRED ]]

set +e
"${helper[@]}" "$lock_dir" throw >/dev/null 2>&1
throw_status=$?
set -e
[[ "$throw_status" -ne 0 ]]
[[ "$("${helper[@]}" "$lock_dir" try)" == ACQUIRED ]]

start_holder
kill -KILL "$holder_pid"
set +e
wait "$HOLDER_PID"
killed_status=$?
set -e
[[ "$killed_status" -eq 137 ]]
[[ "$("${helper[@]}" "$lock_dir" try)" == ACQUIRED ]]

[[ "$(stat -c '%a:%s' "$lock_dir/.bnb-wallet-storage.lock")" == 600:0 ]]
printf 'independent-process lock verification: PASS\n'
