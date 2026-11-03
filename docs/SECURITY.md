# Security Notes — BNB Wallet GUI v1.0.5

Created by jackh0006 (jackh109867@gmail.com)

For the exact byte layout and algorithm choices see docs/CRYPTO.md. For the
plain-language list of what is and is not protected, see docs/THREAT_MODEL.md.

## Data at rest

- One encrypted vault file (`bnb-wallet-vault.bnb`) in the app-support
  directory. Format v2 (`BNBVL004`), envelope-encrypted twice: once with an
  Argon2id key from your vault password, once with an HKDF key from a
  32-byte device secret living only in the platform secure store.
- Atomic writes: vault saves go to `<path>.tmp`, then `rename()` over the
  real file. A crash mid-save leaves the previous good vault intact, never
  a half-written one.
- File permissions tightened to 0600 on Linux/macOS after each save.
- The live Home history is in-memory only. The receipt archive
  (`bnb-wallet-receipts.bin`, envelope `BNBRCPT1`) and the activity log
  (`bnb-wallet-log.bin`, envelope `BNBLOG01`) are encrypted at rest with
  keys derived from the wallet key plus the device drawer secret, and are
  capped (200 entries / 5 MB). The pending-tx status list is plain public
  data in preferences.
- Preferences hold only public configuration, no secrets.

## App lock

- Optional PIN or local biometrics gate reopening the app.
- PIN records are `a2:<saltB64>:<hashB64>` — Argon2id with the same cost
  floor as the vault (64 MiB, t=3, p=4), constant-time comparison.
- Records written by v1.0.2 (unsalted-prefix SHA-256) are refused and
  invalidated; the app asks you to create a fresh PIN under the new scheme.
- Failed attempts scale an exponential cooldown `min(2^(n-1), 900)` seconds,
  persisted with a wall-clock window in secure storage so process restarts
  cannot reset it.

## Auto-lock

- Locks after user-configured idle time (default 60 s; 0 disables the idle
  branch), and immediately when the app goes to background.
- Locking clears private keys, the seed phrase, and cached history from
  memory.

## Cold wallet mode

- Three roles: hot (seed + network), cold (seed, no network) and online
  (public pairing, network, no seed).
- Cold mode puts `RpcService` offline and `connect()` fails closed; it never
  prepares or broadcasts. Online mode wipes keys from memory and opens the
  paired watch-only address.
- Pairing exports public addresses and a fingerprint only. Compare the
  fingerprint on both devices before trusting the pairing.
- Requests and signed responses are versioned canonical JSON envelopes with a
  SHA-256 checksum and strict allow-listed fields. The checksum is integrity,
  not authentication; the ECDSA signature over the exact transaction and the
  paired address provide authenticity.
- The online side re-derives the signing digest, parses the raw EIP-1559
  transaction, compares every field, checks `r`/`s`/`yParity`/hash, recovers
  the signer and refuses anything already broadcast. It broadcasts only after
  that succeeds and treats a node-returned hash mismatch as an unknown
  outcome (no automatic resend).
- Only the first 20 default BIP-44 accounts are supported; the signer picks
  the matching index instead of always using index 0.
- Request lifetime defaults to 30 minutes (hard cap 24 hours); the response
  must have been produced before expiry (5-minute clock skew tolerated).

Details and operator steps: [`COLD_WALLET.md`](COLD_WALLET.md).

## TLS pinning

Optional per-node SPKI pins are checked **after** standard CA and hostname
validation. A pin cannot rescue an untrusted chain or a wrong host. A wrong
pin or an empty pin list fails closed. Pinned HTTP CONNECT is refused before
any socket is opened. SPKI extraction follows RFC 5280 (index 6 with the
explicit version field, index 5 without) and is cross-checked against OpenSSL
in `test/tls_pinning_test.dart`.

## Process memory hardening (Linux)

The wallet calls `prctl(PR_SET_DUMPABLE, 0)`, sets `RLIMIT_CORE` to 0 and
attempts `mlockall(MCL_CURRENT | MCL_FUTURE)` through FFI. The first two are
asserted by reading kernel state; `mlockall` is best-effort and may fail under
a low memlock limit. This is not encrypted memory and does not defend against
a compromised OS.

## Release signing key

The old `scripts/release.keystore` and its hardcoded password were committed
to this public repository. The file is removed from the current tree, but it
remains in history. **Treat that signing key as compromised and rotate it.**
`scripts/build-apk.sh` now requires `BNB_KEYSTORE`, `BNB_KEY_ALIAS`,
`BNB_STORE_PASS` and `BNB_KEY_PASS` from the environment, never creates a
keystore, and refuses a tracked keystore. `scripts/secret-scan.sh` runs in CI.

## Erase all data

