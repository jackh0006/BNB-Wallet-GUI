# BNB Wallet GUI (v1.0.5)

A security-hardened GUI wallet for BNB Smart Chain, made by jackh0006
(jackh109867@gmail.com) from their v1 terminal wallet. Pure Dart networking
(no vendored node, no WebViews).

## What is new in 1.0.5 — the freeze fix

Two taste-test findings from Ubuntu said the app froze ("Force Quit / Wait")
while creating a wallet and while switching networks. Root cause: on Linux the
wallet's cryptography ran on the window's own thread, so 64 MiB memory-hard
Argon2id froze the desktop.

- **Heavy crypto moved to worker isolates** (`compute()`): vault
  encrypt/decrypt and PIN hashing run on a helper core with byte-identical
  output — same envelope, same `BNBVL004` format, same security. The window
  now keeps answering the desktop while it works.
- **Narration during work**: "I stretch 64 MB of memory into armor for your
  vault — one moment…" and the finishing line with the real millisecond cost,
  in the Home connection story.
- **10-second timebox per network step**: a hanging RPC host can no longer
  stall the connect sequence; the story log plainly says "I waited 10 seconds
  and it stayed silent" and moves to the next door.
- Honest record in docs/SECURITY.md and docs/STANDARDS.md, verified by the
  new worker round-trip tests (`test/workers_test.dart`).

## What is new in 1.0.4

- **Connection story on Home**: every blockchain action is narrated in plain
  words — whom I asked, how long it took, which chain it confirmed, whether
  it went through Tor, and that your keys never leave the device.
- **Test RPC tells the truth**: latency, chain-id match (or mismatch), latest
  block, and a verdict a child could read — no more bare "tested".
- **Terminal-grade node book**: add / edit / remove / activate / test nodes
  per network side, duplicate detection, one-tap reset to the official list.
- **Network switch fixes**: switching mainnet ↔ testnet updates every screen
  immediately and narrates the handback; a dead node explains itself.
- **Vault-aware Send**: if you already made a wallet, Send opens it by vault
  password instead of asking you to create/import again.
- docs/STANDARDS.md — every subsystem mapped to its official standard with
  the runnable proof.

## What is new in 1.0.3 (carried over)

- **Two-factor encrypted vault** (`BNBVL004`): password + device-bound key;
  a copied file alone is inert. v1.0.2 vaults migrate transparently.
- **Erase all data**, **Argon2id PIN** with persisted lockout, **idle
  auto-lock**, **Tor/SOCKS5 privacy mode** (fail-closed), **seed
  word-picker**, **send safety** (full grouped EIP-55, poisoning +
  contract warnings), and the fixed `INTERNET` permission for release
  builds.

Read docs/THREAT_MODEL.md (honest limits), docs/STANDARDS.md (proof map),
docs/SECURITY.md (controls), docs/CRYPTO.md (byte-level spec).
Also shipped: LICENSE (AGPL-3.0-or-later), PRIVACY.md, ARCHITECTURE.md,
CONTRIBUTING.md, CHANGELOG.md, SPEC-COMPLIANCE.md (why every spec line is
done, partially done, or an honest deviation), and docs/SBOM.json — the
deterministic component inventory `python3 scripts/sbom.py` regenerates
from the committed lockfile. `python3 scripts/check_token_sources.py`
verifies the trusted token-source links from docs/SPEC-COMPLIANCE §10e
before each release.

## Security quick-start

1. Write down the 24-word recovery phrase on paper — no photos, no cloud.
2. Set an app-lock PIN (Settings → App lock) and an auto-lock window.
3. Finish privacy setup **before** doing sensitive lookups is fine either
   way: enabling Tor simply rebuilds the connection.
4. "Erase all data" is for handing over or decommissioning a device.
   Funds are recoverable only with the phrase.

## Notes on the Tor mode

- Setup: `sudo apt install tor` (Ubuntu; SOCKS on 127.0.0.1:9050) or
  Orbot on Android. Bridges are configured inside Orbot/tor, not here.
- What it hides: which RPC endpoints you query, from your ISP/local
  network. DNS stays in the tunnel.
- What it cannot hide: traffic analysis to the Tor entry point, activity
  already on the chain, or history your address already exposed.

## Development

```bash
flutter pub get
flutter analyze lib
scripts/test-suite.sh   # sequential-aware runner (see dart_test.yaml)
scripts/build-deb.sh    # the release line: a signed amd64 .deb
```

`scripts/test-suite.sh` runs the light suites two-wide and the heavy
Argon2id (`kdf`-tagged) suites strictly one at a time — on a 2-core machine,
overlapping 64 MiB derivations is the "did not complete" cascade recipe.
Release form is the deb; no APK is built on this box (the deb-only release
policy).

Artifacts land in `/home/mhh06/Downloads/BNB Wallet` with `.sha256` and
`.asc` (GPG) companions.

## Attribution

BNB Wallet — created by jackh0006 <jackh109867@gmail.com>
