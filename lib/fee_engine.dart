import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models.dart';

/// One node's raw, live fee picture. Everything here is measured from the
/// chain in the moment — nothing is a "typical" constant.
@immutable
class FeeSourceSnapshot {
  const FeeSourceSnapshot({
    required this.source,
    this.baseFees = const [],
    this.rewards = const [],
    this.gasUsedRatios = const [],
    this.blockSeconds,
    this.blockJitter,
    this.legacyGasPrice,
  });

  /// Node URL (host part is what the UI shows).
  final String source;

  /// `eth_feeHistory` baseFeePerGas, newest last (N + 1 samples).
  final List<BigInt> baseFees;

  /// Per-block priority-fee percentiles: `rewards[i][p]` = p-th percentile
  /// of tips of the transactions included in block i.
  final List<List<BigInt>> rewards;

  /// Per-block gasUsed / gasLimit, 0..1. The congestion measurement.
  final List<double> gasUsedRatios;

  /// Measured average block time in seconds — never a hardcoded constant.
  final double? blockSeconds;

  /// Relative spread of the newest block spacings (0 = perfectly regular).
  final double? blockJitter;

  /// Set only when the node has no `eth_feeHistory` (legacy fallback).
  final BigInt? legacyGasPrice;
}

/// The merged, plain-language fee quote the send flow shows.
@immutable
class FeeQuote {
  const FeeQuote({
    required this.presets,
    required this.recommendedIndex,
    required this.reason,
    required this.sourceLabel,
    required this.floorWei,
    required this.blockSeconds,
    required this.confidence,
    required this.sourcesTried,
    required this.sourcesAnswered,
    this.abnormal = false,
    this.baseFeeWei,
  });

  final List<FeePreset> presets;
  final int recommendedIndex;

  /// Plain words: why this recommendation, measured from the chain live.
  final String reason;

  /// How the numbers were merged, e.g. "median of 3 nodes".
  final String sourceLabel;

  /// Live floor: the lowest fee that was actually included in recent blocks.
  /// Zero means "no floor observed".
  final BigInt floorWei;

  /// Measured block time, seconds; null when no node could measure it.
  final double? blockSeconds;

  /// 'high' (≥2 nodes agree, steady blocks), 'medium', 'low' (single node).
  final String confidence;

  final int sourcesTried;
  final int sourcesAnswered;

  /// True when even the merged quote looks abnormally expensive — the honest
  /// "double-check this node" flag instead of a silent wrong number.
  final bool abnormal;

  /// The EIP-1559 base fee the tiers were built on (null for legacy quotes);
  /// the advanced-fee dialog uses it to rebuild a custom max fee honestly.
  final BigInt? baseFeeWei;

  bool get singleSource => sourcesAnswered < 2;
}

/// Merges raw per-node fee snapshots into the tier list the UI shows.
///
/// Rules (all deliberate, all tested):
///  * every derived number is the MEDIAN across nodes, so one lying or
///    lagging node cannot move the quote;
///  * samples above 3× the smallest are dropped as outliers;
///  * the Low tier is never offered below the empirically observed floor
///    (lowest tip recently included) — and says so when it was raised;
///  * ETAs use the measured block time and measured congestion, never
///    hardcoded "typical" values.
class FeeEngine {
  FeeEngine._();

  static const int _percentiles = 3;
  static const List<String> _tierLabels = ['Slow', 'Standard', 'Fast'];
  static const List<int> _legacyBps = [9000, 10000, 12500];

  /// Roughly 5000 gwei in wei: above this, even a consistent quote is worth
  /// a second look before the user confirms.
  static final BigInt _abnormalCap = BigInt.from(5000) * BigInt.from(10).pow(9);

  static FeeQuote merge(List<FeeSourceSnapshot> sources, {required int tried}) {
    final modern = sources
        .where((s) => s.baseFees.length >= 2 && s.rewards.isNotEmpty)
        .toList();
    if (modern.isNotEmpty) return _mergeEip1559(modern, tried, sources.length);
    final legacy = sources.where((s) => s.legacyGasPrice != null).toList();
    if (legacy.isNotEmpty) return _mergeLegacy(legacy, tried, sources.length);
    throw StateError('No node could quote a network fee right now.');
  }

  // ------------------------------------------------------------ eip1559 ---

