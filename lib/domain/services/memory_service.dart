import 'dart:math';

import 'package:unebb/domain/models/memory_reading.dart';
import 'package:unebb/domain/models/memory_state.dart';

/// Pure domain service — no Flutter, no Supabase imports.
///
/// Schedules reviews with SM-2 (SuperMemo 2) and turns a memory state into
/// what the learner sees ([readingOf]). See docs/MEMORY_MODEL.md.
///
/// Grade mapping from overallScore:
///   >= 0.90 → 5 (perfect recall)
///   >= 0.75 → 4 (correct with hesitation)
///   >= 0.60 → 3 (correct with difficulty)
///    < 0.60 → 1 (incorrect / blackout)
///
/// Scheduling ([applySmTwo]):
///   wrong                   → repetitions=0, interval=1. The ease factor
///                             drops only when a recalled word is forgotten
///                             (a lapse), not while the word is still learnt.
///   correct, still learning → repetitions=1, interval=1, whenever it
///   (repetitions=0: new, or     happens.
///   last answer wrong)
///   correct, due            → repetitions+1; interval 6 after the first
///                             recall, then round(interval × EF).
///   correct, not due yet    → counted, schedule unchanged: repeated
///                             sessions on one day cannot inflate a word.
///   EF = max(1.3, EF + (0.1 - (5-grade)(0.08 + (5-grade)×0.02)))
/// Due dates are whole learning days ([dueAfter]).
///
/// Display ([readingOf]):
///   never recalled    → learning (nothing learnt yet, so not "at risk")
///   last answer wrong → critical, strength 0
///   recalled          → [peakStrength] of the interval: 1–21 days →
///                       0.70–0.80 (good), 21 days–1 year → 0.80–1.0
///                       (strong). It holds through the due day, then
///                       falls ×0.9 per interval overdue: → weak → critical.
class MemoryService {
  const MemoryService();

  /// Recall SM-2 expects on the due date: the interval is how long it takes
  /// for recall to fall to about this level.
  static const double scheduledRecall = 0.9;

  /// Local hour at which a learning day starts, so a review shortly after
  /// midnight still belongs to the evening before.
  static const int dayStartHour = 4;

  /// Interval (days) from which a recalled word is strong — the usual
  /// "mature" threshold of spaced repetition.
  static const int matureDays = 21;

  /// Interval (days) at which strength reaches 1.0.
  static const int fullStrengthDays = 365;

  /// Strength right after a recall with a one-day interval.
  static const double firstRecallStrength = 0.70;

  // Lower bounds of the levels.
  static const double strongThreshold = 0.80;
  static const double goodThreshold = 0.60;
  static const double weakThreshold = 0.30;

  // ---------------------------------------------------------------------------
  // Grade & correctness
  // ---------------------------------------------------------------------------

  /// Maps overallScore to SM-2 grade (1 or 3–5).
  int gradeFromScore(double overallScore) {
    if (overallScore >= 0.90) return 5;
    if (overallScore >= 0.75) return 4;
    if (overallScore >= 0.60) return 3;
    return 1; // failed
  }

  /// True when overallScore meets the correctness threshold (grade >= 3).
  bool isCorrectAnswer(double overallScore) => overallScore >= 0.60;

  // ---------------------------------------------------------------------------
  // Due dates
  // ---------------------------------------------------------------------------

  /// Whether [state] is due for review at [now] (same rule as the review
  /// queue).
  bool isDue(MemoryState state, DateTime now) =>
      !state.nextReviewAt.isAfter(now);

  /// Whether a review of the due words (`'due'` mode, the due count) takes
  /// [state] at [now]: its due day has come, or it is not recalled yet —
  /// new, still being learnt, or just missed. Those wait for nothing, so a
  /// word missed in the morning comes back in the next session, not only
  /// tomorrow. The schedule itself is unchanged ([isDue]).
  bool isUpForReview(MemoryState state, DateTime now) =>
      state.consecutiveCorrect == 0 || isDue(state, now);

  /// Start of the learning day [days] after the one [at] falls in (UTC).
  ///
  /// Intervals count days, so a word is due all through its due day
  /// whatever time it was last reviewed: reviewing a little earlier than
  /// yesterday still finds it due.
  DateTime dueAfter(DateTime at, int days) {
    final day = at.toLocal().subtract(const Duration(hours: dayStartHour));
    return DateTime(day.year, day.month, day.day + days, dayStartHour).toUtc();
  }

  // ---------------------------------------------------------------------------
  // SM-2 core update
  // ---------------------------------------------------------------------------

