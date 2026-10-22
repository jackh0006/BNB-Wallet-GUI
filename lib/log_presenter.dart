import 'package:flutter/material.dart';

import 'encrypted_log_store.dart';

/// One log entry as the Simple view shows it: an icon, 2–4 plain words, and
/// the same severity colour as the Expert view. The Simple view is only a
/// presentation layer over the real encrypted entries — it never invents a
/// line the Expert view cannot show.
@immutable
class LogPresentation {
  const LogPresentation({
    required this.icon,
    required this.title,
    required this.color,
    required this.levelLabel,
  });

  final IconData icon;
  final String title;
  final Color color;
  final String levelLabel;
}

/// Maps every structured entry to a Simple-view card. Falls back per category
/// (never throws for an unknown category/level from an older log file), so
/// every event type has an icon and a short text.
LogPresentation presentLogEntry(Map<String, dynamic> entry) {
  final category = LogCategory.values.firstWhere(
    (c) => c.name == '${entry['category']}',
    orElse: () => LogCategory.system,
  );
  final level = LogLevel.values.firstWhere(
    (l) => l.name == '${entry['level']}',
    orElse: () => LogLevel.info,
  );
  final custom = '${entry['simple'] ?? ''}'.trim();
  return LogPresentation(
    icon: _iconFor(category),
    title: custom.isEmpty ? _titleFor(category, level) : custom,
    color: _colorFor(level),
    levelLabel: level.name.toUpperCase(),
  );
}

IconData _iconFor(LogCategory category) {
  switch (category) {
    case LogCategory.vault:
      return Icons.lock_outline;
    case LogCategory.keys:
      return Icons.key_outlined;
    case LogCategory.network:
      return Icons.cloud_outlined;
    case LogCategory.tor:
      return Icons.visibility_off_outlined;
    case LogCategory.fees:
      return Icons.speed_outlined;
    case LogCategory.tx:
      return Icons.receipt_long_outlined;
    case LogCategory.tokens:
      return Icons.toll_outlined;
    case LogCategory.security:
      return Icons.shield_outlined;
    case LogCategory.system:
      return Icons.phone_android_outlined;
  }
}

String _titleFor(LogCategory category, LogLevel level) {
  if (level == LogLevel.error) return 'Something failed';
  if (level == LogLevel.warn) return 'Needs attention';
  switch (category) {
    case LogCategory.vault:
      return 'Vault';
    case LogCategory.keys:
      return 'Key event';
    case LogCategory.network:
      return 'Node talk';
    case LogCategory.tor:
      return 'Tor';
    case LogCategory.fees:
      return 'Fee check';
    case LogCategory.tx:
      return 'Transaction';
    case LogCategory.tokens:
      return 'Tokens';
    case LogCategory.security:
      return 'Security';
    case LogCategory.system:
      return 'Wallet';
  }
}

Color _colorFor(LogLevel level) {
  switch (level) {
    case LogLevel.error:
      return const Color(0xFFFF6B6B);
    case LogLevel.warn:
      return const Color(0xFFF0B90B);
    case LogLevel.info:
      return const Color(0xFF69C77A);
    case LogLevel.debug:
      return Colors.white54;
  }
}
