# X Wallet — Project Completion

## What X Wallet is

X Wallet is a free, open-source (AGPL-3.0-or-later), local, non-custodial BNB
Smart Chain desktop wallet for Linux. It creates or imports BIP-39 wallets,
derives EVM addresses, signs locally, and stores the vault with Argon2id and
XChaCha20-Poly1305. It also provides a cold/offline signing workflow, optional
Tor/SOCKS routing, transaction review, and a hardened Linux storage path.

## Current stable version

**X Wallet 1.1.0** (`1.1.0+5`)

The stable release is published at:

<https://github.com/jackh0006/X-Wallet/releases/tag/v1.1.0>

## Download

Download only from the release page:

- `x-wallet-1.1.0-amd64.deb`
- `SHA256SUMS`
- SBOM and release documentation

The release page states whether the artifact is signed. **If no valid GPG
signature is present, the package is UNSIGNED.** Do not describe it as signed.

## Verify the SHA-256

```bash
sha256sum x-wallet-1.1.0-amd64.deb
sha256sum --check SHA256SUMS
```

Compare the output with the SHA-256 published on the GitHub release page. A
matching hash proves the download is the artifact the project published; it
does not prove the project itself is free of defects.

If a signature is published:

```bash
gpg --verify SHA256SUMS.asc SHA256SUMS
```

## Supported platform

Verified for the release process:

- Ubuntu 24.04 x86_64 (build, `.deb` install/launch/upgrade/uninstall, Xvfb
  smoke).

Not verified: Debian, Fedora, Linux ARM64, Windows, macOS, Android.
Do not claim support for these until they are built and tested.

A running Secret Service provider (normally `gnome-keyring` on Ubuntu/GNOME or
KWallet on KDE) is required. Minimal or headless sessions without one currently
fail at startup with an unhandled libsecret error; this is a documented
limitation, not a claim of headless support.

## Installation

```bash
sudo apt install ./x-wallet-1.1.0-amd64.deb
```

The Debian package is `x-wallet` and replaces `bnb-wallet` while preserving
the user-data directory and the `/usr/bin/bnb-wallet` compatibility alias.

## Backup and recovery

1. Write the 12/24-word recovery phrase on paper; never store it in a photo,
   cloud note, chat, or password manager.
2. Verify the backup before funding the wallet.
3. To restore, use **Import wallet → recovery phrase** on a clean installation.
4. Confirm the derived address against an independent record.
5. Send a small test amount first.

A copied vault file alone is inert without the device-bound secret. Losing the
recovery phrase and the vault password loses the funds; there is no recovery
service.

## Security limitations

- This is a local hot wallet; a compromised OS, malware, or same-UID attacker
  can read an unlocked session.
- The project has **not** received an independent external audit.
- The release artifact may be unsigned; its SHA-256 is published.
- RPC data is not light-client verified; a malicious provider can mislead the
  review screen.
- Dart memory cannot be securely erased; `mlockall` is best-effort.
- No hardware-wallet support; no multisig support.
- **Large-value custody: NOT APPROVED.**
- Android is blocked by a historical signing-key incident.

## Internal self-audit scope

The internal self-audit covered the key lifecycle, vault encryption, atomic
storage, transaction construction and signing, cold/offline signing, chain and
recipient validation, token/calldata handling, RPC trust, release identity,
supply chain, CI, logging, and packaging. It is documented in
[`FINAL_SELF_AUDIT.md`](FINAL_SELF_AUDIT.md). It is **not** an independent
external audit.

## Known unsupported features

- Hardware wallets (Ledger/Trezor/SafePal).
- Multisignature custody.
- Token approvals/unlimited allowances (the wallet only builds transfers).
- Camera QR scanning on Linux.
- Windows, macOS, Linux ARM64, and Android releases.

## Reporting security issues

Email **jackh109867@gmail.com** privately. Do not open a public issue. Never
send a seed phrase, private key, password, or live wallet file.

## Free use

X Wallet is free to use. There is no subscription, paid license, paywall,
advertisement, or payment required for core wallet functions. Optional
donations are separate from wallet balances and are never requested inside a
transaction confirmation. Blockchain network fees are paid to the network, not
to X Wallet.
