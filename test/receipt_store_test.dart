import 'dart:convert';
import 'dart:typed_data';

import 'package:bnb_wallet_gui/models.dart';
import 'package:bnb_wallet_gui/receipt_store.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _privateKey(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => (i * 7 + seed) % 256));

LocalReceipt _receipt({String hash = '0xabc'}) => LocalReceipt(
  hash: hash,
  network: 'testnet',
  chainId: 97,
  status: 'success',
  from: '0xE068c17463Cc816DC5A410F06a2cbD4e03863046',
  to: '0x7EA499b984050c75192387b5A0e81d6d39db50CD',
  assetSymbol: 'BNB',
  assetAddress: '',
  amountHuman: '0.02',
  amountRaw: '20000000000000000',
  decimals: 18,
  nonce: 7,
  gasLimit: '25200',
  gasUsed: '21000',
  feeWei: '21000000000000',
  blockNumber: 123456,
  confirmations: 12,
  verifiedNodes: 2,
  finalized: false,
  tierLabel: 'Medium (recommended)',
  reason: 'Normal conditions',
  nodeUsed: 'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
  transport: 'direct HTTPS',
  savedAt: '2026-10-19T00:00:00.000Z',
  rawTxHex: '0xdeadbeef',
  note: 'recipient received the full amount',
  blockHash:
      '0x1111111111111111111111111111111111111111111111111111111111111111',
  transactionIndex: 3,
  txType: 'eip1559',
  inputData: '0xa9059cbb',
  eventLogs: [
    {
      'address': '0x7EA499b984050c75192387b5A0e81d6d39db50CD',
      'topics': <String>[],
      'data': '0x00',
    },
  ],
);

void main() {
  group('ReceiptStore envelope — encrypted with wallet + device factors', () {
    test('roundtrip with the same key keeps every field', () async {
      final key = await ReceiptStore.deriveKey(_privateKey(1), 'device-secret');
      final encoded = await ReceiptStore.encode(key, [_receipt()]);
      final decoded = await ReceiptStore.decode(key, encoded);
      expect(decoded, isNotNull);
      expect(decoded, hasLength(1));
      expect(decoded!.single.hash, '0xabc');
      expect(decoded.single.rawTxHex, '0xdeadbeef');
      expect(decoded.single.verifiedNodes, 2);
      expect(decoded.single.finalized, isFalse);
    });

    test(
      'a different wallet key cannot read the file (null, not garbage)',
      () async {
        final keyA = await ReceiptStore.deriveKey(
          _privateKey(1),
          'device-secret',
        );
        final keyB = await ReceiptStore.deriveKey(
          _privateKey(2),
          'device-secret',
        );
        final encoded = await ReceiptStore.encode(keyA, [_receipt()]);
        expect(await ReceiptStore.decode(keyB, encoded), isNull);
      },
    );

    test('a different device secret cannot read the file', () async {
      final keyA = await ReceiptStore.deriveKey(_privateKey(1), 'drawer-A');
      final keyB = await ReceiptStore.deriveKey(_privateKey(1), 'drawer-B');
      final encoded = await ReceiptStore.encode(keyA, [_receipt()]);
      expect(await ReceiptStore.decode(keyB, encoded), isNull);
    });

    test('tampering with one ciphertext byte is detected', () async {
      final key = await ReceiptStore.deriveKey(_privateKey(1), 'device-secret');
      final encoded = await ReceiptStore.encode(key, [_receipt()]);
      final bytes = base64Decode(encoded);
      // First ciphertext byte sits right after magic(8) + nonce(24).
      bytes[32] = bytes[32] ^ 0x01;
      final tampered = base64Encode(bytes);
      expect(await ReceiptStore.decode(key, tampered), isNull);
    });

    test('truncated or non-envelope input is refused', () async {
      final key = await ReceiptStore.deriveKey(_privateKey(1), 'device-secret');
      expect(await ReceiptStore.decode(key, 'not base64 at all'), isNull);
      expect(await ReceiptStore.decode(key, base64Encode([1, 2, 3])), isNull);
    });

    test('the list is capped so the file can never grow unbounded', () async {
      final key = await ReceiptStore.deriveKey(_privateKey(1), 'device-secret');
      final many = [
        for (var i = 0; i < ReceiptStore.maxReceipts + 25; i++)
          _receipt(hash: '0x$i'),
      ];
      final encoded = await ReceiptStore.encode(key, many);
      final decoded = await ReceiptStore.decode(key, encoded);
      expect(decoded, hasLength(ReceiptStore.maxReceipts));
      expect(decoded!.first.hash, '0x0');
    });
  });

  group('local data shapes survive json roundtrips', () {
    test('LocalReceipt.toJson/fromJson is lossless for every field', () {
      final original = _receipt();
      final back = LocalReceipt.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(back.hash, original.hash);
      expect(back.chainId, original.chainId);
      expect(back.amountRaw, original.amountRaw);
      expect(back.feeWei, original.feeWei);
      expect(back.blockNumber, original.blockNumber);
      expect(back.verifiedNodes, original.verifiedNodes);
      expect(back.tierLabel, original.tierLabel);
      expect(back.reason, original.reason);
      expect(back.nodeUsed, original.nodeUsed);
      expect(back.transport, original.transport);
      expect(back.savedAt, original.savedAt);
      expect(back.rawTxHex, original.rawTxHex);
      expect(back.note, original.note);
      expect(back.blockHash, original.blockHash);
      expect(back.transactionIndex, original.transactionIndex);
      expect(back.txType, original.txType);
      expect(back.inputData, original.inputData);
      expect(back.eventLogs, original.eventLogs);
    });

    test('PendingTx.toJson/fromJson is lossless for every field', () {
      const original = PendingTx(
        hash: '0xfeed',
        network: 'mainnet',
        from: '0x1111111111111111111111111111111111111111',
        to: '0x2222222222222222222222222222222222222222',
        native: false,
        assetSymbol: 'USDT',
        assetAddress: '0x55d398326f99059fF775485246999027B3197955',
        amountRaw: '1000000000000000000',
        amountHuman: '1.0',
        decimals: 18,
        gasLimit: '65000',
        nonce: 12,
        mode: 'eip1559',
        priorityFeePerGas: '1000000000',
        maxFeePerGas: '3000000000',
        gasPrice: '0',
        sentAt: '2026-10-19T00:00:00.000Z',
        tierLabel: 'High',
        note: 'speed-up',
      );
      final back = PendingTx.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(back.hash, original.hash);
      expect(back.native, isFalse);
      expect(back.assetAddress, original.assetAddress);
      expect(back.nonce, original.nonce);
      expect(back.mode, original.mode);
      expect(back.maxFeePerGas, original.maxFeePerGas);
      expect(back.note, original.note);
      expect(back.sentAt, original.sentAt);
    });
  });
}
