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
/// Memory strength (UI display only), see [strengthFor]:
///   not recalled yet / last answer wrong → 0.0 (critical)
///   recalled → 0.30 + 0.70 × ln(interval) / ln(60), capped at 1.0
///   so 1st recall → weak, 2nd–3rd → good, 4th → strong.
///   Stage derives from strength.
class MemoryService {
  const MemoryService();

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

  /// Applies one SM-2 review step and returns an updated [MemoryState].
  ///
  /// Only [state] and [overallScore] are required.
  /// All SM-2 bookkeeping (EF, interval, repetitions) is encapsulated here.
  MemoryState applySmTwo(MemoryState state, double overallScore) {
    final grade = gradeFromScore(overallScore);
    final correct = grade >= 3;

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
    final newStage = stageFromStrength(newStrength);
    final nextReview = DateTime.now().toUtc().add(Duration(days: interval));

    return state.copyWith(
      easeFactor: ef,
      sm2Interval: interval,
      sm2Repetitions: repetitions,
      memoryStrength: newStrength,
      recallProbability: newStrength,
      stage: newStage,
      lastReviewedAt: DateTime.now().toUtc(),
      nextReviewAt: nextReview,
      reviewCount: state.reviewCount + 1,
      correctCount: correct ? state.correctCount + 1 : state.correctCount,
      incorrectCount: correct ? state.incorrectCount : state.incorrectCount + 1,
      consecutiveCorrect: correct ? state.consecutiveCorrect + 1 : 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
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
