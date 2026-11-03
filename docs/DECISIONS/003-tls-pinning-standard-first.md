# DECISION-003: TLS Pinning — Standard Validation First

**Date**: 2026-11-03
**Status**: ACCEPTED
**Authors**: jackh0006

## Context

Certificate pinning is a powerful anti-MITM control, but if implemented incorrectly it can weaken security by bypassing standard CA/hostname validation.

## Decision

**SPKI pinning runs ONLY after standard TLS validation succeeds.**

### Implementation (`lib/net/privacy_client.dart`)

```dart
// 1. Standard connect with caller's SecurityContext (trusted roots)
final socket = await SecureSocket.connect(host, port, context: context);

// 2. Standard hostname verification (RFC 6125) — already done by SecureSocket

// 3. ONLY THEN check SPKI pin
if (pins.isNotEmpty) {
  final spkiHash = spkiSha256Base64FromDer(socket.peerCertificate!.der);
  if (!pins.contains(spkiHash)) {
    socket.destroy();
    throw HandshakeException('SPKI pin mismatch');
  }
}
```

### Fixed: v3 Certificate SPKI Index Bug

**Bug**: Original code used index 7 for v3 certs, hashing the extensions block instead of `subjectPublicKeyInfo`.

**Root Cause**: RFC 5280 `TBSCertificate` structure:
```
SEQUENCE {
  version       [0] EXPLICIT Version DEFAULT v1,  // index 0 if present
  serialNumber  CertificateSerialNumber,           // index 0 or 1
  signature     AlgorithmIdentifier,               // index 1 or 2
  issuer        Name,                              // index 2 or 3
  validity      Validity,                          // index 3 or 4
  subject       Name,                              // index 4 or 5
  subjectPublicKeyInfo  SubjectPublicKeyInfo,      // index 5 (no version) or 6 (with version)
  issuerUniqueID  [1] IMPLICIT UniqueIdentifier OPTIONAL,
  subjectUniqueID [2] IMPLICIT UniqueIdentifier OPTIONAL,
  extensions      [3] EXPLICIT Extensions OPTIONAL  // index 7 (with version)
}
```

**Fix**: `spkiIndex = firstElement.tag == 0xA0 ? 6 : 5`

**Verification**: `test/tls_pinning_test.dart` compares Dart result with OpenSSL:
```bash
openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | openssl base64 -A
```

### HTTP CONNECT with Pins

**Refused before socket opens** — not silently downgraded.

```dart
if (node.transport == NodeTransport.httpConnect && node.pinnedSpkiHashes.isNotEmpty) {
  throw StateError('Pinned HTTP CONNECT not supported; use Direct/Tor/SOCKS5');
}
```

## Why This Matters

| Wrong Approach | Risk |
|----------------|------|
| Pin bypasses CA validation | Attacker with valid cert for wrong host accepted |
| Pin bypasses hostname validation | Attacker with valid cert for different host accepted |
| Empty SecurityContext + badCertificateCallback | No validation at all; pin is only check |
| Wrong SPKI index | Pin computed over extensions; real key not pinned |

## Verification

- `test/tls_pinning_test.dart` (6 tests): generates ephemeral CA + cert, proves Dart == OpenSSL, proves pin cannot bypass CA/hostname

## Related

- `lib/net/privacy_client.dart`
- `test/tls_pinning_test.dart`
- `docs/security/NETWORK_PRIVACY_MODEL.md`
- `docs/security/SECURITY_CLAIMS.md` (Network Privacy Claims)