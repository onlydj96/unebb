import 'dart:math';

import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/services/memory_service.dart';

/// Pure domain service that decides which words a review session contains
/// and in what order. No Flutter, no Supabase.
///
/// Ordering rules:
/// 1. Words never reviewed (`reviewCount == 0`) always come first, shuffled.
/// 2. Reviewed words follow by [priorityScore], most urgent first: words
///    still being learnt or just missed (strength 0) before fading ones,
///    and those before words the learner remembers. Equal scores are in
///    random order. Sessions are usually limited, so a remembered word
///    only takes a place when no struggling word is left for it.
class ReviewQueueBuilder {
  const ReviewQueueBuilder({this.memory = const MemoryService()});

  final MemoryService memory;

  /// Whether a `'due'` session at [now] takes [state]
  /// ([MemoryService.isUpForReview]).
  bool isUpForReview(MemoryState state, DateTime now) =>
      memory.isUpForReview(state, now);

  /// Selects the states to review for [mode] (`'due'`: due words plus words
  /// being learnt or just missed; `'all'`: every word) and returns them in
  /// review order.
  List<MemoryState> build(
    List<MemoryState> states, {
    required String mode,
    DateTime? now,
    Random? random,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    final candidates = mode == 'all'
        ? states
        : states.where((s) => isUpForReview(s, at)).toList();
    return order(candidates, now: at, random: random);
  }

  /// Lower score = higher priority. Only meaningful for reviewed words.
  double priorityScore(MemoryState state, DateTime now) {
    // Weak memory → low score → high priority. The strength the learner
    // sees now: decayed when overdue, 0 for words missed or not learnt yet
    // (the stored value is only the one right after the last review).
    var score = memory.currentStrength(state, now);

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

    // Random tie-break: words with the same score (e.g. all recalled once
    // yesterday) come in a different order each session.
    final reviewed = [
      for (final s in states.where((s) => s.reviewCount > 0))
        (state: s, score: priorityScore(s, at), tie: rng.nextDouble()),
    ]..sort((a, b) {
        final byScore = a.score.compareTo(b.score);
        return byScore != 0 ? byScore : a.tie.compareTo(b.tie);
      });

    return [...newWords, for (final r in reviewed) r.state];
  }
}