Located in Settings. Requires typing `ERASE`. It:
1. Overwrites the vault (and any leftover `.tmp`) with random bytes, then
   unlinks both — best-effort due to flash wear-leveling (documented).
2. Cryptographically destroys the data by deleting the device-bound secret
   from secure storage: without that key the remaining ciphertext is inert.
3. Clears: secure-storage items (`bscscan_api_key`, `app_lock_pin_hash`,
   `device_secret_v2`, `app_lock_backoff`) and all preference keys.
4. Resets in-memory state (keys, profiles, nodes, tokens) and returns the
   app to first-run condition.

Funds are recoverable ONLY with the 24-word backup phrase.

## Privacy mode (Tor over SOCKS5)

- Off by default. When on, every RPC call and BscScan request is routed
  through a local SOCKS5 connector — by default `127.0.0.1:9050`.
- Host and port are configurable (Orbot or a system `tor` daemon both work;
  bridges are configured inside Orbot/tor itself, the wallet just speaks
  SOCKS5 to localhost).
- FQDN CONNECT: hostnames are resolved inside the tunnel; DNS never leaks.
- Fail closed: if the SOCKS port is unreachable, requests fail. There is no
  silent direct-connection fallback.
- HTTPS-only through the proxy; plain HTTP requests are refused outright.
- Transport stack: the audited `socks5_proxy` package assigning a
  connection factory into dart:io's `HttpClient`, surfaced through the
  standard `http` client adapter — TLS, chunked encoding, and redirects
  behave exactly as in direct mode.

## What changed between v1.0.2 and v1.0.3 (security-relevant)

