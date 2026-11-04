#!/usr/bin/env bash
# Sequential test driver for the BNB Wallet release machine (2 cores).
#
# Phase 1 — every light suite runs two at a time (the classic default).
# Phase 2 — the `kdf`-tagged suites (real 64 MiB Argon2id derivations in
#           vault_test.dart / workers_test.dart) run STRICTLY one at a time:
#           overlapping 64 MiB derivations on two cores is what turned
#           minutes of work into "did not complete" cascades under load.
#
# Explicit paths (e.g. scripts/test-suite.sh test/foo_test.dart) always run
# sequentially, one file at a time.
#
# Full log lives in your terminal or in a redirected file — never judge a
# run from a `| tail` preview; "did not complete" after a long run means the
# runner was terminated mid-flight, not that any assertion failed.
set -euo pipefail
cd "$(dirname "$0")/.."

# The production Linux launcher starts with a restrictive umask.  Tests that
# exercise real storage must run under the same invariant; otherwise temp
# application directories are deliberately rejected as group-readable.
umask 0077

if [ "$#" -gt 0 ]; then
  exec flutter test --concurrency=1 "$@"
fi

flutter test --concurrency=2 --exclude-tags kdf
flutter test --concurrency=1 --tags kdf
