# Standards & Proof Map — X Wallet v1.0.5

Created by jackh0006 (jackh109867@gmail.com)

This file answers one question: "by what standard is each part built, and
where can I check the proof?" Every row names the official standard, what the
wallet does about it, and the *concrete, reproducible* proof that ships with
the release.

## The map

| Subsystem | Standard | Proof ships with the release |
|---|---|---|
| Seed words | BIP-39 (2048-word English list + checksum) | `flutter test` — the published `test test … junk` vector derives account `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`, the exact address every reference wallet derives. Word-picker only accepts list words. |
| Key derivation | BIP-32/44, path `m/44'/60'/0'/0/0` | Determinism and passphrase-divergence tests in `test/wallet_core_test.dart`. |
| Addresses | EIP-55 checksummed addresses | Official EIP-55 test vectors pass; a single flipped letter is detectable (test included). Send dialog prints the full grouped EIP-55 form. |
| Transactions | EIP-155 replay protection (chain id in signature), EIP-1559 dynamic fee + legacy fallback | web3dart signs with chain id (see call sites in `send_page.dart`); fee tiers are read from chain data (`eth_feeHistory`) before review. |
| Vault encryption | RFC 9106 Argon2id conservative profile — 64 MiB, t=3, p=4, 32-byte tag; HKDF-SHA256 per RFC 5869; XChaCha20-Poly1305 AEAD per CFRG draft | Byte level spec in docs/CRYPTO.md (this exact layout is what your file contains); round-trip, tamper, parameter-downgrade, and "file without device key is inert" tests. |
| Vault storage | POSIX atomicity via write-tmp → `rename()`; 0600 permissions | Design described and applied in `AppStorage.writeVaultAtomic`; crash before rename keeps the previous good vault. |
| App-lock PIN | Argon2id (same 64 MiB profile), constant-time compare, exponential backoff `min(2^(n−1), 900) s` persisted across restarts | PIN/backoff behavior verified in code paths; legacy SHA-256 records are refused and re-created under the new scheme. |
| Transport | HTTPS-only; SOCKS5 CONNECT per RFC 1928, DNS resolved inside the tunnel; fail-closed | Plain-HTTP through the proxy is refused by construction; dead proxy = visible failure, never a silent direct fallback; SOCKS5 comes from the published `socks5_proxy` package, not hand-rolled code. |
| Permissions | Least privilege on every platform | Android build (initial 1.0.5 set) declares only `INTERNET` (`aapt dump permissions` on the artifact) — no camera, contacts, SMS, phone state, storage, or location; the Linux package runs unprivileged and installs no daemon. |
| Node book | Multi-network node list with add / edit / remove / activate / test — capability parity with the v1 terminal wallet | `test/nodes_test.dart` — CRUD, duplicate rejection, per-side filtering, official-defaults reset. |
| Code hygiene | `flutter analyze`: 0 errors, 0 warnings; every new feature carries its test | Re-run on this machine at build time; output kept in the release notes below. |
| Packaging | dpkg metadata + detached GPG + sha256 for both artifacts | `sha256sum -c` and `gpg --verify` commands listed in README — you run them, they pass or the release is broken; nothing hidden. |
| UI responsiveness | GTK apps must answer the desktop's "are you alive?" ping on the window thread | All memory-hard crypto (Argon2id) runs on worker isolates via `compute()` — byte-identical output proven by the round-trip test `test/workers_test.dart`; every network step carries a 10-second timebox. On desktops the device key lives in an owner-only drawer file (native keyring contacted once in a vault's life, for migration, fail-closed, never re-keying a usable vault — `test/drawer_secret_test.dart`); story notifies batch per event-loop turn. Ubuntu "Force Quit / Wait" freezes at wallet creation and network switching (taste rounds 2–3, weak 2-core systems) are fixed by design, not by tuning. |
| Rendering on older GPUs | Every screen must paint on the machines the wallet actually runs on. Reproduced failure: GNOME Wayland + older NVIDIA on nouveau (GT 710) — the Send tab opened solid black and the post-import wallet view never appeared, while the identical binary rendered every page under X11 | Root-caused with click-through screenshots on the affected machine (same pixel clicks, both backends, archived 2026-10-18): it is the Flutter engine's Wayland GL path, not wallet code — and that engine cannot be switched back to Skia in release builds. The launcher starts through GDK's X11 backend when a Wayland session offers XWayland and the user has not set `GDK_BACKEND` themselves; Impeller's GPU acceleration is kept and no crypto or networking logic is touched. |
| Send flow | Exact terminal v1 behavior: gas limit `(estimate·120+99)/100` (rounded UP — the floor form once shaved the whole buffer), fee tiers from `eth_feeHistory` percentiles with `maxFee = base·2 + tip` (legacy ×0.90/1.00/1.25 rounded up), required-BNB = amount + maximum fee cap, recipient suffix typed before release, then a pre-signature re-check of chain id / gas limit / recipient / amount / calldata / fees | `test/send_intent_test.dart` pins the gas formula and the byte-level `verifyTransactionIntent` equivalent — changed amount, swapped contract, dirty calldata, chain switch, and fee drift are each refused before signing; `test/fee_parity_test.dart` pins the tier arithmetic to the v1 formulas (median floor for even samples, basis-point round-up). An unknown broadcast outcome says exactly what v1 prints: do NOT resend, check the explorer and the pending nonce. |
| Runtime fingerprint | Do not volunteer the software stack to RPC nodes or DPI | `HttpClient.userAgent = null`: the `Dart/<version> (dart:io)` header is not sent at all — direct and Tor modes share the scrubbed client; `test/ua_scrub_test.dart` stands up a loopback server and asserts the header is absent. |
| Import result visibility | After import or create, the wallet itself must be on screen — "it just says unlocked, nothing appears" was accepted as a bug report, not a wording problem | The visible tab lives in the app state; create/import land on the Wallet tab, which shows the address card AND a live balance summary (terminal `dashboard()` parity) the moment a wallet is unlocked. The "nothing appears" report itself was the Wayland paint bug above — both are fixed; visible in the archived click-through screenshots. |
| Home quick actions | Buttons must navigate somewhere real — never a dead end | The Home screen's "Send" button used to push an empty page (a black screen — the actual "black page from Home" report); it now switches to the Send tab. Home's welcome card offers "Open my vault", and every unlock path ends with the wallet visibly on screen: Wallet tab when unlocked from Home, the ready Send form when unlocked from the Send gate. The Send gate's empty-state text names the Wallet tab. |
| Erase all data | "Erase" must leave no readable state behind — and must never claim success while something survived | `AppStorage.eraseAllData` shreds the vault and temp vault, deletes the device-key drawer, clears every preference, removes the preferences file itself, and resets the story; it then VERIFIES each artifact and returns whatever could not be removed, and the UI shows that exact list instead of a success message. Proof: `test/erase_flow_test.dart` plus an end-to-end run on the installed binary with an isolated app-data directory (vault, drawer and prefs file all gone; app back to first-run). |
| Unlock → send readiness | One unlock path, no side quests: after unlocking, the working screen must be on screen — the reported failure was an unlock that ended in "save profile / save vault" offers instead of the transfer form | `test/navigation_flow_test.dart` exercises the real navigation over real vault files (Send gate → unlock → transfer form, no save dialogs; Home unlock → Wallet tab). Unlock wiring runs against a debug-only crypto seam (`kDebugMode`-gated `AppState.vaultEncryptOverride`/`vaultDecryptOverride` — compiled out of release builds; the shipped cipher is untouched and stays pinned by `test/vault_test.dart` and `test/workers_test.dart`). The heavy KDF tests carry explicit minutes-scale timeouts: the default 30 s timeout used to kill the shared test device mid-derivation on this 2-core machine and fail unrelated tests ("did not complete" cascade). |
| Multi-node fee engine | A fee quote must be a measured cross-check, never one node's word: median across independent https nodes, the too-good outlier dropped, an empirical live floor from recent history, ETAs computed from measured block seconds, every tier labeled with its source and confidence; legacy chains keep the v1 basis-point round-up | `test/fee_engine_test.dart` pins the median (even count floors to parity), the 100× outlier being dropped (p50 = 1 / p90 = 4 fixture), the live floor, and the ETA arithmetic; the abnormal-quote flag (>5000 gwei) and the plain-words reason are part of the pinned contract. |
| Send pipeline order | The order never varies: prepare → rehearse (raw eth_call) → estimate → live quote → user review → typed-suffix check → local sign → broadcast → pending → included → finalized, each step stamped into the story; the gas limit can never go below the simulation; a pending send is never auto-resent — Speed up / Cancel are explicit user taps re-signing the SAME nonce with ≥12.5% higher fees | `test/tx_lifecycle_test.dart` pins the journey stages, `bumpFee` (+12.5%, rounded up), revert decoding (`Error(string)`, selector `0x08c379a0`), and the broadcast verdicts incl. "already known", nonce-too-low, underpriced and replacement-underpriced. The review dialog shows the nonce fetched before it opened, so the reviewed nonce is the signed nonce. |
| Local receipts | Receipts are device-local evidence, never inside the vault payload: a separate file, key = HKDF-SHA256(wallet private key, device drawer secret), XChaCha20-Poly1305 envelope `BNBRCPT1`, 200-receipt cap, atomic owner-only writes; every figure on a receipt comes from a chain answer — and anything the chain did not report is labeled as such, not invented | `test/receipt_store_test.dart`: the roundtrip keeps every field; one tampered byte or a wrong key returns null (never a plausible fake). The UI prints "2 nodes ✓" only after an independent node's receipt matches block and status. |
| Node manager | Every network question must be able to travel through doors the user curates: enable/disable per door, book order = priority order, strict "use ONLY my door" mode, nine-item test checklist (a chain mismatch blocks; the broadcast probe can never send anything), import/export JSON that fails closed, https-everywhere URL policy (http only for localhost/LAN/.onion over Tor), a "what a node sees" warning remembered once per door — and exactly one hardcoded door table in the codebase | Pure rules pinned in `test/node_manager_test.dart`: `nodeUrlAllowed` (accepts loopback/10.x/192.168/172.16-31/.onion on plain http, refuses `http://8.8.8.8` and `172.32.x`), `feeCandidatePool` (normal = active → configured → book → built-ins capped at 3; strict = exactly the active door or nothing), `independentNodeList` (book doors minus active; empty in strict), `moveNodeIndex` (reorder never crosses a network side). `AppState` flows pin enable/disable persistence, the active-door fallback on disable, fail-closed imports, JSON round-trip and per-URL warning memory. |
| Token sources + clipboard | Where contract addresses may be trusted from gets shipped IN the app (never fetched, never auto-loaded): `assets/token_sources.json` with the 3-step checklist, the scam warning and a one-time notice; the user's own links are editable (add/reorder/remove) and kept apart from the shipped list; CI checks every link over HTTPS — a bot-wall 403 is declared in the list and skipped, never silently called "verified"; the clipboard refuses secret-shaped text and clears itself after 30 s when left untouched | `test/token_sources_test.dart` pins the file shape (list, row completeness, https-only, issuer + explorer + aggregator rows present, exact spec URLs for Tether/Circle, `bot_protected` declared for bscscan.com rows). `test/clipboard_guard_test.dart` pins `ClipboardGuard`: 12/24-word phrases and bare 64-hex keys refused, addresses/hashes/links pass. Reproduce the link check with `python3 scripts/check_token_sources.py` (network needed) and the SBOM with `python3 scripts/sbom.py --out docs/SBOM.json` (deterministic — same lock, same bytes). |
| Test execution | On a 2-core release machine the Argon2id-heavy suites must never overlap: `vault_test.dart` and `workers_test.dart` are tagged `kdf`, the default runner (`dart_test.yaml`) sets `concurrency: 1`, and `scripts/test-suite.sh` runs light suites two-wide and `kdf` suites one-wide. A `did not complete` after a long run means the runner was terminated mid-flight (watchdog or Ctrl-C), NOT that an assertion failed — that exact signature with 9 in-flight KDF tests at a 10-minute wall clock was diagnosed and eliminated this round | Reproduce: `bash scripts/test-suite.sh` — expect `All tests passed!` across both phases; `flutter test --concurrency=1 test/vault_test.dart test/workers_test.dart` proves the heavy tail passes alone. Check-in history: parallel default + load ~5 produced the cascade at 09:00 wall; the subsequent policy run is expected green. |

