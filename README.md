# BNB Wallet

A Linux amd64 desktop wallet for BNB Smart Chain. It is local, self-custodial,
AGPL-3.0-or-later software: the wallet owner controls the recovery phrase and
the source can be inspected, built, and redistributed.

Created and maintained by **jackh0006** ([jackh109867@gmail.com](mailto:jackh109867@gmail.com)).
The project is AI-assisted and self-assessed: automated tools and AI may help
with implementation, review, and documentation, but neither replaces an
independent security audit.

> Important: this project is self-assessed, not independently reviewed. No
> test suite, security score, or software wallet can guarantee the safety of
> large amounts. For substantial savings, use a hardware wallet and make a
> small transfer first.

## What it does

- Creates and restores BIP-39 wallets; derives EVM addresses and signs locally.
- Encrypts the vault with Argon2id and XChaCha20-Poly1305; writes through a
  hardened atomic Linux storage path.
- Supports BSC RPC nodes, optional Tor/SOCKS routing, HTTPS-only custom nodes,
  TLS SPKI pins, and fail-closed privacy routing.
- Reviews a transaction before signing: full checksummed address, chain,
  nonce, fees, maximum cost, poisoning checks, simulation, and safe handling
  of an uncertain broadcast result.
- Includes offline cold-wallet request/sign/verify/broadcast roles and an
  independent ethers.js verification check.
- Stores receipts and activity data encrypted at rest; provides lock, PIN
  backoff, idle lock, and erase-all-data controls.

## Evidence, not a score

Security is not a single measurable number. A credible assessment needs code
review, reproducible test evidence, release provenance, and hands-on testing
on the device that will hold funds. This repository publishes the commands
and limitations needed to judge it:

| Evidence | Where to inspect |
|---|---|
| Threats, protections, and residual risks | [Threat model](docs/THREAT_MODEL.md) |
| Security findings and exact scope | [Security self-assessment](SECURITY_AUDIT.md) |
| Reproducible automated checks | [Testing guide](docs/TESTING.md) |
| Dependency inventory | [SBOM](docs/SBOM.json) |
| Build/install gate | [Release checklist](docs/RELEASE_CHECKLIST.md) |
| Per-version status and confirmation rule | [Release evidence](docs/RELEASE_EVIDENCE.md) |
| Private vulnerability reporting | [Security policy](SECURITY.md) |

## Download and verify the Linux package

Only download a `.deb`, its detached `.asc` signature, and `SHA256SUMS` from
the same GitHub Release. Obtain the maintainer's GPG fingerprint independently
before trusting a signature.

```bash
sha256sum --check SHA256SUMS
gpg --verify bnb-wallet-<version>-amd64.deb.asc bnb-wallet-<version>-amd64.deb
sudo apt install ./bnb-wallet-<version>-amd64.deb
```

Never install a package from a chat attachment, a URL shortener, or an
unverified mirror. Do not type a seed phrase into a website, terminal, or
support message.

## Before sending funds

1. Install from a verified release and keep the `.deb`, checksum, signature,
   and release commit together.
2. Create a wallet, write the recovery phrase on paper, and verify the backup
   before funding it. No photo, cloud note, password manager, or clipboard.
3. Test restoring on a separate clean installation before receiving material
   funds.
4. Send a tiny amount first. Confirm the full recipient address from an
   independent source; never trust a recently copied address by itself.
5. Keep the operating system updated, use a separate user account, and lock
   the screen. Malware or a compromised OS can defeat any desktop wallet.

The fuller non-expert instructions are in [docs/FAMILY_GUIDE.md](docs/FAMILY_GUIDE.md).

## How it compares

This is a feature comparison, not a safety ranking. Features vary by version
and configuration; verify claims against each project's current documentation.

| Property | BNB Wallet | Typical browser-extension wallet | Typical hardware wallet |
|---|---:|---:|---:|
| Local signing | Yes | Yes | Yes |
| Seed exposed to browser extensions | No browser component | Often browser-hosted | No |
| Open source | Yes (AGPL-3.0-or-later) | Varies | Varies |
| Deterministic Linux `.deb` verification material | SHA-256 + GPG signature | Varies | Usually vendor package |
| Offline signing workflow | Built in | Usually external/limited | Device-dependent |
| Protection from a compromised desktop OS | No | No | Better: key remains on device |
| Independent external security review | No | Varies | Varies |

The point of BNB Wallet is an inspectable Linux-native BSC workflow with
encrypted local storage, strict transaction review, privacy routing, and a
cold-wallet protocol in one codebase. It is not a replacement for a hardware
wallet when the consequence of loss is high.

## Build and verify from source

Requirements: current stable Flutter/Dart, Node.js, npm, Python 3, Ubuntu or
Debian amd64 build dependencies, and a configured GPG signing key for a final
release package.

```bash
flutter pub get
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
(cd verification && npm ci && node verify.cjs)
python3 scripts/dependency-audit.py
python3 scripts/sbom.py --out docs/SBOM.json
bash scripts/build-deb.sh
BNB_RELEASE_DEB='/home/mhh06/Downloads/BNB Wallet/bnb-wallet-<version>-amd64.deb' \
  bash scripts/release-check.sh
```

`build-deb.sh` creates a `.deb`, `SHA256SUMS`, and detached GPG signature in
`/home/mhh06/Downloads/BNB Wallet/`. The release gate refuses a package with
no signature or matching checksum.

## Responsible disclosure and license

Do not create public vulnerability issues. See [SECURITY.md](SECURITY.md) for
private reporting and rotation guidance. The [AGPL-3.0-or-later license](LICENSE)
applies: people who receive and use modified network-interacting versions are
entitled to the corresponding source under its terms.

## Donate

Donations are optional and support continued open-source development. The
author's public EVM receiving address, also published in the related
`bnb-terminal-wallet` repository, is:

| Network / asset | Address |
|---|---|
| BNB Smart Chain (BNB or BEP-20 tokens) | `0xdad428900a4359be8f76b3062df34211582e09eb` |
| Ethereum (ETH or ERC-20 tokens) | `0xdad428900a4359be8f76b3062df34211582e09eb` |

Verify the full address from more than one official project location before
sending. Donations are irreversible and are not a purchase, investment, or
support entitlement.
