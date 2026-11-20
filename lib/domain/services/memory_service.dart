import 'dart:math';

import 'package:unebb/domain/models/memory_state.dart';

/// Pure domain service — no Flutter, no Supabase imports.
///
/// Implements the SM-2 spaced repetition algorithm (SuperMemo 2).
///
/// Grade mapping from overallScore:
///   >= 0.90 → 5 (perfect recall)
///   >= 0.75 → 4 (correct with hesitation)
///   >= 0.60 → 3 (correct with difficulty)
///    < 0.60 → 1 (incorrect / blackout)
///
/// SM-2 interval rules:
///   grade < 3  → repetitions=0, interval=1 (review again tomorrow)
///   grade >= 3 →
///     repetitions=0 → interval=1
///     repetitions=1 → interval=6
///     repetitions>1 → interval=round(prev_interval × EF)
///   EF = EF + (0.1 - (5-grade)(0.08 + (5-grade)×0.02))
///   EF = max(1.3, EF)
///
/// Early reviews (before `nextReviewAt`, e.g. a "review all" session): a
/// correct answer is counted but leaves the schedule as it is; a wrong
/// answer resets it as usual.
///
/// Memory strength (UI display only), see [strengthFor]:
///   not recalled yet / last answer wrong → 0.0 (critical)
///   recalled → 0.30 + 0.70 × ln(interval) / ln(60), capped at 1.0
///   so 1st recall → weak, 2nd–3rd → good, 4th → strong.
///   Stage derives from strength. [currentStrength] adds decay for words
///   whose review is overdue.
class MemoryService {
  const MemoryService();

  /// Recall probability SM-2 expects on the due date: the interval is how
  /// long it takes for recall to fall to about this level.
  static const double scheduledRecall = 0.9;

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

  /// Whether [state] is due for review at [now] (same rule as the review
  /// queue).
  bool isDue(MemoryState state, DateTime now) =>
      !state.nextReviewAt.isAfter(now);

  // ---------------------------------------------------------------------------
  // Stage (UI display only — derived from strength)
  // ---------------------------------------------------------------------------

  /// Stage 1 (Well Known):    strength >= 0.80
  /// Stage 2 (Mostly Known):  0.60 <= strength < 0.80
  /// Stage 3 (Vaguely Known): 0.30 <= strength < 0.60
  /// Stage 4 (Unknown):       strength < 0.30
  int stageFromStrength(double strength) {
    if (strength >= 0.80) return 1;
    if (strength >= 0.60) return 2;
    if (strength >= 0.30) return 3;
    return 4;
  }

  // ---------------------------------------------------------------------------
  // SM-2 core update
  // ---------------------------------------------------------------------------

  /// Applies one SM-2 review step at [now] (default: the current time) and
  /// returns an updated [MemoryState].
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

    if (correct && !isDue(state, at)) {
      // Recalling a word seen recently says little about long-term
      // retention: advancing the schedule here would let repeated "review
      // all" sessions push a new word to "strong" within a single day.
      final strength = scheduledStrength(state);
      return state.copyWith(
        memoryStrength: strength,
        recallProbability: strength,
        stage: stageFromStrength(strength),
        lastReviewedAt: at,
        reviewCount: state.reviewCount + 1,
        correctCount: state.correctCount + 1,
        consecutiveCorrect: state.consecutiveCorrect + 1,
      );
    }

    int repetitions = state.sm2Repetitions;
    int interval = state.sm2Interval;
    double ef = state.easeFactor;

    if (!correct) {
      // Failed: reset streak, review tomorrow
      repetitions = 0;
      interval = 1;
    } else {
      // Successful: advance repetitions and compute next interval
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * ef).round();
      }
      repetitions++;
    }

    // Update ease factor (clamp to >= 1.3)
    ef = ef + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02));
    ef = max(1.3, ef);

    final newStrength =
        strengthFor(repetitions: repetitions, intervalDays: interval);

    return state.copyWith(
      easeFactor: ef,
      sm2Interval: interval,
      sm2Repetitions: repetitions,
      memoryStrength: newStrength,
      recallProbability: newStrength,
      stage: stageFromStrength(newStrength),
      lastReviewedAt: at,
      nextReviewAt: at.add(Duration(days: interval)),
      reviewCount: state.reviewCount + 1,
      correctCount: correct ? state.correctCount + 1 : state.correctCount,
      incorrectCount: correct ? state.incorrectCount : state.incorrectCount + 1,
      consecutiveCorrect: correct ? state.consecutiveCorrect + 1 : 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Strength
  // ---------------------------------------------------------------------------

  /// Converts the SM-2 streak and interval to a [0.0, 1.0] display strength.
  ///
  /// The interval alone cannot tell a first recall from a miss (both give
  /// 1 day), so the streak decides: no streak → critical, any recall →
  /// at least weak. Above that the interval grows on a log scale so every
  /// recall moves the word visibly; 60 days counts as fully known.
  ///
  ///   recall #1 (1 day)   → 0.30 weak
  ///   recall #2 (6 days)  → 0.61 good
  ///   recall #3 (~15 days) → 0.76 good
  ///   recall #4 (~40 days) → 0.93 strong
  ///
  /// Mirrored by the backfill in
  /// `supabase/migrations/20261116000001_recompute_memory_strength.sql`.
  double strengthFor({required int repetitions, required int intervalDays}) {
    if (repetitions <= 0) return 0.0;
    final days = max(1, intervalDays);
    return (0.30 + 0.70 * log(days) / log(60)).clamp(0.0, 1.0);
  }

  /// Strength of [state] right after its last review (see [strengthFor]).
  /// Derived from the SM-2 fields, so rows whose stored strength predates
  /// the current scale still display correctly.
  double scheduledStrength(MemoryState state) => strengthFor(
        repetitions: state.sm2Repetitions,
        intervalDays: state.sm2Interval,
      );

  /// Strength to display at [now].
  ///
  /// Until the review is due this is [scheduledStrength]. After that, recall
  /// keeps falling along the forgetting curve SM-2 schedules by,
  /// R(t) = 0.9^(t / interval), so the strength is scaled by
  /// 0.9^(overdue / interval): one interval overdue → ×0.9, five → ×0.59,
  /// ten → ×0.35.
  double currentStrength(MemoryState state, DateTime now) {
    final scheduled = scheduledStrength(state);
    final overdue = now.difference(state.nextReviewAt);
    if (scheduled == 0 || overdue <= Duration.zero) return scheduled;
    final interval = max(1, state.sm2Interval) * Duration.minutesPerDay;
    return scheduled * pow(scheduledRecall, overdue.inMinutes / interval);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Legacy: computes next review from stage (kept for compatibility).
  DateTime calculateNextReview(int stage) {
    final now = DateTime.now().toUtc();
    return switch (stage) {
      1 => now.add(const Duration(days: 7)),
      2 => now.add(const Duration(days: 3)),
      3 => now.add(const Duration(days: 1)),
      4 => now.add(const Duration(minutes: 10)),
      _ => now.add(const Duration(days: 1)),
    };
  }
}
