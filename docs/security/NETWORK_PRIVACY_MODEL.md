# NETWORK_PRIVACY_MODEL.md — Network Privacy Architecture and Guarantees

**Date**: 2026-11-03
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`

---

## Core Principle

**All application network traffic passes through a single, mandatory choke point: `NetworkPrivacyManager` (implemented in `lib/net/privacy_client.dart` and `lib/rpc_service.dart`). No independent network clients may bypass it.**

---

## Connection Modes

| Mode | Description | Fail Behavior | Use Case |
|------|-------------|---------------|----------|
| **Direct** | Plain HTTPS to RPC endpoint | Connection error shown | Trusted local network, no privacy requirement |
| **HTTP Proxy** | HTTP CONNECT tunnel through proxy | Fail closed | Corporate/transparent proxy |
| **HTTPS Proxy** | TLS-wrapped CONNECT through proxy | Fail closed | Proxy requiring TLS |
| **SOCKS5** | SOCKS5 (with optional auth) | Fail closed | General proxy, remote DNS (SOCKS5h) |
| **Tor** | System Tor daemon (SOCKS5 127.0.0.1:9050) | Fail closed | Maximum IP privacy |
| **Tor Bridge** | Tor with pluggable transports (obfs4, WebTunnel) | Fail closed | Censored environments |
| **Strict Privacy** | Enforces selected route for ALL traffic | Fail closed | Default recommended mode |
| **Offline** | Blocks ALL outbound at network layer | N/A | Cold signer, air-gapped operation |

---

## Traffic Classification

| Traffic Type | Route Policy | Notes |
|--------------|--------------|-------|
| **RPC (JSON-RPC, WebSocket)** | Always through active mode | Chain ID validated on connect |
| **Blockchain Explorer (BscScan)** | Always through active mode | API key in secure storage |
| **Token Metadata (contract calls)** | Always through active mode | Decimals/symbol verification |
| **Price APIs (optional)** | Through active mode if enabled | Disabled by default |
| **Update Checks** | Through active mode | Only if enabled |
| **QR Code Generation** | **NEVER** network | Pure local (qr_flutter) |
| **Seed/Key Operations** | **NEVER** network | Local only |

---

## Privacy Guarantees by Mode

### Direct Mode
- **ISP sees**: Destination IP, SNI (hostname), TLS handshake, packet timing/size
- **RPC provider sees**: Your IP, all RPC requests, queried addresses, tx submissions
- **Protected by**: TLS (content encryption), no identifying headers

### HTTP/HTTPS Proxy
- **ISP sees**: Proxy IP, CONNECT requests (destination hostname in CONNECT)
- **Proxy operator sees**: Your IP, destination hostname, all tunneled traffic (if HTTPS proxy, only CONNECT metadata)
- **RPC provider sees**: Proxy exit IP, RPC requests
- **Protected by**: TLS end-to-end (HTTPS proxy), or TLS through CONNECT

### SOCKS5 Proxy
- **ISP sees**: Proxy IP, SOCKS handshake
- **Proxy operator sees**: Your IP, destination hostname (SOCKS5h) or IP, all traffic
- **RPC provider sees**: Proxy exit IP
- **Protected by**: TLS end-to-end, remote DNS resolution (no local DNS)

### Tor (System Daemon)
- **ISP sees**: Tor entry guard IP, encrypted Tor traffic
- **Tor entry guard sees**: Your IP, encrypted traffic to middle relay
- **Tor middle relay sees**: Entry guard IP, exit relay IP
- **Tor exit relay sees**: Destination IP, plaintext HTTP/HTTPS (if not HTTPS) or TLS handshake
- **RPC provider sees**: Tor exit node IP, RPC requests
- **Protected by**: 3-hop onion routing, TLS end-to-end, no local DNS

### Tor Bridge (obfs4/WebTunnel)
- **Additional**: Obscures Tor traffic from DPI/censors
- **Bridge operator sees**: Your IP, obfuscated Tor traffic
- **Same guarantees as Tor** after bridge

---

## What Tor/Proxy DOES Hide

| Hidden From | What Is Hidden |
|-------------|----------------|
| **ISP / Local Network** | Destination hostname/IP, RPC content, queried addresses |
| **RPC Provider** | Your real IP (sees proxy/Tor exit instead) |
| **Passive DPI** | RPC method names, parameters, response content (inside TLS) |

---

## What Tor/Proxy Does NOT Hide

| Party | Still Visible |
|-------|---------------|
| **Blockchain (public)** | All transactions, addresses, balances, token holdings — forever |
| **RPC Provider** | Which addresses you query, what transactions you submit, timing |
| **Tor Exit / Proxy Operator** | Destination IP/hostname, RPC request content (if not TLS — but we enforce HTTPS) |
| **ISP (with Tor)** | That you're using Tor, traffic volume, timing patterns |
| **Traffic Analysis** | Correlation of entry/exit timing/volume (mitigated by HTTPS) |
| **Compromised Device** | Everything the wallet does while unlocked |

---

## Fail-Closed Behavior

1. **Proxy/Tor unreachable** → Connection error shown; **no silent direct fallback**
2. **TLS validation fails** → Connection error; **no certificate bypass**
3. **Chain ID mismatch** → Node blocked; **no silent wrong-chain usage**
4. **DNS resolution fails** → Error; **no local DNS fallback for SOCKS5/Tor**
5. **Route changes mid-session** → Existing connections closed; new ones use new route

---

## DNS Leak Prevention

| Mechanism | Implementation |
|-----------|----------------|
| **SOCKS5h** | Hostname passed to proxy; proxy resolves remotely |
| **Tor** | Hostname passed through SOCKS5 to Tor; Tor resolves at exit |
| **HTTP CONNECT** | CONNECT sent with hostname; proxy resolves |
| **Direct** | System DNS (no leak — direct is explicit) |
| **No pre-resolution** | Code never calls `InternetAddress.lookup()` before proxy/Tor |

---

## Certificate Validation

**Never disabled.** Even with SPKI pinning:

1. Standard `SecureSocket.connect` with caller's `SecurityContext` (trusted roots)
2. Hostname verification (RFC 6125)
3. **Then** SPKI pin check against peer certificate
4. Wrong pin → connection closed
5. Empty pin list → fail closed (no pin = no pin enforcement, but standard validation still runs)

---

## SPKI Pinning Details

- **Format**: Base64(SHA-256(SubjectPublicKeyInfo DER))
- **Extraction**: RFC 5280 TBSCertificate — `subjectPublicKeyInfo` at index 6 (with explicit version) or 5 (without)
- **Verification**: `test/tls_pinning_test.dart` compares Dart result with OpenSSL independent extraction
- **Per-node**: Configured in node book (`RpcNode.pinnedSpkiHashes`)
- **HTTP CONNECT with pins**: **Refused before socket opens** (not silently downgraded)

---

## RPC Chain ID Validation

- **On every connect**: `eth_chainId` called and compared to expected
- **Mismatch**: Node blocked, user warned, **no silent wrong-chain operation**
- **Per-network**: Mainnet (56) and Testnet (97) tracked separately

---

## Request/Response Handling

| Aspect | Implementation |
|--------|----------------|
| **Timeouts** | 10s per network step (connect, RPC call) |
| **Retries** | Fallback to next node in pool (configurable) |
| **Rate Limiting** | Respects `Retry-After` / 429; exponential backoff |
| **User-Agent** | **Scrubbed** — no identifying headers sent |
| **Headers** | Only `Content-Type: application/json`, `Accept: application/json` |
| **Request Bodies** | Never contain secrets (signing is local) |
| **Response Validation** | JSON-RPC 2.0 format, error object checked |

---

## Network Status Dashboard (UI)

Displays for each connection:
- **Mode**: Direct / HTTP Proxy / HTTPS Proxy / SOCKS5 / Tor / Bridge / Offline
- **Route Status**: VERIFIED / NOT VERIFIED / WARNING / FAILED
- **Tor Status**: Connected / Not Running / Bridge Configured
- **Proxy Status**: Connected / Auth Failed / Unreachable
- **DNS Route**: Remote (SOCKS5h/Tor) / Local (Direct) / FAILED
- **TLS Status**: Valid / Invalid / Pinned / FAILED
- **RPC Endpoint**: URL + chain ID + last test timestamp
- **Strict Routing**: ENABLED / DISABLED
- **Last Privacy Check**: Timestamp + result

**Never shows green/VERIFIED unless the relevant test actually passed.**

---

## VPS-Through-Tor Acceptance Scenario

**User configures**: Custom VPS RPC endpoint (e.g., `https://my-vps.example.com`)

