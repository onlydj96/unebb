import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/providers/build_generation.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/services/deck_overview.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

/// Source of truth for the user's decks (cache-first, background sync,
/// optimistic mutations). Screens normally read [deckListProvider].
class DeckNotifier extends AsyncNotifier<List<Deck>> with BuildGeneration {
  @override
  Future<List<Deck>> build() async {
    ref.keepAlive();
    final generation = beginGeneration(ref);
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final cacheService = ref.watch(cacheServiceProvider);

    final cached = cacheService.getCachedDeckList();
    if (cached != null && cached.isNotEmpty) {
      unawaited(_syncInBackground(cacheService, generation));
      return cached;
    }

    final decks = await ref.read(deckRepositoryProvider).getAll();
    await cacheService.cacheDeckList(decks);
    return decks;
  }

  Future<void> _syncInBackground(
    CacheService cacheService,
    Object generation,
  ) async {
    try {
      final decks = await ref.read(deckRepositoryProvider).getAll();
      if (!isCurrentGeneration(generation)) return;
      await cacheService.cacheDeckList(decks);
      final current = state.valueOrNull;
      if (current == null || !listEquals(current, decks)) {
        state = AsyncData(decks);
      }
    } catch (e, st) {
      AppLogger.warning('Background deck sync failed', details: e);
      AppLogger.debug('Stack trace', data: st);
    }
  }

  void _set(List<Deck> decks) {
    state = AsyncData(decks);
    unawaited(ref.read(cacheServiceProvider).cacheDeckList(decks));
  }

  /// Throws [DuplicateDeckException] when the name is already used.
  Future<Deck> createDeck({
    required String name,
    required String language,
    String? description,
  }) async {
    final normalized = name.trim().toLowerCase();
    final exists = (state.valueOrNull ?? const <Deck>[])
        .any((d) => d.name.trim().toLowerCase() == normalized);
    if (exists) throw DuplicateDeckException(name: name);

    final Deck deck;
    try {
      deck = await ref.read(deckRepositoryProvider).create(
            name: name,
            language: language,
            description: description,
          );
    } catch (e) {
      if (PgErrorCodes.isUniqueViolation(e)) {
        throw DuplicateDeckException(name: name);
      }
      rethrow;
    }

    _set([deck, ...?state.valueOrNull]);
    return deck;
  }

  /// Deletes the deck. Its words are removed by the database (cascade), so
  /// they are dropped from the local vocabulary list as well.
  Future<void> deleteDeck(String id) async {
    await ref.read(deckRepositoryProvider).delete(id);
    _set([
      for (final d in state.valueOrNull ?? const <Deck>[])
        if (d.id != id) d,
    ]);
    if (ref.exists(vocabularyNotifierProvider)) {
      ref.read(vocabularyNotifierProvider.notifier).removeDeckWords(id);
    }
  }

  Future<void> updateDeck(Deck deck) async {
    final saved = await ref.read(deckRepositoryProvider).update(deck);
    _set([
      for (final d in state.valueOrNull ?? const <Deck>[])
        d.id == saved.id ? saved : d,
    ]);
  }

  /// Pull-to-refresh; rethrows on failure (previous data is kept).
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<List<Deck>>().copyWithPrevious(previous);
    try {
      final decks = await ref.read(deckRepositoryProvider).getAll();
      await ref.read(cacheServiceProvider).cacheDeckList(decks);
      state = AsyncData(decks);
    } catch (e, st) {
      state = previous.hasValue ? previous : AsyncError(e, st);
      rethrow;
    }
  }
}

final deckNotifierProvider =
    AsyncNotifierProvider<DeckNotifier, List<Deck>>(DeckNotifier.new);

/// Decks for display: live word counts (from the vocabulary list) and ordered
/// by most recent review activity.
final deckListProvider = Provider<AsyncValue<List<Deck>>>((ref) {
  final decksAsync = ref.watch(deckNotifierProvider);
  final words = ref.watch(vocabularyNotifierProvider).valueOrNull;
  final memory = ref.watch(memoryStatesMapNotifierProvider).valueOrNull;
  return decksAsync.whenData(
    (decks) => DeckOverview.arrange(decks, words: words, memory: memory),
  );
});

/// A single deck (with a live word count). `null` data = not found.
final deckByIdProvider =
    Provider.autoDispose.family<AsyncValue<Deck?>, String>((ref, id) {
  return ref.watch(deckListProvider).whenData(
        (decks) => decks.where((d) => d.id == id).firstOrNull,
      );
});

/// Words of one deck, newest first.
final deckVocabularyProvider = Provider.autoDispose
    .family<AsyncValue<List<VocabularyItem>>, String>((ref, deckId) {
  return ref.watch(vocabularyNotifierProvider).whenData(
        (items) => items.where((item) => item.deckId == deckId).toList(),
      );
});

/// Number of words due for review, optionally limited to one deck.
/// `null` while the data needed to compute it is loading.
final dueCountProvider =
    Provider.autoDispose.family<int?, String?>((ref, deckId) {
  final words = ref.watch(vocabularyNotifierProvider).valueOrNull;
  final memory = ref.watch(memoryStatesMapNotifierProvider).valueOrNull;
  if (words == null || memory == null) return null;
  return DeckOverview.dueCount(words: words, memory: memory, deckId: deckId);
});
