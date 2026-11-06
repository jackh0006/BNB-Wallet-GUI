import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bnb_wallet_gui/cold_wallet.dart';
import 'package:bnb_wallet_gui/cold_wallet_protocol.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';

void main() {
  const phrase = 'test test test test test test test test test test test junk';
  const from = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const to = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';

  ColdTxRequest request({
    String id = 'protocol-test-1',
    int chainId = 56,
    String? recipient,
    String value = '0xde0b6b3a7640000',
    String gas = '0x5208',
    String data = '0x',
    int nonce = 0,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    final now = DateTime.now().toUtc();
    return ColdTxRequest(
      version: 1,
      chainId: chainId,
      from: from,
      to: recipient ?? to,
      value: value,
      gasLimit: gas,
      maxFeePerGas: '0x3b9aca00',
      maxPriorityFeePerGas: '0x3b9aca00',
      nonce: nonce,
      data: data,
      assetInfo: const ColdTxAssetInfo(isNative: true),
      createdAt: (createdAt ?? now).toIso8601String(),
      expiresAt: (expiresAt ?? now.add(const Duration(minutes: 10)))
          .toIso8601String(),
      id: id,
    );
  }

  group('pairing envelope', () {
    test('round-trips public addresses and fingerprint', () {
      final pairing = ColdWalletProtocol.exportPairing(
        walletName: 'test cold',
        chainId: 56,
        addresses: const [from, to],
      );
      final text = ColdWalletProtocol.encodePairing(pairing);
      final decoded = ColdWalletProtocol.decodePairingEnvelope(text);
      expect(decoded.walletName, 'test cold');
      expect(decoded.chainId, 56);
      expect(decoded.addresses, [from, to]);
      expect(decoded.fingerprint, pairing.fingerprint);
      expect(decoded.includeXpub, isFalse);
    });

    test('rejects a duplicated address', () {
      expect(
        () => ColdWalletProtocol.exportPairing(
          walletName: 'dup',
          chainId: 56,
          addresses: const [from, from],
        ),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('rejects a checksum-modified payload', () {
      final text = ColdWalletProtocol.encodePairing(
        ColdWalletProtocol.exportPairing(
          walletName: 'tamper',
          chainId: 56,
          addresses: const [from],
        ),
      );
      final object = jsonDecode(text) as Map<String, dynamic>;
      final payload = object['payload'] as Map<String, dynamic>;
      payload['walletName'] = 'evil';
      object['payload'] = payload;
      expect(
        () => ColdWalletProtocol.decodePairingEnvelope(jsonEncode(object)),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('rejects unknown and missing fields', () {
      final pairing = ColdWalletProtocol.exportPairing(
        walletName: 'fields',
        chainId: 56,
        addresses: const [from],
      );
      final payload = pairing.toJson()..['unexpected'] = 'x';
      final unknown = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindPairing,
        payload: payload,
        maxBytes: ColdWalletProtocol.maxPairingBytes,
      );
      expect(
        () => ColdWalletProtocol.decodePairingEnvelope(unknown),
        throwsA(isA<ColdProtocolException>()),
      );

      final missing = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindPairing,
        payload: pairing.toJson()..remove('chainId'),
        maxBytes: ColdWalletProtocol.maxPairingBytes,
      );
      expect(
        () => ColdWalletProtocol.decodePairingEnvelope(missing),
        throwsA(isA<ColdProtocolException>()),
      );
    });
  });

  group('request envelope', () {
    test('round-trips the exact transaction fields', () {
      final original = request();
      final decoded = ColdWalletProtocol.decodeRequestEnvelope(
        ColdWalletProtocol.encodeRequest(original),
      );
      expect(decoded.id, original.id);
      expect(decoded.chainId, original.chainId);
      expect(decoded.from, original.from);
      expect(decoded.to, original.to);
      expect(decoded.value, original.value);
      expect(decoded.gasLimit, original.gasLimit);
      expect(decoded.maxFeePerGas, original.maxFeePerGas);
      expect(decoded.maxPriorityFeePerGas, original.maxPriorityFeePerGas);
      expect(decoded.nonce, original.nonce);
      expect(decoded.data, original.data);
      expect(decoded.assetInfo.isNative, isTrue);
    });

    test('rejects an expired request even with a valid checksum', () {
      final now = DateTime.now().toUtc();
      final expired = request(
        createdAt: now.subtract(const Duration(minutes: 30)),
        expiresAt: now.subtract(const Duration(minutes: 20)),
      );
      final text = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindRequest,
        payload: expired.toJson(),
        maxBytes: ColdWalletProtocol.maxRequestBytes,
      );
      expect(
        () => ColdWalletProtocol.decodeRequestEnvelope(text),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('rejects an unknown field in the request payload', () {
      final payload = request().toJson()..['gasPrice'] = '0x1';
      final text = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindRequest,
        payload: payload,
        maxBytes: ColdWalletProtocol.maxRequestBytes,
      );
      expect(
        () => ColdWalletProtocol.decodeRequestEnvelope(text),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('rejects an immature request (expiry before creation)', () {
      final now = DateTime.now().toUtc();
      final bad = request(
        createdAt: now,
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      final text = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindRequest,
        payload: bad.toJson(),
        maxBytes: ColdWalletProtocol.maxRequestBytes,
      );
      expect(
        () => ColdWalletProtocol.decodeRequestEnvelope(text),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('rejects a native request that carries calldata', () {
      final bad = request(data: '0x01');
      expect(
        () => ColdWalletProtocol.validateRequest(bad),
        throwsA(isA<ColdProtocolException>()),
      );
    });
  });

  group('signed response envelope', () {
    late ColdTxRequest original;
    late ColdTxSignature signature;

    setUp(() {
      original = request(id: 'protocol-sign-1');
      signature = WalletCore.signTransaction(phrase: phrase, request: original);
    });

    test('round-trips and validates against the exact raw bytes', () {
      final text = ColdWalletProtocol.encodeSignature(signature);
      final decoded = ColdWalletProtocol.decodeSignatureEnvelope(text);
      expect(decoded.requestId, signature.requestId);
      expect(decoded.requestHash, signature.requestHash);
      expect(decoded.rawSignedTx, signature.rawSignedTx);
      expect(decoded.signedTxHash, signature.signedTxHash);
      expect(decoded.yParity, signature.yParity);
    });

    test('rejects a modified raw transaction with a fresh checksum', () {
      final payload = signature.toJson()
        ..['rawSignedTx'] =
            '0x02f8723880843b9aca00843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000180c001a09e14c0496472a3ea4af35ece19224ff815dfd656a568524a84130c722b959afda0393349471326e2196f8d11c49649f17df740476d4f5d6447f8dfa20bd0d66a4b';
      final text = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindSignature,
        payload: payload,
        maxBytes: ColdWalletProtocol.maxSignatureBytes,
      );
      expect(
        () => ColdWalletProtocol.decodeSignatureEnvelope(text),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('rejects yParity that does not match v', () {
      final payload = signature.toJson()
        ..['yParity'] = (signature.yParity! ^ 1);
      // Keep v untouched; the protocol must notice the contradiction.
      final text = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindSignature,
        payload: payload,
        maxBytes: ColdWalletProtocol.maxSignatureBytes,
      );
      expect(
        () => ColdWalletProtocol.decodeSignatureEnvelope(text),
        throwsA(isA<ColdProtocolException>()),
      );
    });

    test('rejects a missing request hash', () {
      final payload = signature.toJson()..remove('requestHash');
      final text = ColdWalletProtocol.encodeEnvelope(
        kind: ColdWalletProtocol.kindSignature,
        payload: payload,
        maxBytes: ColdWalletProtocol.maxSignatureBytes,
      );
      expect(
        () => ColdWalletProtocol.decodeSignatureEnvelope(text),
        throwsA(isA<ColdProtocolException>()),
      );
    });
  });

  group('field substitution', () {
    late ColdTxRequest original;
    late ColdTxSignature signature;

    setUp(() {
      original = request(id: 'substitution-1');
      signature = WalletCore.signTransaction(phrase: phrase, request: original);
    });

    void expectRejected(ColdTxRequest changed) {
      final result = WalletCore.verifyColdSignatureDetailed(
        request: changed,
        signature: signature,
        expectedFrom: from,
      );
      expect(result.ok, isFalse, reason: result.reason);
    }

    test(
      'recipient, value, chain, nonce, gas, fees and calldata are bound',
      () {
        expectRejected(
          request(id: 'substitution-1', recipient: to.replaceFirst('70', '71')),
        );
        expectRejected(request(id: 'substitution-1', value: '0x1'));
        expectRejected(request(id: 'substitution-1', chainId: 97));
        expectRejected(request(id: 'substitution-1', nonce: 1));
        expectRejected(request(id: 'substitution-1', gas: '0x5209'));
        expectRejected(
          request(
            id: 'substitution-1',
            data: '0xa9059cbb00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c80000000000000000000000000000000000000000000000000000000000000001',
          ),
        );
      },
    );

    test('r, s, yParity and hash substitutions are rejected', () {
      ColdVerifyResult check(ColdTxSignature changed) =>
          WalletCore.verifyColdSignatureDetailed(
            request: original,
            signature: changed,
            expectedFrom: from,
          );
      final badR = ColdTxSignature(
        version: signature.version,
        requestId: signature.requestId,
        requestHash: signature.requestHash,
        chainId: signature.chainId,
        from: signature.from,
        r: '0x${'1'.padLeft(64, '0')}',
        s: signature.s,
        v: signature.v,
        yParity: signature.yParity,
        signedTxHash: signature.signedTxHash,
        signedAt: signature.signedAt,
        rawSignedTx: signature.rawSignedTx,
      );
      expect(check(badR).ok, isFalse);
      final badS = ColdTxSignature(
        version: signature.version,
        requestId: signature.requestId,
        requestHash: signature.requestHash,
        chainId: signature.chainId,
        from: signature.from,
        r: signature.r,
        s: '0x${'2'.padLeft(64, '0')}',
        v: signature.v,
        yParity: signature.yParity,
        signedTxHash: signature.signedTxHash,
        signedAt: signature.signedAt,
        rawSignedTx: signature.rawSignedTx,
      );
      expect(check(badS).ok, isFalse);
      final badParity = ColdTxSignature(
        version: signature.version,
        requestId: signature.requestId,
        requestHash: signature.requestHash,
        chainId: signature.chainId,
        from: signature.from,
        r: signature.r,
        s: signature.s,
        v: signature.v,
        yParity: signature.yParity! ^ 1,
        signedTxHash: signature.signedTxHash,
        signedAt: signature.signedAt,
        rawSignedTx: signature.rawSignedTx,
      );
      expect(check(badParity).ok, isFalse);
      final badHash = ColdTxSignature(
        version: signature.version,
        requestId: signature.requestId,
        requestHash: signature.requestHash,
        chainId: signature.chainId,
        from: signature.from,
        r: signature.r,
        s: signature.s,
        v: signature.v,
        yParity: signature.yParity,
        signedTxHash: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        signedAt: signature.signedAt,
        rawSignedTx: signature.rawSignedTx,
      );
      expect(check(badHash).ok, isFalse);
    });
  });
}