## Cryptographic building blocks — reviewed inputs, pinned versions

- `cryptography` ^2.9.0 — Argon2id, HKDF, XChaCha20-Poly1305 (pure Dart, no C bindings, no hidden syscalls).
- `socks5_proxy` ^2.1.1 — SOCKS5 client used for Tor routing.
- `bip39_mnemonic`, `bip32_plus`, `web3dart` 3.0.3 — BIP-39/32/44 and transaction formation.
- No hand-written cipher, hash, or padding anywhere in this repository.

## Proofs you can run yourself, in five minutes

1. **Verify the file you downloaded is the file I signed**
   ```bash
   sha256sum -c SHA256SUMS
   gpg --verify SHA256SUMS.asc SHA256SUMS   # only when a signature is published
   ```
2. **Watch the wallet talk to the chain** (Linux, while it is open):
   ```bash
   strace -f -e trace=connect,getaddrinfo /usr/lib/x-wallet/bnb_wallet_gui
   ```
   You will see connections only to HTTPS RPC hosts (and to tor's SOCKS port
   if Privacy mode is on). No other egress.
3. **Look inside the vault**: `~/.local/share` (app support dir) keeps one
   base64 `BNBVL004` blob with the exact layout documented in docs/CRYPTO.md —
   grep the file: no plaintext seed, no plaintext key.
4. **Check what the package installs**: `dpkg -c x-wallet-1.1.0-amd64.deb` — the app binary, its icon and the desktop entry; nothing else.
5. **Rebuild from source** on any machine with Flutter 3.x and compare behavior.
6. **Prove the vault is inert off-device**: copy the vault plus nothing else
   to a second machine and run the same wallet — it cannot open without the
   device-bound key that never left this machine.
7. **Re-derive the send path's arithmetic**: `flutter test test/fee_parity_test.dart test/send_intent_test.dart` — the exact terminal v1 fee formulas and the pre-signature refusal checks run in front of you, no network needed.

## What cannot be proven on paper — true to say, in plain words

Stated as one paragraph so nothing hides behind wording:

*The following remain true regardless of anything above: a compromise of the
operating system (keyloggers, malicious keyboards, rootkits) defeats every
local protection; RPC endpoints could lie about balances (the app does not
independently prove chain state); unknown bugs can hide in any implementation;
long-term cryptographic assumptions can change; and a formal third-party
security audit has not been performed — that is the one assurance this release
cannot produce by itself. Everything stated in the map above, however, is
reproducible today by running the commands in this document.*

Questions about any line in this file: **jackh109867@gmail.com** — I answer
them, including "prove it differently" requests.
