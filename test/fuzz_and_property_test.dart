// Property-based and deterministic mutation tests for the security-critical
// parsers. These are not coverage-guided fuzzing: each run uses a fixed seed,
// so a failure is reproducible and CI time is bounded.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bnb_wallet_gui/cold_tx_codec.dart';
import 'package:bnb_wallet_gui/cold_wallet_protocol.dart';
import 'package:bnb_wallet_gui/send_intent.dart';
import 'package:bnb_wallet_gui/vault.dart';
import 'package:bnb_wallet_gui/wallet_core.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List randomBytes(Random random, int maxLength) {
  final length = random.nextInt(maxLength + 1);
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

ColdTxFields seedFields() => ColdTxFields(
  chainId: 56,
  nonce: BigInt.one,
  maxPriorityFeePerGas: BigInt.one,
  maxFeePerGas: BigInt.from(2),
  gasLimit: BigInt.from(21000),
  to: '0x1111111111111111111111111111111111111111',
  value: BigInt.one,
  data: Uint8List(0),
  accessList: const [],
);

void main() {
  group('property: amount formatting round-trips exactly', () {
    test(
      'parseAmount(formatUnits(v, d), d) == v for random uint256 values',
      () {
        final random = Random(20261106);
        for (var i = 0; i < 2000; i++) {
          final decimals = random.nextInt(19);
          final bits = random.nextInt(256);
          final value = bits == 0
              ? BigInt.zero
              : BigInt.parse(
                  List<int>.generate(
                    (bits + 7) ~/ 8,
                    (_) => random.nextInt(256),
                  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
                  radix: 16,
                );
          final text = WalletCore.formatUnits(value, decimals);
          expect(
            WalletCore.parseAmount(text, decimals),
            value,
            reason: 'decimals=$decimals text=$text',
          );
        }
      },
    );

    test('parseAmount rejects overflow and non-positive input', () {
      for (final text in ['-1', '+1', '', '.', '1.2.3', '1e18', 'abc']) {
        expect(
          () => WalletCore.parseAmount(text, 18),
          throwsArgumentError,
          reason: text,
        );
      }
      expect(
        () => WalletCore.parseAmount('1.0000000000000000001', 18),
        throwsArgumentError,
      );
      final max =
          '115792089237316195423570985008687907853269984665640564039457584007913129639935';
      expect(WalletCore.parseAmount(max, 0), BigInt.parse(max));
      expect(() => WalletCore.parseAmount('${max}0', 0), throwsArgumentError);
    });
  });

  group('property: address checksum and lookalike heuristic', () {
    test('random 20-byte addresses checksum, validate and round-trip', () {
      final random = Random(424242);
      for (var i = 0; i < 1000; i++) {
        final raw = randomBytes(random, 32);
        final bytes = Uint8List(20);
        for (var j = 0; j < 20; j++) {
          bytes[j] = raw.isEmpty ? 0 : raw[j % raw.length];
        }
        final hex =
            '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
        final checksummed = WalletCore.checksumAddress(hex);
        expect(WalletCore.isValidAddress(checksummed), isTrue);
        expect(checksummed.toLowerCase(), hex.toLowerCase());
        expect(
          WalletCore.checksumAddress(checksummed.toLowerCase()),
          checksummed,
        );
      }
    });

    test('sharesAffixes is only a lookalike hint, never an identity claim', () {
      const known = '0x1111111111111111111111111111111111111111';
      expect(
        WalletCore.sharesAffixes(
          known,
          '0x1111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1111',
        ),
        isTrue,
      );
      expect(
        WalletCore.sharesAffixes(
          known,
          '0x2222222222222222222222222222222222222222',
        ),
        isFalse,
      );
      expect(WalletCore.sharesAffixes('not-an-address', known), isFalse);
    });
  });

  group('property: gas buffer never closes below the simulation', () {
    test('every estimate from 1 to 10000 gains headroom', () {
      for (var i = 1; i <= 10000; i++) {
        expect(
          SendIntent.gasLimitWithBuffer(BigInt.from(i)) > BigInt.from(i),
          isTrue,
        );
      }
    });
  });

  group('fuzz: canonical EIP-1559 parser only reports format errors', () {
    test('2000 random byte strings never escape as a crash', () {
      final random = Random(1559);
      for (var i = 0; i < 2000; i++) {
        final bytes = randomBytes(random, 300);
        try {
          ColdTxCodec.parseSigned(bytes);
        } on ColdTxFormatException {
          // The only acceptable failure for hostile input.
        } catch (error) {
          fail(
            'input $i (${bytes.length} bytes) threw ${error.runtimeType}: $error',
          );
        }
      }
    });

    test('mutations of a valid signed transaction stay format errors', () {
      final random = Random(15590);
      final seed = ColdTxCodec.signedPayload(
        seedFields(),
        yParity: 0,
        r: BigInt.one,
        s: BigInt.one,
      );
      expect(ColdTxCodec.parseSigned(seed).fields.chainId, 56);
      for (var i = 0; i < 2000; i++) {
        final mutated = Uint8List.fromList(seed);
        final flips = 1 + random.nextInt(3);
        for (var j = 0; j < flips; j++) {
          mutated[random.nextInt(mutated.length)] = random.nextInt(256);
        }
        try {
          ColdTxCodec.parseSigned(mutated);
        } on ColdTxFormatException {
          // Expected for hostile mutations.
        } catch (error) {
          fail('mutation $i threw ${error.runtimeType}: $error');
        }
      }
    });
  });

  group('fuzz: vault and cold-envelope parsers fail closed', () {
    test('random vault bytes never escape as a crash', () async {
      final random = Random(777);
      for (var i = 0; i < 500; i++) {
        final bytes = randomBytes(random, 400);
        try {
          await VaultCipher.decrypt(
            'password',
            base64Encode(bytes),
            'device-secret',
          );
        } on VaultException {
          // Expected.
        } catch (error) {
          fail('vault input $i threw ${error.runtimeType}: $error');
        }
      }
    });

    test('random cold envelopes never escape as a crash', () {
      final random = Random(778);
      for (var i = 0; i < 1000; i++) {
        final text = String.fromCharCodes(
          List<int>.generate(random.nextInt(200), (_) => random.nextInt(128)),
        );
        try {
          ColdWalletProtocol.decodeEnvelope(
            text: text,
            expectedKind: ColdWalletProtocol.kindRequest,
            maxBytes: ColdWalletProtocol.maxRequestBytes,
          );
        } on ColdProtocolException {
          // Expected.
        } catch (error) {
          fail('envelope $i threw ${error.runtimeType}: $error');
        }
      }
    });
  });

  group('fuzz: ERC-20 intent decoder is total on hostile bytes', () {
    test('random calldata either decodes or throws StateError', () {
      final random = Random(20);
      for (var i = 0; i < 2000; i++) {
        final bytes = randomBytes(random, 200);
        try {
          SendIntent.decodeErc20Transfer(bytes);
        } on StateError {
          // Expected.
        } catch (error) {
          fail('calldata $i threw ${error.runtimeType}: $error');
        }
      }
    });
  });
}