| Area | v1.0.2 | v1.0.3 | v1.0.4 |
|---|---|---|---|
| Vault format | One wrapper (Argon2id password KEK) | Two wrappers: password KEK + device-bound KEK (v2 format; v1 blobs remain readable) | unchanged format (no migration churn) |
| Vault writes | Direct overwrite | Atomic tmp+rename, fsync, 0600 perms | unchanged |
| PIN hash | Salted SHA-256 | Argon2id 64 MiB/t=3/p=4 + exponential backoff | unchanged |
| Erase all data | not available | shred + crypto-erase + full wipes | unchanged |
| Auto-lock | background-only | idle timer (configurable) + background | unchanged |
| Seed entry | system keyboard | BIP-39 word picker | unchanged |
| Address confirmation | short form | full grouped EIP-55 + poisoning + contract warnings | unchanged |
| Tor / SOCKS5 | not available | optional fail-closed mode | unchanged |
| Android INTERNET permission | MISSING in release | added | unchanged |
| Connection visibility | status only ("connected"/"tested") | — | narrated story log: every RPC action explained in plain words with latency/chain-id/block; Test RPC prints the full situation instead of a bare word |
| Node management | add + label-rename only | — | terminal-grade: add/edit/remove/activate/test per network side, duplicate rejection, official-list reset |
| Network switching | could leave stale UI | — | state flips immediately; reconnection runs in background and narrates failures |
| Send gate | "create or import first" even when a vault exists | — | vault-aware: one tap opens the existing encrypted vault |
| UI freeze (Ubuntu) | Argon2id ran on the window thread: vault save/unlock and PIN ops froze the app for seconds (desktop showed "Force Quit / Wait") | — | fixed in v1.0.5: all memory-hard crypto runs on worker isolates (`compute()`), byte-identical output (see `test/workers_test.dart`); RPC steps timeboxed at 10 s so dead hosts cannot stall the switch |
| UI freeze round 2 (weak Ubuntu 24.04) | the Linux keyring (libsecret) runs inside the window thread, and every vault operation re-read the device key from it; story bursts re-fetched history per line — window starved under wallet creation and network switching on a 2-core machine | — | fixed in v1.0.5 refresh: device key memoized once per session; 3 s keyring timeout with an honest owner-only "locked drawer" fallback (story card says when it is used; an existing vault is never re-keyed silently — the wallet fails closed instead); history fetch debounced 400 ms; story notifies batched. Proof: `test/drawer_secret_test.dart` + burst-batching test in `test/story_test.dart` |
| UI freeze round 3 (Store-it moment) | even the first keyring call (fresh wallet creation) froze the window: the plugin's libsecret handler runs synchronously on the GTK thread, where no Dart-side timeout can help | — | fixed in v1.0.5 refresh: on desktops the drawer is the PRIMARY home of the device key — wallet creation touches nothing native; the keyring is contacted exactly once in a vault's life, to migrate an old vault's key out of it (fail-closed if truly stuck, never re-keying). Proof: fail-closed/no-rekey and fresh-mint tests in `test/drawer_secret_test.dart`; timing visible in the story card |
| UI freeze round 4 (root cause — journal-proven) | the Home screen's refresh wrote story lines into the connection story bus, whose notify re-entered the same Home refresh — an unbounded synchronous notify cycle reached an 83,000-frame stack in production (system journal, 2026-10-18 20:31), starving the window thread on a 2-core machine with every single notify burst | — | fixed in v1.0.5 refresh: Home refresh no longer narrates mid-flight (story stays fed by connect/vault/network events that do not re-enter it); 400 ms reentry debounce; explicit reentrancy guard; story bus carries a depth cap AND a 30-lines-per-second budget that prints "story cycle detected and broken" instead of chaining. Proof: cascade cut test + budget tests in `test/story_test.dart`; variant present in the journal for the honest record |
| Black pages on Wayland (round 6) | the Send tab opened as a solid black window; after import the app said "unlocked" but nothing visibly appeared — while the identical binary painted every page correctly under X11 on the same machine | — | root-caused with click-through screenshots (GNOME Wayland + GT 710/nouveau): it is the Flutter engine's Wayland GL path — and that engine cannot be switched off in release builds. The launcher now starts through XWayland when the session provides it and the user has not set `GDK_BACKEND` themselves; GPU acceleration is kept. No crypto, storage or network change. Evidence: archived screenshots of the same clicks on both backends (2026-10-18) |
| Send flow parity + pre-signature verify (round 6) | gas limit `(estimate·120)/100` could round below the simulation; the transaction was signed without re-checking it against what the user reviewed; a lost broadcast reply left the user with no guidance | — | exact terminal v1 arithmetic `(estimate·120+99)/100`, rounding UP so the limit can never close below the simulation; everything reviewed is pinned and re-verified from the transaction object right before signing (chain id, gas limit, recipient, amount, ERC-20 calldata decoded byte-level, EIP-1559 pair or legacy gas price) — any drift refuses the signature; a lost broadcast reply says the true thing: result unknown, do NOT resend, check the explorer and the pending nonce. Proof: `test/send_intent_test.dart`, `test/fee_parity_test.dart` |
| Runtime fingerprint (round 6) | every request carried `Dart/x.y (dart:io)` — a software fingerprint readable by DPI and RPC operators | — | header removed entirely on both transports (`userAgent = null`; Tor shares the scrubbed client) — proven against a loopback server in `test/ua_scrub_test.dart` |
| Import visibility (round 6) | after import or create, only a message appeared; nothing visibly confirmed the wallet | — | the visible tab is app state: create/import land on the Wallet tab, whose unlocked card now shows a live balances summary (terminal `dashboard()` parity) beside the address. The "nothing appears" half was the Wayland paint bug above |
| Quick-action "Send" on Home (round 7) | the button pushed an empty page — a black screen — even though the Send tab itself worked | — | the button now switches to the Send tab; the stray blank route is gone. The "black page from Home" report is fully explained by this stub (not the renderer) |
| Unlock landing (round 7) | unlocking produced a message but moved nowhere; Home had no unlock entry at all | — | Home's welcome card offers "Open my vault", and unlocks land where the wallet is visibly on screen: Wallet tab when started from Home, the ready Send form when started from the Send gate |
| Erase honesty + completeness (round 7) | erase wrapped every removal in a silent catch and always claimed success — one failed deletion could leave the vault on disk while the app said "erased" | — | erase clears every preference, removes the preferences file itself, resets the story, VERIFIES every artifact after wiping and reports exactly what survived. Proof: `test/erase_flow_test.dart` and an end-to-end run on the installed build with an isolated app-data directory |
| Unlock → send, second pass (round 7) | unlocking an existing vault replayed the new-wallet save offers ("Save public profile?" / "Save encrypted vault?") exactly where the send form should appear, and the Send tab — the only page without an app-state listener — never repainted from its locked card after a successful unlock; the asset dropdown also matched its initial value by object identity against a separately built menu item (debug builds refused to build the unlocked form, release builds misrendered it) | — | unlocking never offers to save anything — save offers exist only in create/import flows; the Send page flips to the transfer form the moment the key is in memory; the native asset value is one canonical instance shared by the field and its menu. This is exactly the reported "it asks to save the vault again instead of sending". Proof: `test/navigation_flow_test.dart` drives the real app over real vault files — Send gate → unlock → the transfer form is on screen and no save dialog ever appears; Home → unlock lands on the Wallet tab. Isolated click-through screenshots of the installed build accompany this round |
| Send: rehearsal + fees (round 8) | fees came from a single node's number, a token whose contract disagrees with the wallet could be mispriced, and the exact transfer was never rehearsed before signing | — | the send rehearses the EXACT transfer first with a raw `eth_call` — nothing signed, nothing moves; a revert blocks with the contract's own decoded words. Gas comes from `eth_estimateGas` with the 20%-rounded-up buffer. Fee tiers are merged across up to three independent https nodes: median, the too-good outlier dropped, an empirical live floor from recent history, and ETAs computed from measured block seconds — every tier labeled with source and confidence (pinned by `test/fee_engine_test.dart`: even-count median floor, the 100× liar dropped). Token decimals/symbol are re-asked from the contract before the send; a drift refuses it. The BNB gate = amount + maximum fee cap, checked before anything can be signed. The nonce is fetched BEFORE the review so the reviewed number is the signed number. Quotes above 5000 gwei carry an abnormality warning. The "what the node sees" panel is generated from the RPC calls this send actually made, not a fixed claim |
| Send: receipts + pending (round 8) | the truth of a sent transfer came from whichever single node last answered, the paid fee could silently turn into an invented number, receipts lived nowhere, and pending transactions were invisible | — | every send keeps a local receipt: re-read from an INDEPENDENT node (block and status must match before "2 nodes ✓" shows); fee = chain-reported effectiveGasPrice × gas used — and when the node omits the effective price the receipt says exactly that instead of inventing a number; fee-on-transfer is detected from the token's Transfer events ("received X of Y"). Receipts are stored OUTSIDE the vault payload, encrypted with wallet key + device drawer secret (XChaCha20-Poly1305, envelope `BNBRCPT1`; a tampered byte or wrong key yields nothing, `test/receipt_store_test.dart`). Pending sends show as a waiting card that never resends anything on its own — Speed up / Cancel are explicit taps that re-sign the SAME nonce with ≥12.5% higher fees after naming the old and new rates. Every send paints a seven-stop journey and stamps each step into the story |
| Node manager completion (round 9) | the phone book could add/edit/use/delete doors, but every door was always enabled, book order carried no priority meaning, "strict, one door only" did not exist, a test answered only reach/chain/latency/box, imports and exports did not exist, and the privacy warning could not be remembered per door | — | each row now carries an on/off switch (a switched-off door is never asked anything; switching off the ACTIVE door narrates the fallback to the official door), ▲▼ actions make book order = priority order, and "Use ONLY my node" strict mode hard-gates every fee/receipt pool: exactly one door, no built-in fallback, nothing else — pinned by pure functions (`RpcService.feeCandidatePool` / `independentNodeList`, `test/node_manager_test.dart`). The "Full test" checklist shows nine visible rows: answers-at-all, right chain (a mismatch BLOCKS), chain-head freshness measured against the active door, gas price, EIP-1559 fee-history support, pending nonce, eth_call, estimateGas, and sendRawTransaction availability via a deliberately invalid payload — a test can never broadcast anything. Node lists import/export as JSON (import fails closed on any unsafe row), URLs must be https unless localhost/LAN or .onion-over-Tor (`nodeUrlAllowed`), and the "what a node sees" warning is stored per URL so it shows once per door. All pools are fed from the book itself — the wallet has exactly one table of doors (`BnbNetworks`) and nothing else hardcodes an endpoint |
| Token sources + clipboard (round 9) | the "Add token" field did not say where to find trustworthy contract addresses, there was no shipped source list, no link checker, and copied text sat in the clipboard forever — while seed-shaped text could, in principle, reach the clipboard through any future copy path | — | Settings → Tokens now carries the §10e section: a shipped `assets/token_sources.json` (issuer-official Tether/Circle pages, BscScan rows, aggregators, Trust Wallet assets, PancakeSwap JSON), the ①②③ checklist, the fake-name warning, a one-time "these links are starting points" notice, Open (xdg-open only, after your tap — never fetched by the app) and Copy-link buttons, and user's own links (add/reorder/remove, kept in preferences apart from the shipped defaults). `scripts/check_token_sources.py` verifies every link over HTTPS from CI (BscScan rows are declared `bot_protected` and honestly SKIPped — a 403 from bot protection is refused, not a dead link; `scripts/sbom.py` emits the deterministic `docs/SBOM.json`). `copyText` now refuses secret-shaped text through `ClipboardGuard` (12/15/18/21/24-word phrases, bare 64-hex keys) and self-clears after 30 s — but only if the clipboard still holds what was copied, so your own fresh copy is never clobbered (`test/clipboard_guard_test.dart`, `test/token_sources_test.dart`) |

Everything stated as "proof" lives in docs/STANDARDS.md, including the
commands to reproduce each claim and which remaining items can only be
proven by use (or by paying a third-party audit). Questions:
**jackh109867@gmail.com**.

## Known limitations

See docs/THREAT_MODEL.md and SECURITY_AUDIT.md — in particular: no
third-party audit yet, no OS-enforced air gap for cold mode (runtime offline
only), no camera QR on Linux, no two-device field test, no screenshot
blocking on Linux, the old release key must be rotated, on-chain data is
inherently public, and a compromised OS defeats everything.

## Bug disclosure

jackh0006 <jackh109867@gmail.com>
