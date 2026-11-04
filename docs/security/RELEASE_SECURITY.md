# RELEASE_SECURITY.md — Release Signing and Distribution Security

**Date**: 2026-11-03
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`

---

## Critical: Compromised Release Keystore

**The old Android release keystore (`scripts/release.keystore`) and its predictable password were committed to public Git history.**

| Artifact | Status | Action Required |
|----------|--------|-----------------|
| `scripts/release.keystore` | **REMOVED from tree** (commit `68091b0`) | **TREAT AS COMPROMISED** |
| Predictable hardcoded release password (year and local username) | **REMOVED** | **TREAT AS COMPROMISED** |
| Git history | **CANNOT REWRITE** (public, no force-push) | Document; rotate key |

**Status of rotation**: **NOT VERIFIED.** A clean current-tree scan proves only
that the tracked source tree no longer contains the material. It does not
prove the exposed credential has been invalidated, that the private key is no
longer usable elsewhere, or that any published artifact has been replaced.

**Android update implication**: Android accepts an in-place update only when
the signing lineage is accepted for the installed package. Replacing a
standalone signing key generally prevents users of APKs signed by the old key
from upgrading in place; they must uninstall (which removes app data) and
install the newly signed APK. Verify the actual signing certificate and any
Play App Signing lineage before making user-facing claims.

**Required Operational Action**:
1. Inventory the public commits and release artifacts: identify the old
   certificate fingerprint with `keytool`/`apksigner`, and map every
   distributed APK to that certificate. Do not print passwords or private
   material while doing so.
2. On an isolated trusted machine, determine whether the old keystore can
   still sign a test artifact; record only a yes/no result and certificate
   fingerprint. Do not place the credential in commands, logs, CI output, or
   reports.
3. Obtain explicit release-owner approval, then generate a replacement key
   outside this repository, back it up under the release-owner's recovery
   controls, and store its path/passwords only in a local protected
   configuration or CI secret store.
4. Sign a controlled release with the replacement, record its public
   certificate fingerprint, verify it with `apksigner`, and publish a clear
   migration notice after confirming the package/update-lineage consequences.
5. Run both scan modes and confirm no private signing artifact is tracked.
   Do not generate or commit a replacement key from this repository.

---

## Android APK Signing (`scripts/build-apk.sh`)

### Requirements (Enforced by Script)

```bash
export BNB_KEYSTORE=/path/to/release.keystore   # Must exist, NOT tracked by git
export BNB_KEY_ALIAS=mykeyalias                 # Alias in keystore
export BNB_STORE_PASS=keystore_password         # Keystore password
export BNB_KEY_PASS=key_password                # Key password (may equal store)
# Optional:
export BNB_GPG_KEY=0xABCDEF...                  # GPG key for .asc signature
export BNB_VERSION=1.0.8                        # Override pubspec version
export BNB_OUTDIR=./dist                        # Output directory
```

### Script Behavior

1. **Fails closed** if any env var missing
2. **Refuses tracked keystore**: `git ls-files` check
3. **Builds**: `flutter build apk --release --target-platform android-arm64`
4. **Signs**: `apksigner` v3 scheme, min SDK 29
5. **Verifies**: `apksigner verify --print-certs`
6. **Outputs**: `.apk`, `.apk.sha256`, optional `.apk.asc` (GPG)

### No Keystore Generation

- Script **never** creates a keystore
- Silent generation would produce unupgradeable APKs and hide lost keys
- Missing keystore = hard error with clear message

---

## Linux .deb Signing (`scripts/build-deb.sh`)

### Output

- `bnb-wallet-<version>-amd64.deb`
- `.deb.sha256` (SHA-256 checksum)
- Optional `.deb.asc` (GPG detached signature)

### GPG Signing

```bash
# In build-deb.sh:
gpg --batch --yes --digest-algo SHA256 \
  --default-key "jackh0006 <jackh109867@gmail.com>" \
  --detach-sign --armor "$DEB"
```

- **Key management**: GPG key held by maintainer (not in repo)
- **Verification**: `gpg --verify bnb-wallet-*.deb.asc bnb-wallet-*.deb`

---

## Secret Scanning (CI + Local)

### `scripts/secret-scan.sh` — Runs in GitHub Actions

**Checks**:
1. **Tracked keystores**: `*.jks`, `*.keystore`, `*.p12`, `*.pfx`, `*.pem`, `*.key`
2. **PEM private key blocks**: `-----BEGIN *PRIVATE KEY-----` in tracked files
3. **Old password pattern**: current-tree scan; `bash scripts/secret-scan.sh --history` separately reports the historical exposure without printing it
4. **Inline Android signing passwords**: `storePassword`/`keyPassword` with values
5. **Hardcoded 32-byte keys**: `privateKey`/`secretKey`/`seedPhrase` = 64 hex chars

**Pass Criteria**: The default current-tree mode has zero matches. The
`--history` inventory may report the known public exposure and is not evidence
of credential rotation.

### `.gitignore` Protection

```
*.keystore
*.jks
*.p12
*.pfx
key.properties
release-signing/
/dist/
*.apk
*.aab
*.deb
*.bak
/test_*.dart
/bin/investigate*.dart
/bin/verify_signature.dart
```

---

## SBOM (Software Bill of Materials)

### Generation

```bash
python3 scripts/sbom.py --out docs/SBOM.json
```

### Contents

- Every dependency from `pubspec.lock` + `verification/package-lock.json`
- Version + SHA-256 of each package
- License classification
- Deterministic (same lockfile = same SBOM)

### CI Enforcement

```yaml
# .github/workflows/verify.yml
- run: python3 scripts/sbom.py --out docs/SBOM.json
- name: SBOM must be committed and current
  run: git diff --exit-code docs/SBOM.json