**Wallet behavior**:
1. Connects to local Tor SOCKS5 (127.0.0.1:9050)
2. Passes `my-vps.example.com` hostname through SOCKS5 (no local DNS)
3. Tor routes through 3 hops to exit
4. HTTPS established with VPS (certificate validated)
5. RPC requests sent over Tor circuit
6. VPS sees: Tor exit IP, RPC requests
7. If Tor stops → request fails, **no direct fallback**

**VPS still sees** (cannot be hidden):
- RPC method calls, parameters
- Queried addresses, submitted transactions
- Request timing, volume
- Any identity voluntarily supplied (e.g., API key)

---

## Evidence Locations

| Test / Evidence | Location |
|-----------------|----------|
| TLS pinning integration (OpenSSL cross-check) | `test/tls_pinning_test.dart` |
| User-Agent scrubbing | `test/ua_scrub_test.dart` |
| Proxy/Tor dialog behavior | `test/privacy_dialogs_test.dart` |
| RPC chain ID validation | `test/nodes_test.dart`, `test/node_manager_test.dart` |
| Network layer code | `lib/net/privacy_client.dart`, `lib/rpc_service.dart` |
| Tor manager | `lib/tor_manager.dart` |

---

*This model describes the intended architecture and tested guarantees. Real-world privacy depends on correct configuration, trusted Tor/proxy operators, and an uncompromised device.*