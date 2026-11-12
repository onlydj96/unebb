import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/domain/services/deck_overview.dart';

import '../../helpers/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 9, 12);

  group('DeckOverview.arrange', () {
    test('derives live word counts from the vocabulary list', () {
      final decks = [deck('d1', wordCount: 0), deck('d2', wordCount: 9)];
      final words = [
        vocab('a', deckId: 'd1'),
        vocab('b', deckId: 'd1'),
        vocab('c'), // no deck
      ];

      final arranged = DeckOverview.arrange(decks, words: words);

      expect(arranged.firstWhere((d) => d.id == 'd1').wordCount, 2);
      expect(arranged.firstWhere((d) => d.id == 'd2').wordCount, 0);
    });

    test('keeps server counts while the vocabulary is not loaded', () {
      final arranged = DeckOverview.arrange([deck('d1', wordCount: 5)]);
      expect(arranged.single.wordCount, 5);
    });

    test('orders by most recent review, then newest deck', () {
      final decks = [
        deck('old-unreviewed', createdAt: DateTime.utc(2026, 1, 1)),
        deck('new-unreviewed', createdAt: DateTime.utc(2026, 6, 1)),
        deck('reviewed-long-ago', createdAt: DateTime.utc(2025, 1, 1)),
        deck('reviewed-today', createdAt: DateTime.utc(2025, 1, 1)),
      ];
      final words = [
        vocab('x', deckId: 'reviewed-long-ago'),
        vocab('y', deckId: 'reviewed-today'),
      ];
      final memoryMap = {
        'x':
            memory('x', lastReviewedAt: now.subtract(const Duration(days: 30))),
        'y': memory('y', lastReviewedAt: now),
      };

      final arranged =
          DeckOverview.arrange(decks, words: words, memory: memoryMap);

      expect(arranged.map((d) => d.id), [
        'reviewed-today',
        'reviewed-long-ago',
        'new-unreviewed',
        'old-unreviewed',
      ]);
    });
  });

  group('DeckOverview.dueCount', () {
    test('counts due words per deck; words without a state are new/due', () {
      final words = [
        vocab('due', deckId: 'd1'),
        vocab('later', deckId: 'd1'),
        vocab('no-state', deckId: 'd1'),
        vocab('other-deck', deckId: 'd2'),
      ];
      final memoryMap = {
        'due': memory('due',
            nextReviewAt: now.subtract(const Duration(minutes: 1))),
        'later':
            memory('later', nextReviewAt: now.add(const Duration(days: 2))),
        'other-deck': memory('other-deck', nextReviewAt: now),
      };

      expect(
        DeckOverview.dueCount(
          words: words,
          memory: memoryMap,
          deckId: 'd1',
          now: now,
        ),
        2,
      );
      expect(
        DeckOverview.dueCount(words: words, memory: memoryMap, now: now),
        3,
      );
    });
  });
}
