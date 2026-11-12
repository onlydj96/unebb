import 'dart:math';

import 'package:unebb/domain/models/memory_state.dart';

/// Pure domain service that decides which words a review session contains
/// and in what order. No Flutter, no Supabase.
///
/// Ordering rules:
/// 1. Words never reviewed (`reviewCount == 0`) always come first, shuffled.
/// 2. Reviewed words are split into priority tiers by [priorityScore]
///    (lower score = more urgent) and interleaved with weighted randomness
///    (60% high / 30% medium / 10% low) so sessions stay varied while
///    struggling words surface early.
class ReviewQueueBuilder {
  const ReviewQueueBuilder();

  /// Whether [state] is due at [now].
  bool isDue(MemoryState state, DateTime now) =>
      !state.nextReviewAt.isAfter(now);

  /// Selects the states to review for [mode] (`'due'` or `'all'`) and returns
  /// them in review order.
  List<MemoryState> build(
    List<MemoryState> states, {
    required String mode,
    DateTime? now,
    Random? random,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    final candidates =
        mode == 'all' ? states : states.where((s) => isDue(s, at)).toList();
    return order(candidates, now: at, random: random);
  }

  /// Lower score = higher priority. Only meaningful for reviewed words.
  double priorityScore(MemoryState state, DateTime now) {
    // Weak memory → low score → high priority. (The previous repository
    // version used `1.0 - strength`, which sent the weakest words to the
    // low-priority tier.)
    var score = state.memoryStrength;

    // Words the learner keeps getting wrong are pushed forward.
    if (state.incorrectCount > 0) {
      final incorrectRatio = state.incorrectCount / (state.reviewCount + 1);
      score -= incorrectRatio * 0.5;
    }

    // Slight boost for overdue words.
    final overdueDays = now.difference(state.nextReviewAt).inDays;
    if (overdueDays > 0) score -= overdueDays * 0.01;

    return score;
  }

  List<MemoryState> order(
    List<MemoryState> states, {
    DateTime? now,
    Random? random,
  }) {
    if (states.isEmpty) return const [];
    final rng = random ?? Random();
    final at = (now ?? DateTime.now()).toUtc();

    final newWords = states.where((s) => s.reviewCount == 0).toList()
      ..shuffle(rng);

    final high = <MemoryState>[];
    final medium = <MemoryState>[];
    final low = <MemoryState>[];
    for (final state in states.where((s) => s.reviewCount > 0)) {
      final score = priorityScore(state, at);
      if (score < 0.4) {
        high.add(state);
      } else if (score < 0.7) {
        medium.add(state);
      } else {
        low.add(state);
      }
    }
    high.shuffle(rng);
    medium.shuffle(rng);
    low.shuffle(rng);

    final result = <MemoryState>[...newWords];
    var h = 0, m = 0, l = 0;
    while (h < high.length || m < medium.length || l < low.length) {
      final dice = rng.nextInt(100);
      if (dice < 60 && h < high.length) {
        result.add(high[h++]);
      } else if (dice < 90 && m < medium.length) {
        result.add(medium[m++]);
      } else if (l < low.length) {
        result.add(low[l++]);
      } else if (h < high.length) {
        result.add(high[h++]);
      } else if (m < medium.length) {
        result.add(medium[m++]);
      } else {
        result.add(low[l++]);
      }
    }
    return result;
  }
}
