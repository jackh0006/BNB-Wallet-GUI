import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/fee_engine.dart';

FeeSourceSnapshot _source({
  String url = 'https://node.example',
  BigInt? base,
  List<BigInt> p10 = const [],
  List<BigInt> p50 = const [],
  List<BigInt> p90 = const [],
  List<double> ratios = const [],
  double? seconds = 1.5,
  double? jitter = 0.1,
  BigInt? legacy,
}) {
  final baseValue = base ?? BigInt.from(1000000000);
  final baseFees = [
    for (var i = 0; i < (p10.isEmpty ? 1 : p10.length) + 1; i++) baseValue,
  ];
  return FeeSourceSnapshot(
    source: url,
    baseFees: baseFees,
    rewards: [
      for (var i = 0; i < p10.length; i++) [p10[i], p50[i], p90[i]],
    ],
    gasUsedRatios: ratios,
    blockSeconds: seconds,
    blockJitter: jitter,
    legacyGasPrice: legacy,
  );
}

List<BigInt> _fill(int count, BigInt value) => List.filled(count, value);

List<double> _fillD(int count, double value) => List.filled(count, value);

void main() {
  group('FeeEngine.merge — live data, never hardcoded', () {
    test(
      'normal conditions: medians across nodes, middle tier recommended',
      () {
        final quote = FeeEngine.merge([
          _source(
            url: 'https://a',
            p10: _fill(5, BigInt.from(1)),
            p50: _fill(5, BigInt.from(2)),
            p90: _fill(5, BigInt.from(5)),
            ratios: const [0.5, 0.55, 0.6, 0.5, 0.55],
          ),
          _source(
            url: 'https://b',
            p10: _fill(5, BigInt.from(3)),
            p50: _fill(5, BigInt.from(4)),
            p90: _fill(5, BigInt.from(9)),
            ratios: const [0.6, 0.6, 0.65, 0.6, 0.6],
          ),
        ], tried: 2);

        expect(quote.sourcesAnswered, 2);
        expect(quote.singleSource, isFalse);
        expect(quote.confidence, 'high');
        expect(quote.recommendedIndex, 1);
        expect(quote.presets, hasLength(3));
        expect(quote.presets[1].label, 'Medium (recommended)');
        // median of {2,4} = 3 gwei priority
        expect(quote.presets[1].priorityFeePerGas, BigInt.from(3));
        expect(quote.reason, contains('Normal conditions'));
        expect(quote.blockSeconds, 1.5);
      },
    );

    test('empty chain: cheap tier recommended, all ETAs positive', () {
      final quote = FeeEngine.merge([
        _source(
          p10: _fill(20, BigInt.zero),
          p50: _fill(20, BigInt.zero),
          p90: _fill(20, BigInt.one),
          ratios: _fillD(20, 0.05),
        ),
      ], tried: 3);

      expect(quote.recommendedIndex, 0);
      expect(quote.presets[0].label, 'Low (recommended)');
      expect(quote.reason, contains('cheap tier'));
      expect(quote.presets[0].etaSecondsLow, greaterThanOrEqualTo(1));
      expect(
        quote.presets[0].etaSecondsHigh,
        greaterThan(quote.presets[0].etaSecondsLow!),
      );
      expect(quote.presets[0].target, contains('blocks'));
    });

    test('congested: top tier recommended and low tier carries a warning', () {
      final quote = FeeEngine.merge([
        _source(
          p10: _fill(20, BigInt.from(1)),
          p50: _fill(20, BigInt.from(3)),
          p90: _fill(20, BigInt.from(8)),
          ratios: _fillD(20, 0.92),
        ),
      ], tried: 1);

      expect(quote.recommendedIndex, 2);
      expect(quote.presets[2].label, contains('recommended'));
      expect(quote.presets[0].warning, isNotNull);
      expect(quote.presets[0].warning, contains('92% full'));
      expect(quote.reason, contains('full'));
      // congestion stretches the ETA: more blocks than the calm baseline
      expect(quote.presets[0].expectedBlocks! > 4, isTrue);
    });

    test('rising base fees push the recommendation up even at medium fill', () {
      final rising = [for (var i = 0; i < 21; i++) BigInt.from(100 + i * 10)];
      final snapshot = FeeSourceSnapshot(
        source: 'https://a',
        baseFees: rising,
        rewards: [
          for (var i = 0; i < 20; i++) [BigInt.one, BigInt.two, BigInt.from(5)],
        ],
        gasUsedRatios: _fillD(20, 0.5),
        blockSeconds: 1.5,
        blockJitter: 0.1,
      );
      final quote = FeeEngine.merge([snapshot], tried: 1);
      expect(quote.recommendedIndex, 2);
      expect(quote.reason, contains('rising'));
    });

    test('a lying node is dropped by the 3x outlier rule', () {
      final quote = FeeEngine.merge([
        _source(
          url: 'https://honest',
          p10: _fill(5, BigInt.from(1)),
          p50: _fill(5, BigInt.from(2)),
          p90: _fill(5, BigInt.from(4)),
          ratios: _fillD(5, 0.5),
        ),
        _source(
          url: 'https://liar',
          p10: _fill(5, BigInt.from(100)),
          p50: _fill(5, BigInt.from(200)),
          p90: _fill(5, BigInt.from(400)),
          ratios: _fillD(5, 0.5),
        ),
        _source(
          url: 'https://moderate',
          p10: _fill(5, BigInt.from(2)),
          p50: _fill(5, BigInt.from(3)),
          p90: _fill(5, BigInt.from(5)),
          ratios: _fillD(5, 0.5),
        ),
      ], tried: 3);

      // liar samples (100/200/400) exceed 3x the smallest -> dropped; the
      // even-count median floors, exactly like terminal v1's feeMedian.
      expect(quote.presets[0].priorityFeePerGas, BigInt.from(1));
      expect(quote.presets[2].priorityFeePerGas, BigInt.from(4));
      expect(quote.abnormal, isFalse);
    });

    test('mutually consistent but absurd quotes are flagged, not hidden', () {
      final huge = BigInt.from(20000) * BigInt.from(10).pow(9);
      final quote = FeeEngine.merge([
        _source(
          p10: _fill(5, huge),
          p50: _fill(5, huge),
          p90: _fill(5, huge),
          ratios: _fillD(5, 0.4),
        ),
        _source(
          p10: _fill(5, huge),
          p50: _fill(5, huge),
          p90: _fill(5, huge),
          ratios: _fillD(5, 0.4),
        ),
      ], tried: 2);

      expect(quote.abnormal, isTrue);
      expect(quote.reason, contains('abnormally high'));
    });

    test('single source is labelled as one point of view', () {
      final quote = FeeEngine.merge([
        _source(
          p10: _fill(5, BigInt.from(1)),
          p50: _fill(5, BigInt.from(2)),
          p90: _fill(5, BigInt.from(4)),
          ratios: _fillD(5, 0.5),
        ),
      ], tried: 3);

      expect(quote.singleSource, isTrue);
      expect(quote.confidence, 'low');
      expect(quote.reason, contains('Only one fee source'));
      expect(quote.sourceLabel, contains('one node'));
    });

    test('low tier is never offered below the observed live floor', () {
      final quote = FeeEngine.merge([
        _source(
          url: 'https://no-floor',
          p10: _fill(5, BigInt.zero),
          p50: _fill(5, BigInt.from(2)),
          p90: _fill(5, BigInt.from(4)),
          ratios: _fillD(5, 0.5),
        ),
        _source(
          url: 'https://floor',
          p10: _fill(5, BigInt.from(2)),
          p50: _fill(5, BigInt.from(3)),
          p90: _fill(5, BigInt.from(5)),
          ratios: _fillD(5, 0.5),
        ),
      ], tried: 2);

      expect(quote.floorWei, BigInt.from(2));
      expect(
        quote.presets[0].priorityFeePerGas,
        greaterThanOrEqualTo(BigInt.from(2)),
      );
      expect(quote.presets[0].warning, contains('floor'));
    });

    test('legacy-only nodes: multipliers match terminal v1 arithmetic', () {
      final gasPrice = BigInt.from(3000000000);
      final quote = FeeEngine.merge([
        _source(legacy: gasPrice, seconds: null),
        _source(legacy: gasPrice, seconds: null),
      ], tried: 2);

      const bps = [9000, 10000, 12500];
      for (var i = 0; i < 3; i++) {
        final expected =
            (gasPrice * BigInt.from(bps[i]) + BigInt.from(9999)) ~/
            BigInt.from(10000);
        expect(quote.presets[i].gasPrice, expected);
        expect(quote.presets[i].mode, 'legacy');
      }
      expect(quote.presets[1].label, contains('recommended'));
      expect(quote.reason, contains('fee history'));
    });

    test('no usable source is a truthful refusal, not a guess', () {
      expect(
        () => FeeEngine.merge([
          const FeeSourceSnapshot(source: 'https://dead'),
        ], tried: 3),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown block time falls back to words, not invented numbers', () {
      final quote = FeeEngine.merge([
        _source(
          p10: _fill(5, BigInt.from(1)),
          p50: _fill(5, BigInt.from(2)),
          p90: _fill(5, BigInt.from(4)),
          ratios: _fillD(5, 0.5),
          seconds: null,
          jitter: null,
        ),
      ], tried: 1);

      expect(quote.blockSeconds, isNull);
      expect(quote.presets[0].etaSecondsLow, isNull);
      expect(quote.presets[0].target, contains('block time unknown'));
    });
  });

  group('FeeEngine.formatGwei', () {
    test('trims trailing zeros and keeps whole gwei readable', () {
      expect(FeeEngine.formatGwei(BigInt.from(1000000000)), '1');
      expect(FeeEngine.formatGwei(BigInt.from(1500000000)), '1.5');
      expect(FeeEngine.formatGwei(BigInt.from(100000000)), '0.1');
      expect(FeeEngine.formatGwei(BigInt.zero), '0');
    });
  });
}
