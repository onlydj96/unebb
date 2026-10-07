import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/deck.dart';

/// Provides the list of all decks for the current user.
final deckListProvider = FutureProvider<List<Deck>>((ref) {
  return ref.read(deckRepositoryProvider).getAll();
});

/// Provides a single deck by ID.
final deckByIdProvider = FutureProvider.family<Deck?, String>((ref, id) {
  return ref.read(deckRepositoryProvider).getById(id);
});

/// Notifier for managing deck operations.
class DeckNotifier extends AsyncNotifier<List<Deck>> {
  @override
  Future<List<Deck>> build() {
    return ref.read(deckRepositoryProvider).getAll();
  }

  Future<Deck> createDeck({
    required String name,
    required String language,
    String? description,
  }) async {
    final deck = await ref.read(deckRepositoryProvider).create(
          name: name,
          language: language,
          description: description,
        );
    ref.invalidateSelf();
    return deck;
  }

  Future<void> deleteDeck(String id) async {
    await ref.read(deckRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  Future<void> updateDeck(Deck deck) async {
    await ref.read(deckRepositoryProvider).update(deck);
    ref.invalidateSelf();
  }
}

final deckNotifierProvider =
    AsyncNotifierProvider<DeckNotifier, List<Deck>>(DeckNotifier.new);
