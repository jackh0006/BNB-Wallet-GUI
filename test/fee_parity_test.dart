import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/rpc_service.dart';

/// Round-6 terminal parity: pins the fee arithmetic to the exact terminal v1
/// formulas (`bnb-terminal-wallet-1.0.2/src/fees.js`) so the GUI can never
/// silently drift from the reference wallet.
void main() {
  group('fee math — terminal v1 parity', () {
    test('median: middle for odd counts, floor for even (fees.js)', () {
      expect(RpcService.feeMedian([BigInt.from(5)]), BigInt.from(5));
      expect(RpcService.feeMedian([BigInt.from(1), BigInt.from(3)]), BigInt.from(2));
      // (1+2)/2 in integer math is 1 (floor) — exactly `(a + b) / 2n`.
      expect(RpcService.feeMedian([BigInt.from(1), BigInt.from(2)]), BigInt.from(1));
      expect(
        RpcService.feeMedian([BigInt.from(9), BigInt.from(3), BigInt.from(5)]),
        BigInt.from(5),
      );
      expect(() => RpcService.feeMedian([]), throwsStateError);
    });

    test('bps multiplication rounds UP like fees.js: (v·bps + 9999)/10000', () {
      expect(RpcService.feeMultiplyBps(BigInt.from(100), 9000), BigInt.from(90));
      expect(RpcService.feeMultiplyBps(BigInt.from(100), 10000), BigInt.from(100));
      expect(RpcService.feeMultiplyBps(BigInt.from(100), 12500), BigInt.from(125));
      // Distinguishable from floor: 3·3333 = 0.9999 → must round to 1.
      expect(RpcService.feeMultiplyBps(BigInt.from(3), 3333), BigInt.one);
    });

    test('EIP-1559 tiers: median priority, maxFee = base×2 + tip, expected = base + tip',
        () {
      final rpc = RpcService();
      final base = BigInt.from(100);
      final rewards = [
        [BigInt.from(5), BigInt.from(10), BigInt.from(20)],
        [BigInt.from(7), BigInt.from(12), BigInt.from(22)],
        [BigInt.from(6), BigInt.from(11), BigInt.from(21)],
        [BigInt.from(4), BigInt.from(9), BigInt.from(19)],
        [BigInt.from(8), BigInt.from(13), BigInt.from(23)],
      ];
      final presets = rpc.eip1559Presets(base, rewards);
      expect(presets, hasLength(3));
      expect(presets[0].label, 'Low');
      expect(presets[1].label, 'Medium (recommended)');
      expect(presets[2].label, 'High');
      final tips = [BigInt.from(6), BigInt.from(11), BigInt.from(21)];
      for (var i = 0; i < 3; i++) {
        expect(presets[i].priorityFeePerGas, tips[i]);
        expect(presets[i].maxFeePerGas, base * BigInt.two + tips[i]);
        expect(presets[i].expectedFeePerGas, base + tips[i]);
        expect(presets[i].mode, 'eip1559');
        expect(presets[i].source, 'recent 5 blocks · priority-fee percentiles');
      }
    });

    test('legacy fallback: gasPrice ×0.90 / ×1.00 / ×1.25 (fees.js)', () {
      final rpc = RpcService();
      final presets = rpc.legacyPresets(BigInt.from(100));
      expect(presets, hasLength(3));
      expect(presets[0].gasPrice, BigInt.from(90));
      expect(presets[1].gasPrice, BigInt.from(100));
      expect(presets[2].gasPrice, BigInt.from(125));
      for (final preset in presets) {
        expect(preset.priorityFeePerGas, BigInt.zero);
        expect(preset.maxFeePerGas, preset.gasPrice);
        expect(preset.expectedFeePerGas, preset.gasPrice);
        expect(preset.mode, 'legacy');
        expect(preset.source, 'RPC gas-price quote · legacy fallback');
      }
    });
  });
}
