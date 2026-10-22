import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/send_intent.dart';

/// Round-6 terminal parity: the pre-signature re-checks (terminal v1
/// `verifyTransactionIntent`) and the exact gas-limit formula
/// `(estimate * 120n + 99n) / 100n`.
Uint8List transferData(String recipient, BigInt amount) {
  final addr = recipient.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
  final amt = amount.toRadixString(16).padLeft(64, '0');
  final hex = 'a9059cbb$addr$amt';
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

void main() {
  const token = '0x55d398326f99059fF775485246999027B3197955';
  const recipient = '0x1111111111111111111111111111111111111111';
  final amount = BigInt.parse('1000000000000000000'); // 1 token / 1 BNB

  group('gasLimitWithBuffer — terminal v1 formula', () {
    test('exact formula parity: (est*120 + 99) / 100', () {
      expect(SendIntent.gasLimitWithBuffer(BigInt.from(21000)), BigInt.from(25200));
      expect(SendIntent.gasLimitWithBuffer(BigInt.from(1)), BigInt.from(2));
      // 7 * 1.2 = 8.4 exactly → rounds UP to 9, never down to 8.
      expect(SendIntent.gasLimitWithBuffer(BigInt.from(7)), BigInt.from(9));
    });

    test('the limit is never below the simulation (old GUI bug: floor lost the buffer)', () {
      for (var i = 1; i <= 2000; i++) {
        final estimate = BigInt.from(i);
        final limit = SendIntent.gasLimitWithBuffer(estimate);
        expect(limit > estimate, isTrue, reason: 'estimate $i produced limit $limit');
      }
    });
  });

  group('decodeErc20Transfer — byte-level calldata check', () {
    test('round-trips recipient and amount', () {
      final data = transferData(recipient, amount);
      final (decodedTo, decodedAmount) = SendIntent.decodeErc20Transfer(data);
      expect(decodedTo.toLowerCase(), recipient);
      expect(decodedAmount, amount);
    });

    test('rejects a different selector', () {
      final data = transferData(recipient, amount);
      data[0] = 0x00;
      expect(() => SendIntent.decodeErc20Transfer(data), throwsStateError);
    });

    test('rejects truncated calldata', () {
      final data = transferData(recipient, amount);
      expect(
        () => SendIntent.decodeErc20Transfer(data.sublist(0, 40)),
        throwsStateError,
      );
    });

    test('rejects a recipient word with a dirty prefix', () {
      final hex = 'a9059cbb'
          'ff0000000000000000000000001111111111111111111111111111111111111111'
          '${amount.toRadixString(16).padLeft(64, '0')}';
      final data = Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
      expect(() => SendIntent.decodeErc20Transfer(data), throwsStateError);
    });
  });

  group('verify — refuses to sign anything that changed after review', () {
    void verifyNative({BigInt? value, int chainId = 56, String txTo = recipient}) {
      SendIntent.verify(
        chainId: chainId,
        intendedChainId: 56,
        native: true,
        intendedRecipient: recipient,
        intendedAmount: amount,
        tokenAddress: '',
        txTo: txTo,
        txValue: value ?? amount,
        txData: Uint8List(0),
        txGasLimit: BigInt.from(25200),
        txGasPrice: BigInt.from(5),
        txMaxFeePerGas: null,
        txMaxPriorityFeePerGas: null,
        feeMode: 'legacy',
        expectedGasPrice: BigInt.from(5),
        expectedMaxFee: BigInt.zero,
        expectedPriority: BigInt.zero,
      );
    }

    test('native transfer that matches review passes', () {
      expect(() => verifyNative(), returnsNormally);
    });

    test('checksum case differences do not break the comparison', () {
      expect(
        () => verifyNative(txTo: '0x1111111111111111111111111111111111111111'.toUpperCase()),
        returnsNormally,
      );
    });

    test('changed amount is refused', () {
      expect(
        () => verifyNative(value: amount - BigInt.one),
        throwsA(isA<StateError>()),
      );
    });

    test('changed recipient is refused', () {
      expect(
        () => verifyNative(txTo: '0x2222222222222222222222222222222222222222'),
        throwsA(isA<StateError>()),
      );
    });

    test('chain switch between review and signing is refused', () {
      expect(
        () => verifyNative(chainId: 97),
        throwsA(isA<StateError>()),
      );
    });

    test('missing gas limit is refused', () {
      expect(
        () => SendIntent.verify(
          chainId: 56,
          intendedChainId: 56,
          native: true,
          intendedRecipient: recipient,
          intendedAmount: amount,
          tokenAddress: '',
          txTo: recipient,
          txValue: amount,
          txData: Uint8List(0),
          txGasLimit: null,
          txGasPrice: BigInt.from(5),
          txMaxFeePerGas: null,
          txMaxPriorityFeePerGas: null,
          feeMode: 'legacy',
          expectedGasPrice: BigInt.from(5),
          expectedMaxFee: BigInt.zero,
          expectedPriority: BigInt.zero,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('native transfer carrying calldata is refused', () {
      expect(
        () => SendIntent.verify(
          chainId: 56,
          intendedChainId: 56,
          native: true,
          intendedRecipient: recipient,
          intendedAmount: amount,
          tokenAddress: '',
          txTo: recipient,
          txValue: amount,
          txData: transferData(recipient, amount),
          txGasLimit: BigInt.from(25200),
          txGasPrice: BigInt.from(5),
          txMaxFeePerGas: null,
          txMaxPriorityFeePerGas: null,
          feeMode: 'legacy',
          expectedGasPrice: BigInt.from(5),
          expectedMaxFee: BigInt.zero,
          expectedPriority: BigInt.zero,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('token transfer that matches review passes', () {
      SendIntent.verify(
        chainId: 56,
        intendedChainId: 56,
        native: false,
        intendedRecipient: recipient,
        intendedAmount: amount,
        tokenAddress: token,
        txTo: token,
        txValue: null,
        txData: transferData(recipient, amount),
        txGasLimit: BigInt.from(65000),
        txGasPrice: BigInt.from(5),
        txMaxFeePerGas: null,
        txMaxPriorityFeePerGas: null,
        feeMode: 'legacy',
        expectedGasPrice: BigInt.from(5),
        expectedMaxFee: BigInt.zero,
        expectedPriority: BigInt.zero,
      );
    });

    test('token transfer with a changed calldata amount is refused', () {
      expect(
        () => SendIntent.verify(
          chainId: 56,
          intendedChainId: 56,
          native: false,
          intendedRecipient: recipient,
          intendedAmount: amount,
          tokenAddress: token,
          txTo: token,
          txValue: null,
          txData: transferData(recipient, amount + BigInt.one),
          txGasLimit: BigInt.from(65000),
          txGasPrice: BigInt.from(5),
          txMaxFeePerGas: null,
          txMaxPriorityFeePerGas: null,
          feeMode: 'legacy',
          expectedGasPrice: BigInt.from(5),
          expectedMaxFee: BigInt.zero,
          expectedPriority: BigInt.zero,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('token transfer with a swapped contract is refused', () {
      expect(
        () => SendIntent.verify(
          chainId: 56,
          intendedChainId: 56,
          native: false,
          intendedRecipient: recipient,
          intendedAmount: amount,
          tokenAddress: token,
          txTo: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
          txValue: null,
          txData: transferData(recipient, amount),
          txGasLimit: BigInt.from(65000),
          txGasPrice: BigInt.from(5),
          txMaxFeePerGas: null,
          txMaxPriorityFeePerGas: null,
          feeMode: 'legacy',
          expectedGasPrice: BigInt.from(5),
          expectedMaxFee: BigInt.zero,
          expectedPriority: BigInt.zero,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('EIP-1559 fee drift is refused', () {
      expect(
        () => SendIntent.verify(
          chainId: 56,
          intendedChainId: 56,
          native: true,
          intendedRecipient: recipient,
          intendedAmount: amount,
          tokenAddress: '',
          txTo: recipient,
          txValue: amount,
          txData: Uint8List(0),
          txGasLimit: BigInt.from(25200),
          txGasPrice: null,
          txMaxFeePerGas: BigInt.from(11),
          txMaxPriorityFeePerGas: BigInt.from(3),
          feeMode: 'eip1559',
          expectedGasPrice: BigInt.zero,
          expectedMaxFee: BigInt.from(10),
          expectedPriority: BigInt.from(3),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('legacy gas-price drift is refused', () {
      expect(
        () => SendIntent.verify(
          chainId: 56,
          intendedChainId: 56,
          native: true,
          intendedRecipient: recipient,
          intendedAmount: amount,
          tokenAddress: '',
          txTo: recipient,
          txValue: amount,
          txData: Uint8List(0),
          txGasLimit: BigInt.from(25200),
          txGasPrice: BigInt.from(6),
          txMaxFeePerGas: null,
          txMaxPriorityFeePerGas: null,
          feeMode: 'legacy',
          expectedGasPrice: BigInt.from(5),
          expectedMaxFee: BigInt.zero,
          expectedPriority: BigInt.zero,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