```

---

## Release Procedure (Security Checklist)

### Pre-Release

- [ ] Version bump in `pubspec.yaml`
- [ ] `flutter analyze --no-pub` → no errors
- [ ] `bash scripts/test-suite.sh` → all pass (non-KDF 209, KDF individually)
- [ ] `bash scripts/secret-scan.sh` → clean
- [ ] `cd verification && npm ci && node verify.cjs` → pass
- [ ] `python3 scripts/sbom.py --out docs/SBOM.json` → committed
- [ ] `git diff --exit-code docs/SBOM.json` → clean
- [ ] Update `CHANGELOG.md`

### Linux .deb Release

- [ ] `bash scripts/build-deb.sh` → produces `.deb`, `.sha256`, `.asc`
- [ ] Install on clean Ubuntu 22.04/24.04 amd64 VM
- [ ] Smoke test: launch, vault create/unlock, send, network modes
- [ ] `dpkg -c bnb-wallet-*.deb` → no secrets, correct permissions
- [ ] `gpg --verify bnb-wallet-*.deb.asc bnb-wallet-*.deb`

### Android APK Release (Separate)

- [ ] New keystore generated offline, stored in secret manager
- [ ] `export BNB_KEYSTORE=... BNB_KEY_ALIAS=... BNB_STORE_PASS=... BNB_KEY_PASS=...`
- [ ] `bash scripts/build-apk.sh` → `.apk`, `.sha256`, `.asc`
- [ ] `apksigner verify --print-certs bnb-wallet-*.apk`
- [ ] Test on Android 8+ device/emulator

### Git Tag & Push

- [ ] `git tag -s v1.x.y -m "Release v1.x.y"` (GPG signed tag)
- [ ] `git push origin main --tags`
- [ ] GitHub Release: upload `.deb`, `.apk`, `.sha256`, `.asc`
- [ ] Verify GitHub release artifacts match local checksums

---

## Reproducible Builds (Target)

| Component | Status | Notes |
|-----------|--------|-------|
| **Flutter/Dart toolchain pin** | NOT DONE | Need `FLUTTER_VERSION`, `DART_SDK` pins |
| **Linux build environment** | NOT DONE | Docker image with pinned packages |
| **Android build environment** | NOT DONE | Docker image with pinned SDK/NDK |
| **Independent rebuild verification** | NOT TESTED | Compare two builds byte-for-byte |
| **SBOM determinism** | ✅ DONE | `scripts/sbom.py` from lockfile |

---

## Supply Chain Security

| Practice | Status |
|----------|--------|
| **Dependency pinning** | `pubspec.lock` + `package-lock.json` committed |
| **Vulnerability scanning** | NOT AUTOMATED (manual `flutter pub outdated`) |
| **License compliance** | SBOM includes licenses; all OSS compatible |
| **No proprietary core deps** | ✅ Core wallet uses only OSS |
| **Contribution policy** | `CONTRIBUTING.md` |
| **Vulnerability reporting** | `SECURITY.md` (jackh109867@gmail.com) |

---

## Evidence Locations

| Artifact | Location |
|----------|----------|
| Build scripts | `scripts/build-apk.sh`, `scripts/build-deb.sh` |
| Secret scan | `scripts/secret-scan.sh` |
| SBOM generator | `scripts/sbom.py` |
| SBOM output | `docs/SBOM.json` |
| CI workflow | `.github/workflows/verify.yml` |
| Gitignore | `.gitignore` |
| Release keystore (old) | **REMOVED** (was `scripts/release.keystore`) |

---

## Key Rotation Record

| Date | Key ID | Algorithm | Status | Notes |
|------|--------|-----------|--------|-------|
| ~2026-10 | Old release keystore | RSA-2048 | **COMPROMISED** | In public Git history |
| TBD | New release keystore | RSA-2048 or EC | **PENDING** | Must generate offline |

---

*This document describes release security practices. The old keystore is compromised — rotation is an operational requirement, not a code change.*
