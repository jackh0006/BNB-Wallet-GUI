import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:bnb_wallet_gui/backup_quiz.dart';

void main() {
  group('Backup quiz (spec §2)', () {
    const words = [
      'alpha',
      'bravo',
      'charlie',
      'delta',
      'echo',
      'foxtrot',
      'golf',
      'hotel',
      'india',
      'juliet',
      'kilo',
      'lima',
    ];

    test('picks the requested number of distinct, sorted positions', () {
      final positions = BackupQuiz.pickPositions(
        wordCount: 12,
        random: Random(7),
      );
      expect(positions, hasLength(3));
      expect(positions.toSet(), hasLength(3));
      expect(positions, orderedEquals([...positions]..sort()));
      expect(positions.every((p) => p >= 0 && p < 12), isTrue);
    });

    test('a short phrase just asks every word', () {
      expect(BackupQuiz.pickPositions(wordCount: 2, random: Random(1)), [0, 1]);
    });

    test('accepts correct answers regardless of case and padding', () {
      expect(
        BackupQuiz.answersMatch(
          words: words,
          answers: {1: ' BRAVO ', 5: 'Foxtrot', 11: 'LIMA'},
        ),
        isTrue,
      );
    });

    test('a single wrong or missing word fails the whole check', () {
      expect(
        BackupQuiz.answersMatch(
          words: words,
          answers: {1: 'bravo', 5: 'wrong', 11: 'lima'},
        ),
        isFalse,
      );
      expect(
        BackupQuiz.answersMatch(words: words, answers: {1: 'bravo', 5: ''}),
        isFalse,
      );
      expect(BackupQuiz.answersMatch(words: words, answers: const {}), isFalse);
    });

    test('an out-of-range position can never pass', () {
      expect(
        BackupQuiz.answersMatch(words: words, answers: {99: 'anything'}),
        isFalse,
      );
    });
  });
}
