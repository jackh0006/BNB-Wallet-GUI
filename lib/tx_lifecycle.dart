import 'package:flutter/foundation.dart';

import 'rpc_story.dart';

/// Lifecycle of one outgoing transaction, as plain words the UI can show.
/// The order here is the order of the journey strip.
enum TxStage {
  prepared,
  simulated,
  signed,
  broadcast,
  pending,
  included,
  finalized,
  failed,
}

extension TxStageText on TxStage {
  String get label => switch (this) {
    TxStage.prepared => 'Prepared',
    TxStage.simulated => 'Simulated',
    TxStage.signed => 'Signed here',
    TxStage.broadcast => 'Sent to node',
    TxStage.pending => 'In line',
    TxStage.included => 'In a block',
    TxStage.finalized => 'Final',
    TxStage.failed => 'Stopped',
  };

  String get detail => switch (this) {
    TxStage.prepared => 'Your entries, checked before anything moves.',
    TxStage.simulated => 'The chain itself rehearsed the exact transfer.',
    TxStage.signed => 'Signed on this device — the key never left it.',
    TxStage.broadcast => 'The raw public transaction went to the network.',
    TxStage.pending => 'Miners can include it at any moment now.',
    TxStage.included => 'It is inside a block. Waiting for finality.',
    TxStage.finalized =>
      'Buried deep enough that reordering is no longer possible.',
    TxStage.failed => 'Nothing was signed or sent unless stated below.',
  };
}

/// The visible journey strip during a send (failed is an off-strip state).
const List<TxStage> sendJourney = [
  TxStage.prepared,
  TxStage.simulated,
  TxStage.signed,
  TxStage.broadcast,
  TxStage.pending,
  TxStage.included,
  TxStage.finalized,
];

/// -1 when [stage] is not one of the journey stops (failed).
int journeyIndexOf(TxStage stage) => sendJourney.indexOf(stage);

/// Every event a send can emit, mapped to its plain-words story line.
/// The switch is exhaustive on purpose: adding an event without words is a
/// compile error, and a test walks all values so none can go unmapped.
enum SendEvent {
  prepared,
  simulated,
  feePicked,
  refused,
  signed,
  broadcast,
  acceptedKnown,
  pending,
  included,
  finalized,
  reverted,
  unknownOutcome,
  failed,
  replaced,
  cancelled,
}

@immutable
class SendEventNote {
  const SendEventNote(this.text, {this.kind = RpcStoryKind.info});
  final String text;
  final RpcStoryKind kind;
}

SendEventNote sendEventNote(SendEvent event) => switch (event) {
  SendEvent.prepared => const SendEventNote(
    'I checked the recipient and amount before anything else.',
  ),
  SendEvent.simulated => const SendEventNote(
    'I rehearsed this exact transfer on the chain: it is what you will see — no surprise gas, no revert waiting for you.',
  ),
  SendEvent.feePicked => const SendEventNote(
    'You picked the network fee tier from live data; the maximum it can ever reserve is shown on the review.',
  ),
  SendEvent.refused => const SendEventNote(
    'I stopped before signing — nothing left this device.',
    kind: RpcStoryKind.fail,
  ),
  SendEvent.signed => const SendEventNote(
    'You confirmed every character. I signed locally — your key never leaves this device.',
  ),
  SendEvent.broadcast => const SendEventNote(
    'The raw public transaction went to the node. The network decides the rest.',
  ),
  SendEvent.acceptedKnown => const SendEventNote(
    'The node already knew this exact signed transaction — it was in the network before the answer came back. Nothing is duplicated.',
    kind: RpcStoryKind.ok,
  ),
  SendEvent.pending => const SendEventNote(
    'Waiting for a miner to include it. Nothing to do on your side.',
    kind: RpcStoryKind.wait,
  ),
  SendEvent.included => const SendEventNote(
    'It is inside a block now. Waiting for finality means waiting for the chain to bury it deep.',
    kind: RpcStoryKind.ok,
  ),
  SendEvent.finalized => const SendEventNote(
    'Final: the chain buried it deep enough that reordering is no longer possible.',
    kind: RpcStoryKind.ok,
  ),
  SendEvent.reverted => const SendEventNote(
    'It was mined but the contract refused it — only the gas was spent. The receipt shows why.',
    kind: RpcStoryKind.fail,
  ),
  SendEvent.unknownOutcome => const SendEventNote(
    'The broadcast answer never came back. It may still have reached the chain — do NOT resend blindly.',
    kind: RpcStoryKind.fail,
  ),
  SendEvent.failed => const SendEventNote(
    'That attempt failed. Nothing more was sent.',
    kind: RpcStoryKind.fail,
  ),
  SendEvent.replaced => const SendEventNote(
    'A replacement with the same nonce is now in the network. Only one of the two can confirm.',
    kind: RpcStoryKind.wait,
  ),
  SendEvent.cancelled => const SendEventNote(
    'A cancel transaction is in the network with the same nonce. If it confirms first, the original cannot.',
    kind: RpcStoryKind.wait,
  ),
};