  /// Applies one review at [now] (default: the current time) and returns the
  /// updated [MemoryState].
  ///
  /// All SM-2 bookkeeping (EF, interval, repetitions) is encapsulated here.
  MemoryState applySmTwo(
    MemoryState state,
    double overallScore, {
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    final grade = gradeFromScore(overallScore);
    final correct = grade >= 3;
    // Not recalled since it was added or last missed.
    final learning = state.sm2Repetitions == 0;

    var repetitions = state.sm2Repetitions;
    var interval = state.sm2Interval;
    var easeFactor = state.easeFactor;
    var nextReviewAt = state.nextReviewAt;

    if (!correct) {
      // Start over tomorrow. Missing a word that is still being learnt
      // (e.g. "I don't know" on first sight) says nothing about how hard
      // it is to retain, so only a lapse lowers the ease factor.
      if (!learning) easeFactor = _adjustEase(easeFactor, grade);
      repetitions = 0;
      interval = 1;
      nextReviewAt = dueAfter(at, 1);
    } else if (learning || isDue(state, at)) {
      interval = switch (repetitions) {
        0 => 1,
        1 => 6,
        _ => max(1, (interval * easeFactor).round()),
      };
      easeFactor = _adjustEase(easeFactor, grade);
      repetitions++;
      nextReviewAt = dueAfter(at, interval);
    }
    // Otherwise a correct answer before the due day: counted below, but the
    // schedule stays, so repeated "review all" sessions on one day cannot
    // push a word up.

    final reviewed = state.copyWith(
      easeFactor: easeFactor,
      sm2Interval: interval,
      sm2Repetitions: repetitions,
      lastReviewedAt: at,
      nextReviewAt: nextReviewAt,
      reviewCount: state.reviewCount + 1,
      correctCount: correct ? state.correctCount + 1 : state.correctCount,
      incorrectCount: correct ? state.incorrectCount : state.incorrectCount + 1,
      consecutiveCorrect: correct ? state.consecutiveCorrect + 1 : 0,
    );
    final strength = currentStrength(reviewed, at);
    return reviewed.copyWith(
      memoryStrength: strength,
      recallProbability: strength,
      stage: stageFromStrength(strength),
    );
  }

  double _adjustEase(double easeFactor, int grade) => max(
        1.3,
        easeFactor + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02)),
      );

  // ---------------------------------------------------------------------------
  // Strength & level (display)
  // ---------------------------------------------------------------------------

  /// Strength right after a recall that scheduled [intervalDays].
  ///
  /// Log scale, so every recall moves a word visibly:
  ///
  ///   1 day → 0.70, 6 → 0.76, 15 → 0.79   (good)
  ///   21 days → 0.80, 45 → 0.85, 120 → 0.92, 365+ → 1.0   (strong)
  ///
  /// Mirrored by `supabase/migrations/20261120000001_memory_model_v2.sql`.
  double peakStrength(int intervalDays) {
    final days = max(1, intervalDays);
    if (days < matureDays) {
      return firstRecallStrength +
          (strongThreshold - firstRecallStrength) * log(days) / log(matureDays);
    }
    final grown = log(days / matureDays) / log(fullStrengthDays / matureDays);
    return min(1.0, strongThreshold + (1 - strongThreshold) * grown);
  }

  /// Strength of [state] at [now] (0.0–1.0).
  ///
  /// 0 unless the last answer was correct. Then [peakStrength] of the
  /// interval until the end of the due day — reviewing any time that day
  /// is on time — after which recall keeps falling along the forgetting
  /// curve SM-2 schedules by, R(t) = 0.9^(t / interval): ×0.9 per interval
  /// overdue, ×0.59 after five, ×0.35 after ten.
  double currentStrength(MemoryState state, DateTime now) {
    if (state.consecutiveCorrect == 0) return 0.0;
    final interval = max(1, state.sm2Interval);
    final peak = peakStrength(interval);
    final overdue =
        now.difference(state.nextReviewAt) - const Duration(days: 1);
    if (overdue <= Duration.zero) return peak;
    final intervals = overdue.inMinutes / (interval * Duration.minutesPerDay);
    return peak * pow(scheduledRecall, intervals);
  }

  /// Level of a word with [strength] that has been recalled before.
  MemoryLevel levelForStrength(double strength) {
    if (strength >= strongThreshold) return MemoryLevel.strong;
    if (strength >= goodThreshold) return MemoryLevel.good;
    if (strength >= weakThreshold) return MemoryLevel.weak;
    return MemoryLevel.critical;
  }

  /// Stored `stage` for [strength] (1 = strong … 4 = critical).
  int stageFromStrength(double strength) => levelForStrength(strength).stage;

  /// What the learner sees for [state] at [now].
  ///
  /// A word never recalled is [MemoryLevel.learning]: there is nothing to
  /// forget yet, so it is not counted as critical.
  MemoryReading readingOf(MemoryState state, DateTime now) {
    if (state.correctCount == 0) {
      return const MemoryReading(MemoryLevel.learning, 0.0);
    }
    final strength = currentStrength(state, now);
    return MemoryReading(levelForStrength(strength), strength);
  }
}
