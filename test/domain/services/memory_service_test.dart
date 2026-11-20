import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:unebb/domain/models/memory_reading.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/services/memory_service.dart';

const _sut = MemoryService();

/// A local time in November 2026 (learning days are local).
DateTime _at(int day, [int hour = 12, int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

/// [correctCount] and [consecutiveCorrect] default to [repetitions]: a
/// streak of on-schedule recalls.
MemoryState _state({
  int repetitions = 0,
  int interval = 1,
  double ef = 2.5,
  int reviewCount = 0,
  int? correctCount,
  int? consecutiveCorrect,
  required DateTime nextReviewAt,
}) {
  final created = DateTime.utc(2026, 10, 1);
  return MemoryState(
    id: 'test-id',
    userId: 'user-id',
    vocabularyId: 'vocab-id',
    stage: 4,
    memoryStrength: 0.0,
    recallProbability: 0.0,
    nextReviewAt: nextReviewAt.toUtc(),
    reviewCount: reviewCount,
    correctCount: correctCount ?? repetitions,
    incorrectCount: 0,
    consecutiveCorrect: consecutiveCorrect ?? repetitions,
    easeFactor: ef,
    sm2Interval: interval,
    sm2Repetitions: repetitions,
    createdAt: created,
    updatedAt: created,
  );
}

/// A word added at [at]: due at once.
MemoryState _newWord(DateTime at) => _state(nextReviewAt: at);

MemoryLevel _level(MemoryState state, DateTime now) =>
    _sut.readingOf(state, now).level;

const _goodOrStrong = [MemoryLevel.good, MemoryLevel.strong];

void main() {
  // ---------------------------------------------------------------------------
  // Grade & correctness
  // ---------------------------------------------------------------------------
  group('isCorrectAnswer', () {
    test('true from the threshold (0.6) up', () {
      expect(_sut.isCorrectAnswer(0.6), isTrue);
      expect(_sut.isCorrectAnswer(1.0), isTrue);
    });

    test('false below the threshold', () {
      expect(_sut.isCorrectAnswer(0.59), isFalse);
      expect(_sut.isCorrectAnswer(0.0), isFalse);
    });
  });

  group('gradeFromScore', () {
    test('score >= 0.90 → grade 5', () {
      expect(_sut.gradeFromScore(0.90), 5);
      expect(_sut.gradeFromScore(1.0), 5);
    });

    test('score >= 0.75 and < 0.90 → grade 4', () {
      expect(_sut.gradeFromScore(0.75), 4);
      expect(_sut.gradeFromScore(0.89), 4);
    });

    test('score >= 0.60 and < 0.75 → grade 3', () {
      expect(_sut.gradeFromScore(0.60), 3);
      expect(_sut.gradeFromScore(0.74), 3);
    });

    test('score < 0.60 → grade 1', () {
      expect(_sut.gradeFromScore(0.59), 1);
      expect(_sut.gradeFromScore(0.0), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Levels
  // ---------------------------------------------------------------------------
  group('levelForStrength', () {
    test('a lower bound belongs to the level it starts', () {
      expect(_sut.levelForStrength(1.0), MemoryLevel.strong);
      expect(_sut.levelForStrength(0.80), MemoryLevel.strong);
      expect(_sut.levelForStrength(0.7999), MemoryLevel.good);
      expect(_sut.levelForStrength(0.60), MemoryLevel.good);
      expect(_sut.levelForStrength(0.5999), MemoryLevel.weak);
      expect(_sut.levelForStrength(0.30), MemoryLevel.weak);
      expect(_sut.levelForStrength(0.2999), MemoryLevel.critical);
      expect(_sut.levelForStrength(0.0), MemoryLevel.critical);
    });

    test('stored stage: 1 = strong … 4 = critical', () {
      expect(_sut.stageFromStrength(0.9), 1);
      expect(_sut.stageFromStrength(0.7), 2);
      expect(_sut.stageFromStrength(0.4), 3);
      expect(_sut.stageFromStrength(0.1), 4);
      expect(MemoryLevel.learning.stage, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // Due dates
  // ---------------------------------------------------------------------------
  group('dueAfter', () {
    test('is the start of a later learning day', () {
      expect(_sut.dueAfter(_at(20, 21), 1), _at(21, 4).toUtc());
      expect(_sut.dueAfter(_at(20, 9), 6), _at(26, 4).toUtc());
    });

    test('a review after midnight belongs to the evening before', () {
      expect(_sut.dueAfter(_at(21, 2), 1), _at(21, 4).toUtc());
      expect(_sut.dueAfter(_at(21, 4), 1), _at(22, 4).toUtc());
    });

    test('crosses month ends', () {
      expect(_sut.dueAfter(_at(30), 1), DateTime(2026, 12, 1, 4).toUtc());
    });
  });

  // ---------------------------------------------------------------------------
  // applySmTwo
  // ---------------------------------------------------------------------------
  group('applySmTwo', () {
    group('on schedule', () {
      test('intervals grow 1 → 6 → round(6 × EF)', () {
        var now = _at(1);
        var state = _newWord(now);
        final intervals = <int>[];
        for (var i = 0; i < 3; i++) {
          state = _sut.applySmTwo(state, 0.8, now: now); // grade 4: EF stays
          intervals.add(state.sm2Interval);
          now = state.nextReviewAt.add(const Duration(hours: 8));
        }
        expect(intervals, [1, 6, 15]);
        expect(state.sm2Repetitions, 3);
        expect(state.easeFactor, 2.5);
      });

      test('the next review is due from the start of its learning day', () {
        final now = _at(20, 21);
        final result = _sut.applySmTwo(
          _state(repetitions: 1, reviewCount: 1, nextReviewAt: now),
          0.8,
          now: now,
        );
        expect(result.lastReviewedAt, now.toUtc());
        expect(result.nextReviewAt, _at(26, 4).toUtc());
      });

      test('a review earlier in the day than the last one is on time', () {
        final first =
            _sut.applySmTwo(_newWord(_at(20, 21)), 1.0, now: _at(20, 21));
        final second = _sut.applySmTwo(first, 1.0, now: _at(21, 8));
        expect(second.sm2Repetitions, 2);
        expect(second.sm2Interval, 6);
      });

      test('a perfect recall raises the ease factor, a laboured one lowers it',
          () {
        final now = _at(20);
        expect(_sut.applySmTwo(_newWord(now), 1.0, now: now).easeFactor,
            greaterThan(2.5));
        expect(_sut.applySmTwo(_newWord(now), 0.6, now: now).easeFactor,
            lessThan(2.5));
      });

      test('stores the strength and stage the learner sees right after', () {
        final now = _at(20);
        final result = _sut.applySmTwo(_newWord(now), 0.9, now: now);
        final reading = _sut.readingOf(result, now);
        expect(result.memoryStrength, reading.strength);
        expect(result.recallProbability, reading.strength);
        expect(result.stage, reading.level.stage);
      });
    });

    group('wrong answers', () {
      final now = _at(20);

      test('reset the streak; the word is due again the next day', () {
        final result = _sut.applySmTwo(
          _state(
              repetitions: 3, interval: 15, reviewCount: 3, nextReviewAt: now),
          0.3,
          now: now,
        );
        expect(result.sm2Repetitions, 0);
        expect(result.sm2Interval, 1);
        expect(result.consecutiveCorrect, 0);
        expect(result.incorrectCount, 1);
        expect(result.nextReviewAt, _at(21, 4).toUtc());
      });

      test('a lapse lowers the ease factor, never below 1.3', () {
        final lapsed = _sut.applySmTwo(
          _state(
              repetitions: 3, interval: 15, reviewCount: 3, nextReviewAt: now),
          0.0,
          now: now,
        );
        expect(lapsed.easeFactor, closeTo(1.96, 1e-9));

        final floored = _sut.applySmTwo(
          _state(
              repetitions: 2,
              interval: 6,
              ef: 1.4,
              reviewCount: 2,
              nextReviewAt: now),
          0.0,
          now: now,
        );
        expect(floored.easeFactor, 1.3);
      });

      test('missing a word not learnt yet leaves the ease factor', () {
        // "I don't know" on first sight, three days running.
        var state = _newWord(_at(1));
        for (var day = 1; day <= 3; day++) {
          state = _sut.applySmTwo(state, 0.0, now: _at(day));
        }
        expect(state.easeFactor, 2.5);
        expect(state.incorrectCount, 3);
        expect(state.correctCount, 0);
      });

      test('a wrong answer before the due day still resets the word', () {
        final result = _sut.applySmTwo(
          _state(
              repetitions: 2,
              interval: 6,
              reviewCount: 2,
              nextReviewAt: _at(23, 4)),
          0.2,
          now: now,
        );
        expect(result.sm2Repetitions, 0);
        expect(result.sm2Interval, 1);
      });
    });

    group('a correct answer after a miss', () {
      test('is the first recall, even before the word is due again', () {
        final missed =
            _sut.applySmTwo(_newWord(_at(20, 9)), 0.0, now: _at(20, 9));
        expect(_level(missed, _at(20, 9)), MemoryLevel.learning);

        final recalled = _sut.applySmTwo(missed, 0.9, now: _at(20, 18));
        expect(recalled.sm2Repetitions, 1);
        expect(recalled.sm2Interval, 1);
        expect(recalled.nextReviewAt, _at(21, 4).toUtc());
        expect(_level(recalled, _at(20, 18)), MemoryLevel.good);
      });

      test('relearns a forgotten word the same way', () {
        final lapsed = _sut.applySmTwo(
          _state(
              repetitions: 4,
              interval: 40,
              reviewCount: 4,
              nextReviewAt: _at(20, 9)),
          0.0,
          now: _at(20, 9),
        );
        expect(_level(lapsed, _at(20, 9)), MemoryLevel.critical);

        final relearnt = _sut.applySmTwo(lapsed, 0.9, now: _at(20, 18));
        expect(relearnt.sm2Repetitions, 1);
        expect(_level(relearnt, _at(20, 18)), MemoryLevel.good);
      });
    });

    group('before the due day', () {
      final now = _at(20);
      final notDue = _state(
        repetitions: 2,
        interval: 6,
        reviewCount: 2,
        nextReviewAt: _at(23, 4),
      );

      test('a correct answer leaves the schedule unchanged', () {
        final result = _sut.applySmTwo(notDue, 1.0, now: now);
        expect(result.sm2Interval, 6);
        expect(result.sm2Repetitions, 2);
        expect(result.easeFactor, 2.5);
        expect(result.nextReviewAt, notDue.nextReviewAt);
      });

      test('a correct answer is still counted', () {
        final result = _sut.applySmTwo(notDue, 1.0, now: now);
        expect(result.reviewCount, 3);
        expect(result.correctCount, 3);
        expect(result.consecutiveCorrect, 3);
        expect(result.lastReviewedAt, now.toUtc());
      });

      test('repeated same-day sessions cannot push a word past one recall', () {
        var state = _newWord(now);
        for (var i = 0; i < 10; i++) {
          state = _sut.applySmTwo(state, 1.0, now: now.add(Duration(hours: i)));
        }
        expect(state.sm2Repetitions, 1);
        expect(state.sm2Interval, 1);
        expect(state.correctCount, 10);
        expect(_level(state, _at(20, 21)), MemoryLevel.good);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // peakStrength
  // ---------------------------------------------------------------------------
  group('peakStrength', () {
    test('a first recall (1 day) is 0.70, good', () {
      expect(_sut.peakStrength(1), closeTo(0.70, 1e-9));
    });

    test('intervals under 21 days are good', () {
      for (final days in [1, 6, 15, 20]) {
        expect(_sut.levelForStrength(_sut.peakStrength(days)), MemoryLevel.good,
            reason: '$days days');
      }
    });

    test('21 days and more are strong', () {
      for (final days in [21, 45, 120, 365]) {
        expect(
            _sut.levelForStrength(_sut.peakStrength(days)), MemoryLevel.strong,
            reason: '$days days');
      }
    });

    test('grows with the interval and reaches 1.0 at a year', () {
      final values = [
        for (final days in [1, 6, 15, 20, 21, 45, 120, 365, 1000])
          _sut.peakStrength(days),
      ];
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1]));
      }
      expect(_sut.peakStrength(365), closeTo(1.0, 1e-9));
      expect(_sut.peakStrength(1000), 1.0);
    });

    test('an interval under one day counts as one day', () {
      expect(_sut.peakStrength(0), _sut.peakStrength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // readingOf / currentStrength
  // ---------------------------------------------------------------------------
  group('readingOf', () {
    final now = _at(20);

    test('a word not reviewed yet is learning', () {
      expect(_sut.readingOf(_newWord(now), now),
          const MemoryReading(MemoryLevel.learning, 0.0));
    });

    test('a word never recalled is learning, not critical', () {
      var state = _newWord(_at(10));
      for (var day = 10; day < 13; day++) {
        state = _sut.applySmTwo(state, 0.0, now: _at(day));
      }
      expect(_level(state, now), MemoryLevel.learning);
      expect(_sut.currentStrength(state, now), 0.0);
    });

    test('a recalled word that was then missed is critical', () {
      final lapsed = _sut.applySmTwo(
        _state(repetitions: 3, interval: 15, reviewCount: 3, nextReviewAt: now),
        0.2,
        now: now,
      );
      expect(_sut.readingOf(lapsed, now),
          const MemoryReading(MemoryLevel.critical, 0.0));
    });

    test('every correct answer leaves the word good or strong', () {
      final rng = Random(42);
      for (var i = 0; i < 500; i++) {
        final repetitions = rng.nextInt(7);
        final streak = repetitions == 0 ? 0 : repetitions + rng.nextInt(3);
        final state = _state(
          repetitions: repetitions,
          interval: repetitions == 0 ? 1 : 1 + rng.nextInt(400),
          ef: 1.3 + rng.nextDouble() * 1.7,
          correctCount: streak + rng.nextInt(4),
          consecutiveCorrect: streak,
          reviewCount: streak + 1 + rng.nextInt(4),
          nextReviewAt:
              now.add(Duration(hours: rng.nextInt(24 * 800) - 24 * 400)),
        );
        final score = 0.6 + rng.nextDouble() * 0.4;
        final result = _sut.applySmTwo(state, score, now: now);
        expect(_level(result, now), isIn(_goodOrStrong), reason: '$state');
      }
    });

    group('over time', () {
      // Recalled once on the 20th at 21:00: due from the 21st, 04:00.
      final recalled =
          _sut.applySmTwo(_newWord(_at(20, 21)), 0.9, now: _at(20, 21));

      test('holds until the end of the due day', () {
        for (final t in [
          _at(21, 3),
          _at(21, 4, 1), // just due: used to drop straight to critical
          _at(21, 23, 59),
          _at(22, 3, 59),
        ]) {
          expect(_sut.currentStrength(recalled, t), closeTo(0.70, 1e-9),
              reason: '$t');
        }
      });

      test('then fades: good → weak → critical', () {
        expect(_level(recalled, _at(23, 4)), MemoryLevel.good); // ×0.9
        expect(_level(recalled, _at(24, 4)), MemoryLevel.weak); // ×0.81
        expect(_level(recalled, _at(29, 4)), MemoryLevel.weak);
        expect(_level(recalled, _at(30, 12)), MemoryLevel.critical);
      });

      test('falls ×0.9 per interval past the due day', () {
        final state = _state(
            repetitions: 3, interval: 30, reviewCount: 3, nextReviewAt: _at(1));
        final peak = _sut.peakStrength(30);
        final dueDayEnd = state.nextReviewAt.add(const Duration(days: 1));
        expect(
          _sut.currentStrength(state, dueDayEnd.add(const Duration(days: 30))),
          closeTo(peak * 0.9, 1e-9),
        );
        expect(
          _sut.currentStrength(state, dueDayEnd.add(const Duration(days: 300))),
          closeTo(peak * 0.3487, 1e-4),
        );
      });

      test('a long-neglected strong word steps down one level at a time', () {
        final state = _state(
            repetitions: 5, interval: 45, reviewCount: 5, nextReviewAt: _at(1));
        final seen = <MemoryLevel>[];
        for (var day = 0; day <= 600; day += 5) {
          final level =
              _level(state, state.nextReviewAt.add(Duration(days: day)));
          if (seen.isEmpty || seen.last != level) seen.add(level);
        }
        expect(seen, [
          MemoryLevel.strong,
          MemoryLevel.good,
          MemoryLevel.weak,
          MemoryLevel.critical,
        ]);
      });

      test('a correct answer on a faded word restores it', () {
        final faded = _state(
            repetitions: 1, interval: 1, reviewCount: 1, nextReviewAt: _at(1));
        expect(_level(faded, now), MemoryLevel.critical);

        final result = _sut.applySmTwo(faded, 0.9, now: now);
        expect(result.sm2Interval, 6);
        expect(_level(result, now), MemoryLevel.good);
      });
    });

    test(
        'a learner reviewing daily at any hour never sees a recalled word '
        'below good', () {
      // Five words added on each of the first ten days; every day all due
      // words are recalled at a random time between 07:00 and 23:59.
      final rng = Random(7);
      final words = <MemoryState>[];
      for (var day = 1; day <= 30; day++) {
        if (day <= 10) {
          for (var i = 0; i < 5; i++) {
            words.add(_newWord(_at(day, 0, 30)));
          }
        }
        final at = _at(day, 7 + rng.nextInt(17), rng.nextInt(60));
        for (var i = 0; i < words.length; i++) {
          if (words[i].reviewCount > 0) {
            expect(_level(words[i], at), isIn(_goodOrStrong),
                reason: 'day $day, word $i');
          }
          if (_sut.isDue(words[i], at)) {
            words[i] = _sut.applySmTwo(words[i], 0.9, now: at);
          }
        }
      }
      // Words added on the first days have become strong.
      expect(_level(words.first, _at(30, 23)), MemoryLevel.strong);
    });
  });
}