/// Replacement fee bump: go-ethereum requires ≥10% to replace; 12.5% gives
/// headroom and is rounded UP so repeated bumps never stall.
BigInt bumpFee(BigInt wei) =>
    (wei * BigInt.from(1125) + BigInt.from(999)) ~/ BigInt.from(1000);

// ------------------------------------------------------------ revert text ---

/// Turns an RPC error into the contract's own words when it carries a revert
/// reason, and into honest plain words when it does not. Never invents a
/// reason: unknown data is shown as hex, labelled as undecoded.
String decodeRevertReason(Object error) {
  final raw = error.toString();
  final text = raw
      .replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '')
      .trim();

  // "execution reverted: <text>"
  final colon = RegExp(
    r'execution reverted[^:]*:\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (colon != null) {
    final tail = colon.group(1)!.trim();
    final decoded = _decodeAbiString(tail);
    return decoded ?? tail;
  }
  // bare "execution reverted" possibly followed by hex data
  final hex = RegExp(r'0x08c379a0[0-9a-fA-F]*').firstMatch(text);
  if (hex != null) {
    final decoded = _decodeAbiString(hex.group(0)!);
    if (decoded != null) return decoded;
  }
  final anyHex = RegExp(r'0x[0-9a-fA-F]{8,}').firstMatch(text);
  if (anyHex != null && text.toLowerCase().contains('revert')) {
    return 'the contract refused with undecoded data (${anyHex.group(0)!.length > 74 ? '${anyHex.group(0)!.substring(0, 74)}…' : anyHex.group(0)!}). Assume it is not safe to send and verify on the explorer first';
  }
  if (text.toLowerCase().contains('execution reverted')) {
    return 'the contract refused the transfer (no reason given)';
  }
  if (text.toLowerCase().contains('insufficient funds')) {
    return 'the account cannot cover this transaction with its current BNB balance';
  }
  return text;
}

