# X Wallet

A Linux amd64 desktop wallet for BNB Smart Chain. It is local, self-custodial,
AGPL-3.0-or-later software: the wallet owner controls the recovery phrase and
the source can be inspected, built, and redistributed.

Created and maintained by **jackh0006** ([jackh109867@gmail.com](mailto:jackh109867@gmail.com)).
The project is AI-assisted and self-assessed: automated tools and AI may help
with implementation, review, and documentation, but neither replaces an
independent security audit.

**Current stable release: X Wallet 1.1.0 (`v1.1.0`).** Download and verify it from
<https://github.com/jackh0006/X-Wallet/releases/tag/v1.1.0>. The exact
per-version evidence is in [docs/releases/1.1.0.md](docs/releases/1.1.0.md).
Post-release branding commits on `main` are not part of the published artifact;
the generated status block below describes the current branch HEAD, while the
`v1.1.0` tag retains its own release evidence.

<!-- BEGIN GENERATED:status -->
> **Generated release status** — do not edit this block by hand.
>
> Version `1.1.0+5` · status **INCOMPLETE**
> Tests: 49 files / 308 declarations · SBOM `e0e972b3fd712761`
>
> The exact evidence commit is in `release/evidence.json` when a bundle is published. This is not an audit.
> See [the generated status report](docs/GENERATED_STATUS.md) and [the release evidence policy](docs/RELEASE_EVIDENCE.md).
<!-- END GENERATED:status -->

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
| Current implementation status and blockers | [Implementation status](IMPLEMENTATION_STATUS.md) |
| Chronological implementation log | [Implementation log](docs/IMPLEMENTATION_LOG.md) |
| Security scorecard and evidence | [Security scorecard](docs/SECURITY_SCORECARD.md) |
| Risk register | [Security risk register](docs/SECURITY_RISK_REGISTER.md) |
| Threats, protections, and residual risks | [Threat model](docs/THREAT_MODEL.md) |
| Security findings and exact scope | [Security self-assessment](SECURITY_AUDIT.md) |
| Three-pass self-audit | [Self-audit 2026-11-06](docs/SELF_AUDIT_2026-11-06.md) |
| Independent review guide | [Review guide](docs/INDEPENDENT_REVIEW_GUIDE.md) |
| Generated status, checks, and limitations | [Generated status](docs/GENERATED_STATUS.md) |
| Machine-readable release manifest | [Manifest](release/manifest.json) |
| Test inventory (47 files) | [Test inventory](docs/testing/test-inventory.json) |
| Test results and environment | [Test results](docs/TEST_RESULTS.md) |
| Reproducible automated checks | [Testing strategy](docs/TESTING_STRATEGY.md) |
| Dependency inventory | [SBOM](docs/SBOM.json) |
| Supply-chain controls | [Supply-chain security](docs/SUPPLY_CHAIN_SECURITY.md) |
| Build/install gate | [Release checklist](docs/RELEASE_CHECKLIST.md) |
| Release process | [Release process](docs/RELEASE_PROCESS.md) |
| Release verification | [Release verification](docs/RELEASE_VERIFICATION.md) |
| Platform support | [Compatibility](docs/COMPATIBILITY.md) |
| Backup and recovery | [Backup and recovery](docs/BACKUP_AND_RECOVERY.md) |
| Release signing checklist | [Signing checklist](docs/SIGNING_CHECKLIST.md) |
| Rename compatibility | [Rename compatibility](docs/RENAME_COMPATIBILITY.md) |
| High-value custody guidance | [High-value custody](docs/HIGH_VALUE_CUSTODY.md) |
| Hardware-wallet plan | [Hardware-wallet plan](docs/HARDWARE_WALLET_PLAN.md) |
| Multisignature architecture | [Multisig architecture](docs/MULTISIG_ARCHITECTURE.md) |
| Incident response | [Incident response](docs/INCIDENT_RESPONSE.md) |
| Android signing incident | [Incident record](docs/security/INCIDENT_2026-11-KEYSTORE.md) |
| Dated competitor comparison | [Competitor analysis](docs/COMPETITORS.md) |
| Final completion guide | [Project completion](docs/PROJECT_COMPLETION.md) |
| Final internal self-audit | [Self-audit](docs/FINAL_SELF_AUDIT.md) |
| Private vulnerability reporting | [Security policy](SECURITY.md) |

## Download and verify the Linux package

Only download `x-wallet-1.1.0-amd64.deb`, `SHA256SUMS`, and any `.asc` signature
from the same GitHub Release. Obtain the maintainer's GPG fingerprint
independently before trusting a signature. If the release is marked UNSIGNED,
verify the published SHA-256 and do not describe the package as signed.

```bash
sha256sum --check SHA256SUMS
gpg --verify x-wallet-<version>-amd64.deb.asc x-wallet-<version>-amd64.deb
sudo apt install ./x-wallet-<version>-amd64.deb
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
The dated, source-linked comparison is in
[docs/COMPETITORS.md](docs/COMPETITORS.md).

| Property | X Wallet | Typical browser-extension wallet | Typical hardware wallet |
|---|---:|---:|---:|
| Local signing | Yes | Yes | Yes |
| Seed exposed to browser extensions | No browser component | Often browser-hosted | No |
| Open source | Yes (AGPL-3.0-or-later) | Varies | Varies |
| Deterministic Linux `.deb` verification material | SHA-256 + GPG signature | Varies | Usually vendor package |
| Offline signing workflow | Built in | Usually external/limited | Device-dependent |
| Protection from a compromised desktop OS | No | No | Better: key remains on device |
| Independent external security review | No | Varies | Varies |

The point of X Wallet is an inspectable Linux-native BSC workflow with
encrypted local storage, strict transaction review, privacy routing, and a
cold-wallet protocol in one codebase. It is not a replacement for a hardware
wallet when the consequence of loss is high.

## Build and verify from source

Requirements: current stable Flutter/Dart, Node.js, npm, Python 3, and Ubuntu
or Debian amd64 build dependencies. A maintainer-controlled GPG signing key is
also required for a publishable release package.

```bash
flutter pub get
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
(cd verification && npm ci && node verify.cjs)
python3 scripts/dependency-audit.py
python3 scripts/sbom.py --out docs/SBOM.json
bash scripts/build-deb.sh
BNB_RELEASE_DEB='/home/mhh06/Downloads/X Wallet/x-wallet-<version>-amd64.deb' \
  bash scripts/release-check.sh
```

`build-deb.sh` creates a `.deb` and `SHA256SUMS` in
`/home/mhh06/Downloads/X Wallet/`. Set `BNB_GPG_KEY` to an available,
authorized secret key to also create the detached signature; an unsigned local
build is diagnostic-only. The release gate refuses a package with no signature
or matching checksum.

## Responsible disclosure and license

Do not create public vulnerability issues. See [SECURITY.md](SECURITY.md) for
private reporting and rotation guidance. The [AGPL-3.0-or-later license](LICENSE)
applies: people who receive and use modified network-interacting versions are
entitled to the corresponding source under its terms.

## Free to use

X Wallet is free: no subscription, paid license, paywall, advertisement, or
payment is required for core wallet functions. Blockchain network fees are
paid to the network, not to X Wallet. Optional donations are separate.

## Donate

Donations are optional and support continued open-source development. See
[DONATE.md](DONATE.md) for the complete public multi-network address table,
copied from the author's related `BNB-Terminal-Wallet` repository. Verify the
whole address from more than one official project location before sending.
Donations are irreversible and are not a purchase, investment, or support
entitlement.
