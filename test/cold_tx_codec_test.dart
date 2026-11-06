import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

import 'package:bnb_wallet_gui/cold_tx_codec.dart';
import 'package:bnb_wallet_gui/cold_wallet.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';

void main() {
  const phrase = 'test test test test test test test test test test test junk';
  const from = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const to = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';

  const expectedUnsigned =
      '0x02ef3880843b9aca00843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000080c0';
  const expectedDigest =
      '0x49a4706f2144d8540edb6e02d92004093496c59b83b3a2e0cc261070f7c1f0cb';
  const expectedRaw =
      '0x02f8723880843b9aca00843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000080c001a09e14c0496472a3ea4af35ece19224ff815dfd656a568524a84130c722b959afda0393349471326e2196f8d11c49649f17df740476d4f5d6447f8dfa20bd0d66a4b';
  const expectedHash =
      '0xd21376c58b99ea2d445d7228223befcfd5b42fe0107ddb5696976346a56f93f0';

  ColdTxRequest request({String id = 'test-request-vector-1'}) => ColdTxRequest(
    version: 1,
    chainId: 56,
    from: from,
    to: to,
    value: '0xde0b6b3a7640000',
    gasLimit: '0x5208',
    maxFeePerGas: '0x3b9aca00',
    maxPriorityFeePerGas: '0x3b9aca00',
    nonce: 0,
    data: '0x',
    assetInfo: const ColdTxAssetInfo(isNative: true),
    expiresAt: DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .toIso8601String(),
    createdAt: DateTime.now().toUtc().toIso8601String(),
    id: id,
  );

  test(
    'Dart unsigned payload and digest equal the independent ethers vector',
    () {
      final tx = request();
      final fields = ColdTxFields(
        chainId: tx.chainId,
        nonce: BigInt.from(tx.nonce),
        maxPriorityFeePerGas: BigInt.parse('3b9aca00', radix: 16),
        maxFeePerGas: BigInt.parse('3b9aca00', radix: 16),
        gasLimit: BigInt.parse('5208', radix: 16),
        to: tx.to,
        value: BigInt.parse('de0b6b3a7640000', radix: 16),
        data: Uint8List(0),
        accessList: const [],
      );
      expect(
        bytesToHex(fields.unsignedPayload(), include0x: true),
        expectedUnsigned,
      );
      expect(fields.signingDigestHex, expectedDigest);
    },
  );

  test(
    'Dart signature and raw transaction equal the ethers vector exactly',
    () {
      final signature = WalletCore.signTransaction(
        phrase: phrase,
        request: request(),
      );
      expect(signature.requestHash?.toLowerCase(), expectedDigest);
      expect(signature.yParity, 1);
      expect(signature.v, '0x1');
      expect(
        signature.r.toLowerCase(),
        '0x9e14c0496472a3ea4af35ece19224ff815dfd656a568524a84130c722b959afd',
      );
      expect(
        signature.s.toLowerCase(),
        '0x393349471326e2196f8d11c49649f17df740476d4f5d6447f8dfa20bd0d66a4b',
      );
      expect(signature.rawSignedTx?.toLowerCase(), expectedRaw);
      expect(signature.signedTxHash.toLowerCase(), expectedHash);
      expect(signature.from.toLowerCase(), from.toLowerCase());

      final parsed = ColdTxCodec.parseSigned(
        Uint8List.fromList(hexToBytes(signature.rawSignedTx!)),
      );
      expect(parsed.hash.toLowerCase(), expectedHash);
      expect(parsed.yParity, 1);
      expect(parsed.fields.signingDigestHex, expectedDigest);
    },
  );

  test('strict verifier accepts the exact vector and reports the hash', () {
    final signature = WalletCore.signTransaction(
      phrase: phrase,
      request: request(),
    );
    final result = WalletCore.verifyColdSignatureDetailed(
      request: request(),
      signature: signature,
      expectedFrom: from,
    );
    expect(result.ok, isTrue, reason: result.reason);
    expect(result.txHash?.toLowerCase(), expectedHash);
    expect(result.rawSignedTx?.toLowerCase(), expectedRaw);
  });

  test('raw transaction parser rejects a non-canonical field', () {
    // The canonical raw transaction has data = 0x80.  Switching it to the
    // empty-list byte 0xc0 changes the serialized bytes without changing the
    // signature, so the canonical re-encode check must reject it.
    final badHex = expectedRaw.replaceFirst(
      '764000080c001a0',
      '7640000c0c001a0',
    );
    expect(badHex, isNot(expectedRaw));
    expect(
      () => ColdTxCodec.parseSigned(Uint8List.fromList(hexToBytes(badHex))),
      throwsA(isA<ColdTxFormatException>()),
    );
  });
  test('validateFields rejects the zero address', () {
    expect(
      () => ColdTxCodec.validateFields(
        chainId: 56,
        nonce: BigInt.zero,
        maxPriorityFeePerGas: BigInt.one,
        maxFeePerGas: BigInt.from(2),
        gasLimit: BigInt.from(21000),
        to: '0x0000000000000000000000000000000000000000',
        value: BigInt.zero,
        data: Uint8List(0),
        accessList: const [],
      ),
      throwsA(
        isA<ColdTxFormatException>().having(
          (error) => error.message,
          'message',
          contains('zero address'),
        ),
      ),
    );
  });

  test('signedPayload rejects a high-s signature', () {
    final fields = ColdTxFields(
      chainId: 56,
      nonce: BigInt.zero,
      maxPriorityFeePerGas: BigInt.one,
      maxFeePerGas: BigInt.from(2),
      gasLimit: BigInt.from(21000),
      to: to,
      value: BigInt.zero,
      data: Uint8List(0),
      accessList: const [],
    );
    final halfN = BigInt.parse(
      '7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0',
      radix: 16,
    );
    expect(
      () => ColdTxCodec.signedPayload(
        fields,
        yParity: 0,
        r: BigInt.one,
        s: halfN + BigInt.one,
      ),
      throwsA(
        isA<ColdTxFormatException>().having(
          (error) => error.message,
          'message',
          contains('low-s'),
        ),
      ),
    );
  });
}
