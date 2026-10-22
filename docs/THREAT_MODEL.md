# Threat Model — BNB Wallet GUI v1.0.3

Created by jackh0006 (jackh109867@gmail.com)

This page states plainly what the wallet protects against, what it does not,
and where it fails. Nothing here should be read as "unhackable" or "military
grade". Software carries risk; this document describes ours.

## Assets

| Asset | Where it lives | How it is protected |
|---|---|---|
| 24-word seed phrase | In memory only after unlock; in the vault file only Argon2id+device-bound double-wrapped | Two independent wrappers must both open; see docs/CRYPTO.md |
| Private keys | In memory after unlock; persisted only inside the vault | Same envelope as the seed |
| Vault password | Never stored | Only an Argon2id verifier-side KEK exists; there is no recovery path |
| Device-bound secret | Platform secure store (Android Keystore-backed preferences / libsecret on Linux) | Never in prefs or the vault file |
| App-lock PIN | Only as a salted Argon2id hash in secure storage | Exponential backoff on failures: 1 s, 2 s, 4 s … capped at 15 min |
| BscScan API key | Secure storage | Public-but-private value; erased with "Erase all data" |
| Transaction history | Not persisted at all | Fetched live from the explorer API; nothing on disk |
| Non-secret config (network, RPC nodes, Tor host/port, auto-lock) | SharedPreferences | No secrets by policy |

## What this wallet defends against

1. **Stolen vault file.** A copy of `bnb-wallet-vault.bnb` alone is inert:
   it needs both your password and the device-bound secret. Moving the file
   to another machine, or exfiltrating it via malware, yields nothing.
2. **Weak passwords / offline brute force.** Any password guess costs an
   Argon2id run (64 MiB, t=3, p=4) per attempt, per salt. There are no
   shortcuts in the file: parameters live in an authenticated header.
3. **Tampering / parameter downgrade.** The entire header (magic, version,
   KDF parameters, salt) is authenticated data for every AEAD box. Flipping
   a byte — or rewriting parameters to a weaker KDF — fails authentication.
4. **Malicious contacts / address poisoning.** The send dialog shows the
   full grouped, checksummed address and warns when a recipient shares a
   4+ character prefix or suffix with an address already on the device —
   the classic "drip address" scam.
5. **Contract-recipient mistakes.** Before confirmation, the app reads the
   recipient's on-chain code and warns when it is a contract.
6. **Shoulder surfing & screen capture (Android).** FLAG_SECURE prevents
   screenshots and app-switch thumbnails. No equivalent toggle exists on
   Linux desktop — that is a documented gap, see below.
7. **Idle exposure.** Auto-lock (configurable; 60 s default) and an
   immediate lock on backgrounding clear keys from memory.
8. **PIN guessing across restarts.** The backoff window is persisted in
   secure storage, so killing the app does not reset the counter.
9. **Keyboard side channels for seeds.** Seeds are entered by tapping
   official BIP-39 words through a picker; the IME/keyboard never receives
   the phrase, so gesture-typing traces and auto-learn dictionaries stay
   clean.
10. **Network observers (when Tor mode is on).** All RPC and explorer
   traffic is routed through a local SOCKS5 connector (Tor). DNS travels
   inside the tunnel. If the proxy is down, calls fail — the app never
   silently falls back to a direct connection.

## What this wallet does NOT defend against

Honesty section. These are real limits, not corner cases.

- **A compromised device or OS.** Keyloggers, rootkits, screen readers, or
  a malicious keyboard on a rooted/android-modified device can defeat any
  local protection, including the secure store. Out of scope.
- **Malicious RPC endpoints or explorer API.** A lying endpoint can show
  fake balances or reflect the wrong history. The wallet does not verify
  chain data independently (light-client proofs are not implemented).
- **On-chain privacy.** Blockchains are public ledgers. Any address you
  transact with, and everyone running a node, can link amounts and
  counterparties. Tor hides *where you asked*, not *what the chain says*.
- **ISP/traffic analysis with Tor on.** Your ISP still sees that you are
  sending traffic to Tor (or to a bridge endpoint). It does not see the
  destinations inside the tunnel unless it also runs the guard.
- **Tor entry/exit observers.** A malicious guard with a malicious exit
  could correlate traffic patterns for non-TLS traffic; the wallet is
  HTTPS-only, so exits see ciphertext only.
- **Clipboard.** Addresses and amounts can be copied. Malware reading the
  clipboard can substitute addresses. Always compare the full grouped
  address in the confirmation dialog.
- **Linux FLAG_SECURE gap.** On desktop, screenshots are not blocked at
  the toolkit level. Lock your session when leaving the machine.
- **Flash shred guarantees.** "Erase all data" overwrites the vault with
  random bytes before deletion, but wear-leveling means copies can linger
  in flash. The real guarantee is crypto-erasure: deleting the device
  secret leaves the ciphertext permanently unverifiable.
- **Seed loss.** There is no recovery. If you lose the seed phrase and
  forget the vault password, the funds are gone. The app cannot fix this.
- **User error.** Sending to the wrong (valid) address, losing the seed,
  or confirming a scam transaction is out of scope for any software.
- **Independent verification — honest status.** The cryptography sits on
  audited, published primitives (Argon2id, XChaCha20-Poly1305, HKDF — from
  the pinned `cryptography` package; SOCKS5 from `socks5_proxy`), and this
  repository documents and tests what it composes from them: see
  docs/STANDARDS.md for the subsystem-by-subsystem proof map, including
  commands you can run yourself in five minutes (verify signatures with GPG,
  watch the app's network with strace, read the vault's public byte layout,
  inspect the shipped deb's file layout). What no software author alone can
  hand you is a **third-party security audit of this release** — if you plan
  to hold serious value here, require one before doing so, and ask me for
  the latest audit statement: **jackh109867@gmail.com**. Everything else on
  this page is checkable, and this document says explicitly that the checks
  it describes have been run for this build.

## When Tor mode is useful, and when it is not

Useful: reducing which nodes see *your IP asking about your addresses* —
useful if your address is linked to a publicly known identity and you do
not want the RPC provider to correlate it.

Not useful: hiding activity from the chain, hiding identity already baked
into past transactions, or bypassing a malware/keyboard compromise.

## Responsible disclosure

Found an issue? Contact jackh0006 <jackh109867@gmail.com>. Please include
reproduction steps. Do not test against addresses you do not own.

Anything in this document you cannot reproduce or that sounds like trust
instead of proof? Email me — I will show you the runnable proof, or say
plainly that it can only be proven by use (docs/STANDARDS.md explains which
is which).