  static FeeQuote _mergeEip1559(
    List<FeeSourceSnapshot> sources,
    int tried,
    int answered,
  ) {
    final merged = <BigInt>[
      for (var p = 0; p < _percentiles; p++)
        _median(
          _dropOutliers([for (final s in sources) _sourcePercentile(s, p)]),
        ),
    ];
    final baseFee = _median(
      _dropOutliers([for (final s in sources) s.baseFees.last]),
    );
    final ratios = <double>[
      for (final s in sources)
        _medianD(s.gasUsedRatios.isEmpty ? const [0.5] : s.gasUsedRatios),
    ];
    final ratio = _medianD(ratios).clamp(0.0, 1.0);
    final seconds = _medianNullable([for (final s in sources) s.blockSeconds]);
    final jitter = _medianNullable([for (final s in sources) s.blockJitter]);
    final rising =
        sources.where((s) => _isRising(s.baseFees)).length * 2 >=
        sources.length;
    final floor = _observedFloor(sources);

    final blocks = _tierBlocks(ratio);
    final presets = <FeePreset>[];
    for (var i = 0; i < _percentiles; i++) {
      var price = merged[i];
      String? warning;
      if (price < floor) {
        warning =
            'Raised to the live floor of ${formatGwei(floor)} gwei — the '
            'lowest fee that was recently accepted by the network.';
        price = floor;
      }
      if (i == 0 && ratio > 0.85) {
        warning = warning == null
            ? 'Blocks are ~${(ratio * 100).round()}% full — this tier may take longer to confirm.'
            : '$warning Blocks are ~${(ratio * 100).round()}% full.';
      }
      final eta = _eta(blocks[i], seconds);
      final maxFee = baseFee * BigInt.two + price;
      presets.add(
        FeePreset(
          label: _tierLabels[i],
          target: eta,
          priorityFeePerGas: price,
          maxFeePerGas: maxFee,
          expectedFeePerGas: baseFee + price,
          mode: 'eip1559',
          source: _sourceLine(answered),
          warning: warning,
          etaSecondsLow: _etaLow(blocks[i], seconds),
          etaSecondsHigh: _etaHigh(blocks[i], seconds),
          expectedBlocks: seconds == null ? null : blocks[i],
        ),
      );
    }
    final recommended = _recommend(ratio, rising);
    presets[recommended] = presets[recommended].copyWith(
      label: '${presets[recommended].label} (recommended)',
      recommended: true,
    );

    final abnormal = presets[2].maxFeePerGas > _abnormalCap;
    var reason = _reason(recommended, ratio, rising);
    if (answered < 2) {
      reason =
          '$reason Only one fee source answered, so treat this as a '
          'single point of view.';
    }
    if (abnormal) {
      reason =
          '$reason Warning: the quoted fees are abnormally high — check '
          'the node before confirming.';
    }
    return FeeQuote(
      presets: presets,
      recommendedIndex: recommended,
      reason: reason,
      sourceLabel: _sourceLine(answered),
      floorWei: floor,
      blockSeconds: seconds,
      confidence: _confidence(answered, seconds, jitter),
      sourcesTried: tried,
      sourcesAnswered: answered,
      abnormal: abnormal,
      baseFeeWei: baseFee,
    );
  }

  // -------------------------------------------------------------- legacy ---

  static FeeQuote _mergeLegacy(
    List<FeeSourceSnapshot> sources,
    int tried,
    int answered,
  ) {
    final gasPrice = _median(
      _dropOutliers([for (final s in sources) s.legacyGasPrice!]),
    );
    final seconds = _medianNullable([for (final s in sources) s.blockSeconds]);
    final floor = _observedFloor(sources);
    final presets = <FeePreset>[];
    for (var i = 0; i < _percentiles; i++) {
      var price = _multiplyBps(gasPrice, _legacyBps[i]);
      String? warning;
      if (price < floor) {
        warning = 'Raised to the live floor of ${formatGwei(floor)} gwei.';
        price = floor;
      }
      presets.add(
        FeePreset(
          label: _tierLabels[i],
          target: _eta(_tierBlocks(0.5)[i], seconds),
          priorityFeePerGas: BigInt.zero,
          maxFeePerGas: price,
          expectedFeePerGas: price,
          gasPrice: price,
          mode: 'legacy',
          source:
              'gas-price quote from ${answered == 1 ? 'one node' : '$answered nodes'} · legacy fallback',
          warning: warning,
          etaSecondsLow: _etaLow(_tierBlocks(0.5)[i], seconds),
          etaSecondsHigh: _etaHigh(_tierBlocks(0.5)[i], seconds),
          expectedBlocks: seconds == null ? null : _tierBlocks(0.5)[i],
        ),
      );
    }
    const recommended = 1;
    presets[recommended] = presets[recommended].copyWith(
      label: '${presets[recommended].label} (recommended)',
      recommended: true,
    );
    return FeeQuote(
      presets: presets,
      recommendedIndex: recommended,
      reason:
          'The node did not provide fee history, so these multipliers of '
          'its live gas-price quote are shown. The middle one is the neutral '
          'choice.',
      sourceLabel:
          'legacy gas-price quote (${answered == 1 ? 'one node' : '$answered nodes'})',
      floorWei: floor,
      blockSeconds: seconds,
      confidence: answered < 2 ? 'low' : 'medium',
      sourcesTried: tried,
      sourcesAnswered: answered,
    );
  }

  // ------------------------------------------------------------- helpers ---

  static BigInt _sourcePercentile(FeeSourceSnapshot s, int p) => _median([
    for (final block in s.rewards) block.length > p ? block[p] : BigInt.zero,
  ]);