/// `0x08c379a0` + ABI string (offset/len/bytes). Returns null when the shape
/// does not match — the caller then falls back to showing what it has.
String? _decodeAbiString(String hexText) {
  final hex = hexText.replaceFirst('0x', '');
  if (!hex.startsWith('08c379a0') || hex.length < 8 + 64 + 64) return null;
  final len = int.tryParse(hex.substring(8 + 64, 8 + 128), radix: 16);
  if (len == null || len <= 0) return null;
  final dataStart = 8 + 128;
  final charCount = len * 2;
  if (hex.length < dataStart + charCount) return null;
  final bytes = <int>[];
  for (var i = 0; i < charCount; i += 2) {
    final byte = int.tryParse(
      hex.substring(dataStart + i, dataStart + i + 2),
      radix: 16,
    );
    if (byte == null) return null;
    bytes.add(byte);
  }
  try {
    final text = String.fromCharCodes(bytes).replaceAll('\u0000', '').trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

// --------------------------------------------------------- broadcast reads ---

enum BroadcastVerdict {
  acceptedKnown,
  nonceTooLow,
  underpriced,
  replacementUnderpriced,
  insufficientFunds,
  intrinsicGas,
  unknownOutcome,
  failed,
}

@immutable
class BroadcastReading {
  const BroadcastReading(this.verdict, this.plainWords);
  final BroadcastVerdict verdict;
  final String plainWords;
}

BroadcastReading readBroadcastError(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('already known') ||
      lower.contains('known transaction') ||
      lower.contains('already exists') ||
      lower.contains('transaction already in the pool')) {
    return const BroadcastReading(
      BroadcastVerdict.acceptedKnown,
      'The node already knows this signed transaction — it is in the network. '
      'Do not resend; wait for a confirmation.',
    );
  }
  if (lower.contains('nonce too low') || lower.contains('nonce is too low')) {
    return const BroadcastReading(
      BroadcastVerdict.nonceTooLow,
      'The account nonce already moved past this transaction, so the node '
      'refused it. It was either confirmed already or replaced — check the '
      'explorer before doing anything else.',
    );
  }
  if (lower.contains('replacement transaction underpriced') ||
      lower.contains('replacement underpriced')) {
    return const BroadcastReading(
      BroadcastVerdict.replacementUnderpriced,
      'The node wants a bigger fee bump than the one offered to replace the '
      'pending transaction. Nothing was sent — try again with a larger '
      'increase.',
    );
  }
  if (lower.contains('underpriced') ||
      lower.contains('gas price below minimum') ||
      lower.contains('min gas price') ||
      lower.contains('fee too low')) {
    return const BroadcastReading(
      BroadcastVerdict.underpriced,
      'The node refused the fee as below its minimum — nothing was sent. Pick '
      'a higher fee tier and try again.',
    );
  }
  if (lower.contains('insufficient funds') ||
      lower.contains('insufficient balance')) {
    return const BroadcastReading(
      BroadcastVerdict.insufficientFunds,
      'The account cannot cover the amount plus the maximum gas cap with its '
      'current BNB balance. Nothing was sent.',
    );
  }
  if (lower.contains('intrinsic gas')) {
    return const BroadcastReading(
      BroadcastVerdict.intrinsicGas,
      'The gas limit is below the minimum the chain allows for this transfer. '
      'Nothing was sent.',
    );
  }
  if (lower.contains('timeout') ||
      lower.contains('timed out') ||
      lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('closed')) {
    return const BroadcastReading(
      BroadcastVerdict.unknownOutcome,
      'The broadcast answer never came back. The transaction may still have '
      'reached the chain — do NOT resend blindly.',
    );
  }
  return BroadcastReading(BroadcastVerdict.failed, message);
}

// --------------------------------------------------------------- evm logs ---

/// Minimal, dependency-free shape of one EVM log — keeps the decoder pure.
@immutable
class EvmLog {
  const EvmLog({
    required this.address,
    required this.topics,
    required this.data,
  });
  final String address;
  final List<String> topics;
  final String data;
}

/// keccak256("Transfer(address,address,uint256)") — a protocol constant.
const String erc20TransferTopic =
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

/// Finds the ERC-20 Transfer amount emitted to [to] from [from] by the [token]
/// contract. Returns null when no matching event exists — the caller then
/// says exactly that instead of guessing.
BigInt? findTransferAmount({
  required List<EvmLog> logs,
  required String token,
  required String from,
  required String to,
}) {
  for (final log in logs) {
    if (log.address.toLowerCase() != token.toLowerCase()) continue;
    if (log.topics.isEmpty) continue;
    if (log.topics.first.toLowerCase() != erc20TransferTopic) continue;
    if (log.topics.length < 3) continue;
    if (!topicIsAddress(log.topics[1], from)) continue;
    if (!topicIsAddress(log.topics[2], to)) continue;
    final data = log.data.replaceFirst('0x', '');
    if (data.length < 64) continue;
    final amount = BigInt.tryParse(data.substring(0, 64), radix: 16);
    if (amount != null) return amount;
  }
  return null;
}

bool topicIsAddress(String topic, String address) {
  final padded = address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
  return topic.toLowerCase() == '0x$padded';
}
