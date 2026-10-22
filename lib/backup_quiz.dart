import 'dart:math';

/// Pure backup-check logic (spec §2): the user re-types a few randomly chosen
/// words, so "I stored it" is never enough on its own. Kept separate from the
/// dialog so the selection and comparison can be tested without a widget.
class BackupQuiz {
  BackupQuiz._();

  /// Picks [count] distinct word positions, sorted so the dialog reads in
  /// phrase order. Uses [Random.secure] unless a test supplies a seeded one.
  static List<int> pickPositions({
    required int wordCount,
    int count = 3,
    Random? random,
  }) {
    if (wordCount <= 0) return const [];
    final wanted = count < wordCount ? count : wordCount;
    final indices = List<int>.generate(wordCount, (index) => index)
      ..shuffle(random ?? Random.secure());
    return (indices.take(wanted).toList()..sort());
  }

  /// True only when every requested position matches (case/space-insensitive).
  /// An empty answer or an out-of-range position never passes.
  static bool answersMatch({
    required List<String> words,
    required Map<int, String> answers,
  }) {
    if (answers.isEmpty) return false;
    for (final entry in answers.entries) {
      if (entry.key < 0 || entry.key >= words.length) return false;
      final expected = words[entry.key].trim().toLowerCase();
      final given = entry.value.trim().toLowerCase();
      if (expected.isEmpty || given != expected) return false;
    }
    return true;
  }
}
