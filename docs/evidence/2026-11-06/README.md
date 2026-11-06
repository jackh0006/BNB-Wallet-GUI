# Evidence bundle — 2026-11-06

**Candidate:** `1.0.10+4`
**Code commit:** `e474b8956a68febf44ef780c7decf898e9050018`
**Evidence bundle source:** `b50ad2c95fb2c204fbb7803ffcc27d30483538cb`
**Tested code commit:** `90d0f7cce3c535455495e29a03c0f35e8d91de6c`
**PR:** <https://github.com/jackh0006/BNB-Wallet-GUI/pull/10>

| File | Contents |
|---|---|
| `environment.txt` | Host OS/kernel/CPU/RAM and Flutter/Dart versions |
| `full-suite-summary.txt` | Local serial full-suite summary (47/47) |
| `ci-checks.txt` | GitHub required-check results for PR #10 |
| `reproducibility-x-wallet.log` | X Wallet two clean fixed-path builds; identical archive `0e3cb4c1…` |
| `reproducibility-fixed.log` | Earlier fixed-path investigation (historical; archive `388f94bf…`) |
| `same-path-diff.txt` | Same-path rebuild diff (only a stale `native_assets.json`) |
| `package-sha256.txt` | Unsigned `.deb` SHA-256 |

## Not in this bundle

- Full test logs (large; regenerable with `bash scripts/test-suite.sh`).
- The release GPG signature (none exists).
- Clean-install logs (not tested).
- An independent audit (none performed).
- A real BSC/Anvil integration log (not implemented in this tranche).

Do not present this bundle as a complete release approval. It is evidence for
the listed checks only.
