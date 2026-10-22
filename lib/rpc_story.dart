/// One plain-language line in the RPC "connection story" — how the wallet's
/// chat with the blockchain went, told like a story anyone can follow.
///
/// The log NEVER contains keys, phrases, or full addresses, and it lives
/// only in memory (withdrawn on lock/exit), never on disk.
enum RpcStoryKind { ok, fail, wait, info }

class RpcStoryLine {
  RpcStoryLine(
    this.text, {
    this.kind = RpcStoryKind.info,
    this.detail,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final DateTime at;
  final String text;
  final String? detail;
  final RpcStoryKind kind;

  /// HH:mm:ss stamp for display.
  String get clock =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';
}

/// Renders one story line for a small child: symbol first, then the story.
///
/// Symbols: ✅ worked · ❌ did not work · ⏳ waiting · 💬 information.
String storyTextToString(RpcStoryLine line) {
  final symbol = switch (line.kind) {
    RpcStoryKind.ok => '✅',
    RpcStoryKind.fail => '❌',
    RpcStoryKind.wait => '⏳',
    RpcStoryKind.info => '💬',
  };
  final detail = line.detail == null ? '' : ' — ${line.detail}';
  return '${line.clock}  $symbol  ${line.text}$detail';
}
