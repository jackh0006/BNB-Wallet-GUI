# DECISION-002: Cold Wallet Protocol Design

**Date**: 2026-11-03
**Status**: ACCEPTED
**Authors**: jackh0006

## Context

Need a secure, verifiable protocol for offline signing where:
- Cold device holds seed, has no network
- Online device has network, holds no keys
- User transports requests/responses via QR/file/paste
- No seed/private key ever crosses the channel

## Decision

**Three versioned, checksummed, canonical JSON envelopes** with strict field allow-lists:

1. **Pairing** (`kind: "pairing"`) — Public addresses + fingerprint only
2. **Request** (`kind: "request"`) — Unsigned EIP-1559 transaction + metadata
3. **Signature** (`kind: "signature"`) — Signed raw tx + verification data

All envelopes:
```json
{
  "magic": "BNBCOLD",
  "version": 1,
  "kind": "pairing|request|signature",
  "payload": { ... },  // canonical JSON (sorted keys)
  "checksum": "sha256(canonical_json(payload))"
}
```

## Key Security Properties

| Property | Mechanism |
|----------|-----------|
| **Integrity** | SHA-256 checksum over canonical payload |
| **Replay protection** | Single-use request ID; pending required; broadcast burn list |
| **Field binding** | Online verifier re-derives digest, parses raw tx, compares ALL fields |
| **Signer binding** | Response must recover to paired `from` address |
| **Expiry** | Request TTL (30 min default, 24h max); 5 min clock skew tolerance |
| **No secrets in transit** | Pairing = public only; request = unsigned; signature = public key crypto |

## Why Not Alternatives

| Alternative | Rejected Because |
|-------------|------------------|
| PSBT (Partially Signed Bitcoin Transactions) | Bitcoin-centric; EIP-1559 fields don't map cleanly |
| Raw transaction + separate metadata | No integrity/checksum; easy to mismatch |
| Encrypted envelope | Adds complexity; payload is public anyway (unsigned tx) |
| Binary encoding (RLP/CBOR) | JSON is human-readable, debuggable, cross-platform |

## Verification

- `test/cold_wallet_protocol_test.dart` (15 tests): envelope integrity, expiry, substitutions
- `test/cold_wallet_service_test.dart` (15 tests): persistence, replay, verification, broadcast
- `verification/verify.cjs` (ethers.js): independent cross-check of signed bytes

## Limitations

- Camera QR scanning not implemented on Linux (file/paste only)
- Access lists not supported (cold codec rejects them)
- First 20 default BIP-44 accounts only (custom paths unsupported in request)
- No OS-enforced air gap (runtime offline only)

## Related

- `lib/cold_wallet_protocol.dart`
- `lib/cold_wallet_service.dart`
- `lib/screens/cold_wallet_dialogs.dart`
- `docs/COLD_WALLET.md`
- `docs/security/SECURITY_CLAIMS.md` (Cold Wallet Claims)