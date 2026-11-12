import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';

/// Pure presentation-independent deck ordering and counting.
///
/// Word counts and "last studied" times are derived from data the app already
/// holds (vocabulary list + memory states), so showing decks costs a single
/// `decks` query instead of scanning the whole review history.
abstract final class DeckOverview {
  /// Returns [decks] with fresh word counts (when [words] is known) ordered by
  /// most recent review activity; decks never reviewed follow, newest first.
  static List<Deck> arrange(
    List<Deck> decks, {
    List<VocabularyItem>? words,
    Map<String, MemoryState>? memory,
  }) {
    final counts = <String, int>{};
    final lastReviewed = <String, DateTime>{};

    if (words != null) {
      for (final word in words) {
        final deckId = word.deckId;
        if (deckId == null) continue;
        counts[deckId] = (counts[deckId] ?? 0) + 1;

        final reviewedAt = memory?[word.id]?.lastReviewedAt;
        if (reviewedAt == null) continue;
        final current = lastReviewed[deckId];
        if (current == null || reviewedAt.isAfter(current)) {
          lastReviewed[deckId] = reviewedAt;
        }
      }
    }

    final arranged = [
      for (final deck in decks)
        words == null ? deck : deck.copyWith(wordCount: counts[deck.id] ?? 0),
    ];

    arranged.sort((a, b) {
      final aReview = lastReviewed[a.id];
      final bReview = lastReviewed[b.id];
      if (aReview != null && bReview != null) return bReview.compareTo(aReview);
      if (aReview != null) return -1;
      if (bReview != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return arranged;
  }

  /// Number of words in [deckId] (or all words when null) due at [now].
  static int dueCount({
    required List<VocabularyItem> words,
    required Map<String, MemoryState> memory,
    String? deckId,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    var due = 0;
    for (final word in words) {
      if (deckId != null && word.deckId != deckId) continue;
      final state = memory[word.id];
      // Words without a memory state yet are new → due immediately.
      if (state == null || !state.nextReviewAt.isAfter(at)) due++;
    }
    return due;
  }
}