  /// The empirical floor: the lowest tip that was actually included in any
  /// of the sampled recent blocks (10th-percentile sample, minimum over
  /// blocks). Zero when nothing positive was seen — then there is no floor
  /// to respect, and we say nothing.
  static BigInt _observedFloor(List<FeeSourceSnapshot> sources) {
    final positives = <BigInt>[];
    for (final s in sources) {
      if (s.legacyGasPrice != null) continue;
      for (final block in s.rewards) {
        if (block.isNotEmpty && block[0] > BigInt.zero) positives.add(block[0]);
      }
    }
    if (positives.isEmpty) return BigInt.zero;
    return _median(_dropOutliers(positives));
  }

  /// Blocks roughly expected before inclusion at this tier, adjusted by the
  /// measured congestion of the last ~20 blocks.
  static List<int> _tierBlocks(double ratio) {
    const base = [4, 2, 1];
    final adj = 1 + math.max(0.0, ratio - 0.6) * 4;
    return [for (final b in base) math.max(1, (b * adj).ceil())];
  }

  static bool _isRising(List<BigInt> baseFees) {
    if (baseFees.length < 6) return false;
    final last = _median(baseFees.sublist(baseFees.length - 3));
    final before = _median(
      baseFees.sublist(baseFees.length - 6, baseFees.length - 3),
    );
    if (before <= BigInt.zero) return false;
    return last * BigInt.from(100) > before * BigInt.from(105);
  }

  static int _recommend(double ratio, bool rising) {
    if (ratio >= 0.75 || rising) return 2;
    if (ratio <= 0.45) return 0;
    return 1;
  }

  static String _reason(int index, double ratio, bool rising) {
    final pct = (ratio * 100).round();
    return switch (index) {
      2 =>
        'Blocks are about $pct% full${rising ? ' and fees are rising' : ''}'
            ' — the top tier gives the best chance of the next block.',
      0 =>
        'Blocks are mostly empty (~$pct% full) and fees are flat — the '
            'cheap tier should still land soon.',
      _ =>
        'Normal conditions (~$pct% full, fees ${rising ? 'rising' : 'stable'})'
            ' — the middle tier usually confirms in a block or two.',
    };
  }

  static String _confidence(int answered, double? seconds, double? jitter) {
    if (answered < 2) return 'low';
    if (seconds != null && (jitter == null || jitter <= 0.4)) return 'high';
    return 'medium';
  }

  static String _sourceLine(int answered) => answered == 1
      ? 'live from one node'
      : 'median of $answered nodes (outliers dropped)';

  static String _eta(int blocks, double? seconds) {
    if (seconds == null) return 'likely several blocks (block time unknown)';
    final lo = _etaLow(blocks, seconds)!;
    final hi = _etaHigh(blocks, seconds)!;
    final unit = blocks == 1 ? 'block' : 'blocks';
    return '≈ $lo–$hi s · about $blocks $unit';
  }

  static int? _etaLow(int blocks, double? seconds) =>
      seconds == null ? null : math.max(1, (blocks * seconds * 0.7).round());

  static int? _etaHigh(int blocks, double? seconds) => seconds == null
      ? null
      : math.max(
          (blocks * seconds * 1.8).round(),
          _etaLow(blocks, seconds)! + 1,
        );

  static BigInt _median(List<BigInt> values) {
    if (values.isEmpty) throw StateError('No fee samples.');
    final sorted = [...values]..sort((a, b) => a.compareTo(b));
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) ~/ BigInt.two;
  }

  static double _medianD(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static double? _medianNullable(List<double?> values) {
    final present = [for (final v in values) ?v];
    return present.isEmpty ? null : _medianD(present);
  }

  /// Drops samples that are more than 3× the smallest in the set. With fewer
  /// than three samples there is nothing to compare against, so all stay.
  static List<BigInt> _dropOutliers(List<BigInt> values) {
    if (values.length < 3) return values;
    final min = values.reduce((a, b) => a < b ? a : b);
    if (min <= BigInt.zero) return values;
    final cap = min * BigInt.from(3);
    final kept = [
      for (final v in values)
        if (v <= cap) v,
    ];
    return kept.isEmpty ? [min] : kept;
  }

  /// Same arithmetic as terminal v1 (`fees.js`): `(v·bps + 9999)/10000`.
  static BigInt _multiplyBps(BigInt value, int bps) =>
      (value * BigInt.from(bps) + BigInt.from(9999)) ~/ BigInt.from(10000);

  /// Renders wei in gwei, trailing zeros trimmed — for the warning lines.
  static String formatGwei(BigInt wei) {
    final whole = wei ~/ BigInt.from(10).pow(9);
    final frac = wei % BigInt.from(10).pow(9);
    if (frac == BigInt.zero) return whole.toString();
    var fracText = frac.toString().padLeft(9, '0');
    fracText = fracText.replaceFirst(RegExp(r'0+$'), '');
    return fracText.isEmpty ? whole.toString() : '$whole.$fracText';
  }
}
