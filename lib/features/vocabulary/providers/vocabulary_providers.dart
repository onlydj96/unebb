import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/providers/build_generation.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/vocabulary/providers/ai_content_provider.dart';

/// Normalized form used for duplicate detection (mirrors the DB unique index
/// on `(user_id, lower(word), language)`).
String normalizeWord(String word) => word.trim().toLowerCase();

/// Manages the full vocabulary list for the current user.
///
/// Cache-first: cached words render instantly, then a background sync
/// replaces them whenever the server copy differs (edits, AI content written
/// by the Edge Function, other devices).
class VocabularyNotifier extends AsyncNotifier<List<VocabularyItem>>
    with BuildGeneration {
  @override
  Future<List<VocabularyItem>> build() async {
    ref.keepAlive();
    final generation = beginGeneration(ref);
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final cacheService = ref.watch(cacheServiceProvider);

    final cached = cacheService.getCachedVocabularyList();
    if (cached != null && cached.isNotEmpty) {
      unawaited(_syncInBackground(cacheService, generation));
      return cached;
    }

    final items = await ref.read(vocabularyRepositoryProvider).getAll();
    await cacheService.cacheVocabularyList(items);
    return items;
  }

  Future<void> _syncInBackground(
    CacheService cacheService,
    Object generation,
  ) async {
    try {
      final items = await ref.read(vocabularyRepositoryProvider).getAll();
      if (!isCurrentGeneration(generation)) return;
      await cacheService.cacheVocabularyList(items);
      final current = state.valueOrNull;
      if (current == null || !listEquals(current, items)) {
        state = AsyncData(items);
      }
    } catch (e, st) {
      AppLogger.warning('Background vocabulary sync failed', details: e);
      AppLogger.debug('Stack trace', data: st);
    }
  }

  /// Finds an existing word with the same spelling and language.
  ///
  /// [deckId] limits the search to one deck; [excludeId] skips the word being
  /// edited.
  VocabularyItem? findLocalDuplicate({
    required String word,
    required String language,
    String? deckId,
    String? excludeId,
  }) {
    final normalized = normalizeWord(word);
    return (state.valueOrNull ?? const <VocabularyItem>[])
        .where((v) =>
            v.id != excludeId &&
            v.language == language &&
            normalizeWord(v.word) == normalized &&
            (deckId == null || v.deckId == deckId))
        .firstOrNull;
  }

  DuplicateWordException _duplicateError(String word, String language) {
    final existing = findLocalDuplicate(word: word, language: language);
    return DuplicateWordException(
      word: word,
      existingDeckId: existing?.deckId,
    );
  }

  /// Adds a new word and returns the created vocabulary item's ID.
  ///
  /// Throws [DuplicateWordException] if the word already exists in the deck
  /// (or anywhere, when the database enforces per-user uniqueness).
  Future<String> addWord({
    required String word,
    required String language,
    String? deckId,
  }) async {
    final vocabRepo = ref.read(vocabularyRepositoryProvider);

    // 1. Duplicate check against the in-memory list (no network round trip);
    //    fall back to the server when the list is not loaded yet.
    final loaded = state.hasValue;
    final duplicate = loaded
        ? findLocalDuplicate(word: word, language: language, deckId: deckId)
        : await vocabRepo.findDuplicate(
            word: word,
            language: language,
            deckId: deckId,
          );
    if (duplicate != null) {
      throw DuplicateWordException(
        word: word,
        existingDeckId: duplicate.deckId,
      );
    }

    // 2. Create the row. The DB unique index is the final authority.
    final VocabularyItem item;
    try {
      item = await vocabRepo.create(
        word: word,
        language: language,
        deckId: deckId,
      );
    } catch (e) {
      if (PgErrorCodes.isUniqueViolation(e)) {
        throw _duplicateError(word, language);
      }
      rethrow;
    }

    // 3. Optimistically show the word everywhere.
    final updatedList = [item, ...?state.valueOrNull];
    state = AsyncData(updatedList);
    unawaited(ref.read(cacheServiceProvider).cacheVocabularyList(updatedList));

    // 4. Initial memory state so it enters the review queue. Not fatal: a
    //    review session creates missing states on its own.
    try {
      final memoryState = await ref
          .read(memoryStateRepositoryProvider)
          .create(vocabularyId: item.id);
      if (ref.exists(memoryStatesMapNotifierProvider)) {
        ref
            .read(memoryStatesMapNotifierProvider.notifier)
            .addState(memoryState);
      }
    } catch (e, st) {
      AppLogger.warning('Initial memory state creation failed', details: e);
      AppLogger.debug('Stack trace', data: st);
    }

    // 5. Generate AI content in the background (status is observable).
    unawaited(ref.read(aiContentProvider.notifier).ensure(item));

    return item.id;
  }

  /// Saves edits to a word. When the spelling or language changes, the old
  /// AI content (which describes the previous word) is cleared and
  /// regenerated.
  Future<VocabularyItem> updateWord(VocabularyItem item) async {
    final previous = (state.valueOrNull ?? const [])
        .where((v) => v.id == item.id)
        .firstOrNull;
    final wordChanged = previous != null &&
        (normalizeWord(previous.word) != normalizeWord(item.word) ||
            previous.language != item.language);

    final duplicate = findLocalDuplicate(
      word: item.word,
      language: item.language,
      excludeId: item.id,
      deckId: item.deckId,
    );
    if (duplicate != null) {
      throw DuplicateWordException(
        word: item.word,
        existingDeckId: duplicate.deckId,
      );
    }

    // Apply only the edited fields onto the latest copy: AI content that
    // arrived after the edit screen opened must not be overwritten with the
    // screen's stale (empty) snapshot.
    final edited = (previous ?? item).copyWith(
      word: item.word,
      language: item.language,
      deckId: item.deckId,
    );
    final toSave = wordChanged
        ? edited.copyWith(
            pronunciation: null,
            definition: null,
            explanation: null,
            usage: null,
            examples: null,
            synonyms: null,
            collocations: null,
            commonMistakes: null,
          )
        : edited;

    final VocabularyItem saved;
    try {
      saved = await ref.read(vocabularyRepositoryProvider).update(toSave);
    } catch (e) {
      if (PgErrorCodes.isUniqueViolation(e)) {
        throw _duplicateError(item.word, item.language);
      }
      rethrow;
    }

    _replace(saved);
    if (wordChanged) {
      unawaited(
          ref.read(aiContentProvider.notifier).ensure(saved, force: true));
    }
    return saved;
  }

  Future<void> deleteWord(String id) async {
    await ref.read(vocabularyRepositoryProvider).delete(id);

    final updatedList = (state.valueOrNull ?? const <VocabularyItem>[])
        .where((v) => v.id != id)
        .toList();
    state = AsyncData(updatedList);
    unawaited(ref.read(cacheServiceProvider).cacheVocabularyList(updatedList));

    if (ref.exists(memoryStatesMapNotifierProvider)) {
      ref.read(memoryStatesMapNotifierProvider.notifier).removeStates({id});
    }
  }

  /// Drops every word of a deleted deck (the DB cascades the delete).
  void removeDeckWords(String deckId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final removedIds =
        current.where((v) => v.deckId == deckId).map((v) => v.id).toSet();
    if (removedIds.isEmpty) return;
    final updatedList =
        current.where((v) => !removedIds.contains(v.id)).toList();
    state = AsyncData(updatedList);
    unawaited(ref.read(cacheServiceProvider).cacheVocabularyList(updatedList));
    if (ref.exists(memoryStatesMapNotifierProvider)) {
      ref
          .read(memoryStatesMapNotifierProvider.notifier)
          .removeStates(removedIds);
    }
  }

  /// Applies a row returned by the server (e.g. freshly generated AI content).
  void applyServerUpdate(VocabularyItem item) => _replace(item);

  void _replace(VocabularyItem item) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updatedList = [
      for (final v in current) v.id == item.id ? item : v,
    ];
    state = AsyncData(updatedList);
    unawaited(ref.read(cacheServiceProvider).cacheVocabularyList(updatedList));
  }

  /// Pull-to-refresh. Keeps the current list on screen while loading and
  /// rethrows on failure so the caller can tell the user.
  Future<void> refresh() async {
    final previous = state;
    state =
        const AsyncLoading<List<VocabularyItem>>().copyWithPrevious(previous);
    try {
      final items = await ref.read(vocabularyRepositoryProvider).getAll();
      await ref.read(cacheServiceProvider).cacheVocabularyList(items);
      state = AsyncData(items);
    } catch (e, st) {
      state = previous.hasValue ? previous : AsyncError(e, st);
      rethrow;
    }
  }
}

