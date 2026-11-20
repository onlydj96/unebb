import 'package:flutter_test/flutter_test.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/services/memory_service.dart';

// Helper to build a minimal MemoryState for testing.
MemoryState _state({
  int repetitions = 0,
  int interval = 1,
  double ef = 2.5,
  double strength = 0.0,
  int reviewCount = 0,
  DateTime? nextReviewAt,
}) {
  final now = DateTime.now().toUtc();
  return MemoryState(
    id: 'test-id',
    userId: 'user-id',
    vocabularyId: 'vocab-id',
    stage: 4,
    memoryStrength: strength,
    recallProbability: strength,
    nextReviewAt: nextReviewAt ?? now,
    reviewCount: reviewCount,
    correctCount: 0,
    incorrectCount: 0,
    consecutiveCorrect: 0,
    easeFactor: ef,
    sm2Interval: interval,
    sm2Repetitions: repetitions,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late MemoryService sut;

  setUp(() => sut = const MemoryService());

  // ---------------------------------------------------------------------------
  // isCorrectAnswer
  // ---------------------------------------------------------------------------
  group('isCorrectAnswer', () {
    test('returns true at threshold (0.6)', () {
      expect(sut.isCorrectAnswer(0.6), isTrue);
    });

    test('returns true above threshold', () {
      expect(sut.isCorrectAnswer(0.9), isTrue);
      expect(sut.isCorrectAnswer(1.0), isTrue);
    });

    test('returns false below threshold', () {
      expect(sut.isCorrectAnswer(0.59), isFalse);
      expect(sut.isCorrectAnswer(0.0), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // gradeFromScore
  // ---------------------------------------------------------------------------
  group('gradeFromScore', () {
    test('score >= 0.90 → grade 5', () {
      expect(sut.gradeFromScore(0.90), 5);
      expect(sut.gradeFromScore(1.0), 5);
    });

    test('score >= 0.75 and < 0.90 → grade 4', () {
      expect(sut.gradeFromScore(0.75), 4);
      expect(sut.gradeFromScore(0.89), 4);
    });

    test('score >= 0.60 and < 0.75 → grade 3', () {
      expect(sut.gradeFromScore(0.60), 3);
      expect(sut.gradeFromScore(0.74), 3);
    });

    test('score < 0.60 → grade 1', () {
      expect(sut.gradeFromScore(0.59), 1);
      expect(sut.gradeFromScore(0.0), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // stageFromStrength
  // ---------------------------------------------------------------------------
  group('stageFromStrength', () {
    test('Stage 1 at 0.80', () => expect(sut.stageFromStrength(0.80), 1));
    test('Stage 1 at 1.0', () => expect(sut.stageFromStrength(1.0), 1));
    test('Stage 2 at 0.60', () => expect(sut.stageFromStrength(0.60), 2));
    test('Stage 2 at 0.79', () => expect(sut.stageFromStrength(0.79), 2));
    test('Stage 3 at 0.30', () => expect(sut.stageFromStrength(0.30), 3));
    test('Stage 3 at 0.59', () => expect(sut.stageFromStrength(0.59), 3));
    test('Stage 4 at 0.29', () => expect(sut.stageFromStrength(0.29), 4));
    test('Stage 4 at 0.0', () => expect(sut.stageFromStrength(0.0), 4));
  });

  // ---------------------------------------------------------------------------
  // calculateNextReview (legacy)
  // ---------------------------------------------------------------------------
  group('calculateNextReview', () {
    test('Stage 1 → 7 days', () {
      final next = sut.calculateNextReview(1);
      final diff = next.difference(DateTime.now().toUtc());
      expect(diff.inHours, closeTo(7 * 24, 1));
    });

    test('Stage 2 → 3 days', () {
      final next = sut.calculateNextReview(2);
      final diff = next.difference(DateTime.now().toUtc());
      expect(diff.inHours, closeTo(3 * 24, 1));
    });

    test('Stage 3 → 1 day', () {
      final next = sut.calculateNextReview(3);
      final diff = next.difference(DateTime.now().toUtc());
      expect(diff.inHours, closeTo(24, 1));
    });

    test('Stage 4 → 10 minutes', () {
      final next = sut.calculateNextReview(4);
      final diff = next.difference(DateTime.now().toUtc());
      expect(diff.inMinutes, closeTo(10, 1));
    });
  });

  // ---------------------------------------------------------------------------
  // applySmTwo — SM-2 algorithm
  // ---------------------------------------------------------------------------
  group('applySmTwo', () {
    // -- Interval progression -------------------------------------------------
    test('first correct → interval=1, repetitions=1', () {
      final result = sut.applySmTwo(_state(repetitions: 0), 0.8);
      expect(result.sm2Repetitions, 1);
      expect(result.sm2Interval, 1);
    });

    test('second correct → interval=6, repetitions=2', () {
      final result = sut.applySmTwo(_state(repetitions: 1, interval: 1), 0.8);
      expect(result.sm2Repetitions, 2);
      expect(result.sm2Interval, 6);
    });

    test('third correct → interval = round(prev * EF)', () {
      final result = sut.applySmTwo(
        _state(repetitions: 2, interval: 6, ef: 2.5),
        0.8,
      );
      expect(result.sm2Interval, (6 * 2.5).round());
      expect(result.sm2Repetitions, 3);
    });

    // -- Failure resets -------------------------------------------------------
    test('incorrect answer resets repetitions to 0 and interval to 1', () {
      final result = sut.applySmTwo(
        _state(repetitions: 3, interval: 15, ef: 2.5),
        0.3, // score < 0.6 → grade 1
      );
      expect(result.sm2Repetitions, 0);
      expect(result.sm2Interval, 1);
    });

    // -- Ease factor ----------------------------------------------------------
    test('perfect score (1.0) increases ease factor', () {
      final before = _state(ef: 2.5);
      final result = sut.applySmTwo(before, 1.0);
      expect(result.easeFactor, greaterThan(2.5));
    });

    test('low-pass score (0.6) slightly decreases ease factor', () {
      final before = _state(ef: 2.5);
      final result = sut.applySmTwo(before, 0.6);
      expect(result.easeFactor, lessThan(2.5));
    });

    test('ease factor never goes below 1.3', () {
      var state = _state(ef: 1.3);
      // Apply several fails
      for (int i = 0; i < 5; i++) {
        state = sut.applySmTwo(state, 0.0);
      }
      expect(state.easeFactor, greaterThanOrEqualTo(1.3));
    });

    // -- Strength & next review -----------------------------------------------
    test('correct answer increases memory strength', () {
      // repetitions=2, interval=6 → after correct: interval=round(6*2.5)=15
      final result = sut.applySmTwo(
        _state(repetitions: 2, interval: 6, strength: 0.61),
        0.8,
      );
      expect(result.memoryStrength, greaterThan(0.61));
    });

    test('incorrect answer resets the streak so strength drops to critical',
        () {
      final result = sut.applySmTwo(
        _state(repetitions: 3, interval: 30, strength: 0.9),
        0.3,
      );
      expect(result.memoryStrength, 0.0);
      expect(result.stage, 4);
    });

    test('each on-schedule recall moves a new word up one label', () {
      // Perfect answers from a fresh word, each on its due date:
      // critical → weak → good → good → strong.
      var now = DateTime.utc(2026, 1, 1);
      var state = _state(nextReviewAt: now);
      final stages = <int>[];
      for (var i = 0; i < 4; i++) {
        state = sut.applySmTwo(state, 1.0, now: now);
        stages.add(state.stage);
        now = state.nextReviewAt;
      }
      expect(stages, [3, 2, 2, 1]);
    });

    test('the lowest passing grade still leaves critical on the first recall',
        () {
      final result = sut.applySmTwo(_state(), 0.6);
      expect(result.stage, 3);
    });

    test('strength always in [0.0, 1.0]', () {
      final veryHighInterval = sut.applySmTwo(
        _state(repetitions: 10, interval: 200, ef: 2.5),
        1.0,
      );
      expect(veryHighInterval.memoryStrength, lessThanOrEqualTo(1.0));

      final fail = sut.applySmTwo(_state(strength: 0.0), 0.0);
      expect(fail.memoryStrength, greaterThanOrEqualTo(0.0));
    });

    test('next review is scheduled in the future', () {
      final result = sut.applySmTwo(_state(), 0.8);
      expect(result.nextReviewAt.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('next review is the interval after [now]', () {
      final now = DateTime.utc(2026, 11, 20, 9);
      final result = sut.applySmTwo(
        _state(repetitions: 1, nextReviewAt: now),
        0.8,
        now: now,
      );
      expect(result.lastReviewedAt, now);
      expect(result.nextReviewAt, now.add(const Duration(days: 6)));
    });

    // -- Early review (before the due date) -----------------------------------
    group('before the due date', () {
      final now = DateTime.utc(2026, 11, 20, 9);
      final notDue = _state(
        repetitions: 2,
        interval: 6,
        reviewCount: 2,
        nextReviewAt: now.add(const Duration(days: 3)),
      );

      test('a correct answer leaves the schedule unchanged', () {
        final result = sut.applySmTwo(notDue, 1.0, now: now);
        expect(result.sm2Interval, 6);
        expect(result.sm2Repetitions, 2);
        expect(result.easeFactor, 2.5);
        expect(result.nextReviewAt, notDue.nextReviewAt);
      });

      test('a correct answer is still counted', () {
        final result = sut.applySmTwo(notDue, 1.0, now: now);
        expect(result.reviewCount, 3);
        expect(result.correctCount, 1);
        expect(result.lastReviewedAt, now);
      });

      test('a wrong answer still resets the word', () {
        final result = sut.applySmTwo(notDue, 0.2, now: now);
        expect(result.sm2Interval, 1);
        expect(result.sm2Repetitions, 0);
        expect(result.incorrectCount, 1);
      });

      test('repeated same-day sessions cannot make a word strong', () {
        var state = _state(nextReviewAt: now);
        for (var i = 0; i < 10; i++) {
          state = sut.applySmTwo(state, 1.0, now: now);
        }
        expect(state.sm2Interval, 1);
        // Still the first-recall label: weak.
        expect(sut.stageFromStrength(sut.currentStrength(state, now)), 3);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // strengthFor
  // ---------------------------------------------------------------------------
  group('strengthFor', () {
    double s(int repetitions, int interval) =>
        sut.strengthFor(repetitions: repetitions, intervalDays: interval);

    test('no streak → 0.0 whatever the interval', () {
      expect(s(0, 1), 0.0);
      expect(s(0, 30), 0.0);
    });

    test('first recall (1 day) → exactly 0.30, weak', () {
      expect(s(1, 1), 0.30);
      expect(sut.stageFromStrength(s(1, 1)), 3);
    });

    test('second recall (6 days) → good', () {
      expect(s(2, 6), closeTo(0.606, 0.001));
      expect(sut.stageFromStrength(s(2, 6)), 2);
    });

    test('interval 60 → 1.0, longer intervals capped', () {
      expect(s(5, 60), closeTo(1.0, 0.001));
      expect(s(6, 200), 1.0);
    });

    test('grows with the interval', () {
      expect(s(3, 15), greaterThan(s(2, 6)));
      expect(s(4, 40), greaterThan(s(3, 15)));
    });

    test('a zero interval with a streak is treated as one day', () {
      expect(s(1, 0), 0.30);
    });
  });

  // ---------------------------------------------------------------------------
  // currentStrength
  // ---------------------------------------------------------------------------
  group('currentStrength', () {
    final now = DateTime.utc(2026, 11, 20, 9);

    test('0 for a word never reviewed', () {
      expect(sut.currentStrength(_state(nextReviewAt: now), now), 0.0);
    });

    test('0 right after a miss', () {
      final missed = sut.applySmTwo(
        _state(repetitions: 3, interval: 30, nextReviewAt: now),
        0.0,
        now: now,
      );
      expect(sut.currentStrength(missed, now), 0.0);
    });

    test('the scheduled strength until the word is due', () {
      final state = _state(
        repetitions: 3,
        interval: 30,
        nextReviewAt: now.add(const Duration(days: 1)),
      );
      expect(
        sut.currentStrength(state, now),
        sut.strengthFor(repetitions: 3, intervalDays: 30),
      );
    });

    test('decays once overdue: ×0.9 per interval', () {
      final state = _state(repetitions: 3, interval: 30, nextReviewAt: now);
      final scheduled = sut.strengthFor(repetitions: 3, intervalDays: 30);
      expect(
        sut.currentStrength(state, now.add(const Duration(days: 30))),
        closeTo(scheduled * 0.9, 1e-9),
      );
      expect(
        sut.currentStrength(state, now.add(const Duration(days: 300))),
        closeTo(scheduled * 0.3487, 1e-4),
      );
    });

    test('a long-neglected strong word is no longer strong', () {
      final state = _state(repetitions: 5, interval: 45, nextReviewAt: now);
      expect(sut.stageFromStrength(sut.currentStrength(state, now)), 1);
      final later = now.add(const Duration(days: 200));
      expect(
        sut.stageFromStrength(sut.currentStrength(state, later)),
        greaterThan(1),
      );
    });
  });
}
