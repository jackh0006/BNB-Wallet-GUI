# Release Signing Checklist (Owner Only)

This checklist is for the release owner. Do not run it with an agent-generated
or test key. Do not commit private keys, passwords, or `.gnupg` contents.

## 1. Confirm the artifact and source

```bash
cd /approved/release/workspace
git status --porcelain            # must be empty
git rev-parse HEAD                # must equal the candidate source commit
sha256sum bnb-wallet-1.0.10-amd64.deb
python3 scripts/check_release_identity.py --artifact bnb-wallet-1.0.10-amd64.deb
```

The identity validator must pass before signing. The artifact must have been
built from a clean archive of the recorded source commit.

## 2. Confirm the owner key

On the offline/approved signing host:

```bash
export GNUPGHOME=/secure/owner/gnupg   # owner-controlled
gpg --list-secret-keys --with-colons
gpg --fingerprint <owner-key>
```

Compare the full 40-hex fingerprint with the fingerprint published through an
independent channel. Do not trust a fingerprint supplied only in the same
repository or chat.

## 3. Sign the checksum manifest

```bash
scripts/sign-release.sh \
  --deb bnb-wallet-1.0.10-amd64.deb \
  --key <owner-key-fingerprint> \
  --outdir /approved/release/out
```

Expected output: `SHA256SUMS`, `SHA256SUMS.asc`, and the signing fingerprint.

## 4. Verify independently

On a separate clean keyring containing only the owner's public key:

```bash
scripts/verify-release-signature.sh \
  --deb bnb-wallet-1.0.10-amd64.deb \
  --sums /approved/release/out/SHA256SUMS \
  --sig /approved/release/out/SHA256SUMS.asc \
  --fingerprint <owner-key-fingerprint>
```

Both lines must say PASS. Then run the test suite from the exact source commit.

## 5. Failure cases that must be rejected

- Wrong fingerprint.
- Modified `.deb`.
- Modified `SHA256SUMS`.
- Missing `.asc`.
- Revoked or expired key.
- Untrusted public key.
- More than one checksum line.
- A package name that does not match the manifest.

`scripts/test_release_signing.sh` exercises the first four with a disposable
test key. Revocation/expiry requires a real key lifecycle and must be checked
on the owner's keyring.

## 6. Publish only after verification

Publish:

- `.deb`
- `SHA256SUMS`
- `SHA256SUMS.asc`
- public key fingerprint and independent distribution instructions
- SBOM, manifest, test summary, known limitations, and release evidence

Never publish an unsigned or unverified package. Never describe provenance as
reproducibility, and never describe a self-audit as an independent audit.

## Android

Android signing is separate and remains **BLOCKED** until the historical key is
denylisted and a replacement signer is approved for the actual distribution
channel. Do not reuse this checklist for APK signing.