final vocabularyNotifierProvider =
    AsyncNotifierProvider<VocabularyNotifier, List<VocabularyItem>>(
  VocabularyNotifier.new,
);

/// A single vocabulary item.
///
/// Served from the vocabulary list when possible, so edits and freshly
/// generated AI content show up immediately; falls back to a direct fetch for
/// words that are not in the list (deep links, stale cache).
final vocabularyItemProvider =
    FutureProvider.autoDispose.family<VocabularyItem?, String>((ref, id) async {
  final list = await ref.watch(vocabularyNotifierProvider.future);
  final local = list.where((v) => v.id == id).firstOrNull;
  if (local != null) return local;
  return ref.read(vocabularyRepositoryProvider).getById(id);
});

/// Manages the memory states map with cache-first loading and optimistic
/// updates (used by the dashboard, deck and word screens).
class MemoryStatesMapNotifier extends AsyncNotifier<Map<String, MemoryState>>
    with BuildGeneration {
  @override
  Future<Map<String, MemoryState>> build() async {
    ref.keepAlive();
    final generation = beginGeneration(ref);
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};

    final cacheService = ref.watch(cacheServiceProvider);

    final cached = cacheService.getCachedMemoryStates();
    if (cached != null && cached.isNotEmpty) {
      unawaited(_syncInBackground(cacheService, generation));
      return {for (final s in cached) s.vocabularyId: s};
    }

    final states = await ref.read(memoryStateRepositoryProvider).getAll();
    await cacheService.cacheMemoryStates(states);
    return {for (final s in states) s.vocabularyId: s};
  }

  Future<void> _syncInBackground(
    CacheService cacheService,
    Object generation,
  ) async {
    try {
      final states = await ref.read(memoryStateRepositoryProvider).getAll();
      if (!isCurrentGeneration(generation)) return;
      await cacheService.cacheMemoryStates(states);
      final fresh = {for (final s in states) s.vocabularyId: s};
      final current = state.valueOrNull;
      if (current == null || !mapEquals(current, fresh)) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      AppLogger.warning('Background memory states sync failed', details: e);
      AppLogger.debug('Stack trace', data: st);
    }
  }

  void _set(Map<String, MemoryState> map) {
    state = AsyncData(map);
    unawaited(
      ref.read(cacheServiceProvider).cacheMemoryStates(map.values.toList()),
    );
  }

  /// Add a single memory state (used after adding a word).
  void addState(MemoryState memoryState) => updateState(memoryState);

  /// Remove memory states (used after deleting words).
  void removeStates(Set<String> vocabularyIds) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(Map.of(current)..removeWhere((id, _) => vocabularyIds.contains(id)));
  }

  /// Insert or replace a single memory state (used after each review).
  void updateState(MemoryState memoryState) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set({...current, memoryState.vocabularyId: memoryState});
  }

  /// Pull-to-refresh; rethrows on failure (previous data is kept).
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<Map<String, MemoryState>>()
        .copyWithPrevious(previous);
    try {
      final states = await ref.read(memoryStateRepositoryProvider).getAll();
      await ref.read(cacheServiceProvider).cacheMemoryStates(states);
      state = AsyncData({for (final s in states) s.vocabularyId: s});
    } catch (e, st) {
      state = previous.hasValue ? previous : AsyncError(e, st);
      rethrow;
    }
  }
}

final memoryStatesMapNotifierProvider =
    AsyncNotifierProvider<MemoryStatesMapNotifier, Map<String, MemoryState>>(
  MemoryStatesMapNotifier.new,
);

/// Read-only view of [memoryStatesMapNotifierProvider].
final memoryStatesMapProvider =
    FutureProvider<Map<String, MemoryState>>((ref) async {
  return ref.watch(memoryStatesMapNotifierProvider.future);
});
