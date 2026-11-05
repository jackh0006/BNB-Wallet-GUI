# Release evidence policy

This is the permanent release rule for every version. The README, security
policy, ownership notice, donation addresses, and comparison wording are
evergreen: a normal source update must not rewrite them. A release changes the
version in `pubspec.yaml`, its source, its SBOM, and its release artifacts.

The required GitHub verification workflow runs
`scripts/check_release_evidence.py`. It rejects a source version unless
`docs/releases/<major>.<minor>.<patch>.md` exists, names the exact version
(including its build suffix), and contains the marked test-result table. This
applies equally to human and AI-authored changes.

## Required evidence for a confirmed version

Before describing a version as **confirmed**, a maintainer must run these
commands from its tagged source commit and retain their unedited terminal
output with the release:

```bash
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
(cd verification && npm ci && node verify.cjs)
python3 scripts/dependency-audit.py
python3 scripts/sbom.py --out docs/SBOM.json
git diff --exit-code -- docs/SBOM.json
bash scripts/build-deb.sh
BNB_RELEASE_DEB='/absolute/path/to/bnb-wallet-<version>-amd64.deb' \
  bash scripts/release-check.sh
```

The signed tag, `.deb`, `.asc`, `SHA256SUMS`, SBOM, and command transcript
must all name or unambiguously identify the same source revision. A clean
Ubuntu install-and-launch test, upgrade/uninstall check, and data-preservation
check are required before public release.

## Status vocabulary

- **Confirmed**: every required command exited zero, the artifact matched its
  checksum and signature, and the clean-install checks are recorded.
- **Partially verified**: only the listed checks passed. It must never be
  presented as a substitute for a full release gate.
- **Not tested**: no result was captured. Silence, a stalled process, or an
  interrupted run is not a pass.

No score, AI analysis, self-assessment, test result, or package signature can
guarantee safety for a real-money wallet. Independent review remains required
for a credible large-value security claim.
