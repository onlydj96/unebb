import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/providers/build_generation.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/services/delta_sync.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/vocabulary/providers/ai_content_provider.dart';

/// Normalized form used for duplicate detection (mirrors the DB unique index
/// on `(user_id, lower(word), language)`).
String normalizeWord(String word) => word.trim().toLowerCase();

/// A [VocabularyNotifier.sync] / [MemoryStatesMapNotifier.sync] call within
/// this long after a completed sync reuses its result.
const Duration kResyncAfter = Duration(seconds: 30);

/// Newest words first (the server's `created_at desc` order); ties keep their
/// current order so the list does not reshuffle between syncs.
List<VocabularyItem> _newestFirst(List<VocabularyItem> items) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byDate = b.$2.createdAt.compareTo(a.$2.createdAt);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in indexed) item];
}

/// Manages the full vocabulary list for the current user.
///
/// Cache-first: cached words render instantly, then a background sync
/// applies whatever changed on the server (edits, AI content written by the
/// Edge Function, other devices). The sync downloads only rows changed since
/// the previous one (see [deltaSync]); a full download happens without a
/// usable cache, once a day, and on pull-to-refresh.
class VocabularyNotifier extends AsyncNotifier<List<VocabularyItem>>
    with BuildGeneration {
  Object _build = Object();
  Future<void>? _syncing;
  DateTime? _lastSyncedAt;

  @override
  Future<List<VocabularyItem>> build() async {
    ref.keepAlive();
    final generation = _build = beginGeneration(ref);
    _syncing = null;
    _lastSyncedAt = null;
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final cacheService = ref.watch(cacheServiceProvider);

    final cached = cacheService.getCachedVocabularyList();
    if (cached != null && cached.isNotEmpty) {
      _startSync(cacheService, generation, cached);
      return cached;
    }

    final (items, cursor) = await _fetchFresh(cacheService, null);
    await cacheService.cacheVocabularyList(items, syncCursor: cursor);
    _lastSyncedAt = DateTime.now();
    return items;
  }

  /// Brings the list up to date with the server and returns it (used before
  /// a review session). Joins a sync already running and skips the server
  /// when one finished within [kResyncAfter]. Once the list has loaded this
  /// never throws: offline, the current list is returned.
  Future<List<VocabularyItem>> sync() async {
    final loaded = await future;
    final last = _lastSyncedAt;
    final recent =
        last != null && DateTime.now().difference(last) < kResyncAfter;
    if (_syncing == null &&
        !recent &&
        ref.read(currentUserIdProvider) != null) {
      _startSync(
        ref.read(cacheServiceProvider),
        _build,
        state.valueOrNull ?? loaded,
      );
    }
    await _syncing;
    return state.valueOrNull ?? loaded;
  }

  void _startSync(
    CacheService cacheService,
    Object generation,
    List<VocabularyItem> base,
  ) {
    final run = _syncWithServer(cacheService, generation, base);
    _syncing = run;
    unawaited(run.whenComplete(() {
      if (identical(_syncing, run)) _syncing = null;
    }));
  }

  Future<void> _syncWithServer(
    CacheService cacheService,
    Object generation,
    List<VocabularyItem> base,
  ) async {
    try {
      final (items, cursor) = await _fetchFresh(cacheService, base);
      if (!isCurrentGeneration(generation)) return;
      await cacheService.cacheVocabularyList(items, syncCursor: cursor);
      _lastSyncedAt = DateTime.now();
      final current = state.valueOrNull;
      if (current == null || !listEquals(current, items)) {
        state = AsyncData(items);
      }
    } catch (e, st) {
      AppLogger.warning('Background vocabulary sync failed', details: e);
      AppLogger.debug('Stack trace', data: st);
    }
  }

  /// The server's list, built from [base] plus the rows changed since the
  /// cache's cursor when possible, otherwise downloaded in full.
  Future<(List<VocabularyItem>, SyncCursor?)> _fetchFresh(
    CacheService cacheService,
    List<VocabularyItem>? base,
  ) async {
    final repo = ref.read(vocabularyRepositoryProvider);
    final cursor = cacheService.getVocabularySyncCursor();
    if (base != null && cursor != null && !cursor.isExpired) {
      final delta = await deltaSync<VocabularyItem>(
        cached: base,
        since: cursor.updatedUpTo,
        keyOf: (v) => v.id,
        updatedAtOf: (v) => v.updatedAt,
        fetchChanged: repo.getUpdatedSince,
        fetchCount: repo.count,
        fetchKeys: repo.getAllIds,
      );
      if (delta != null) {
        return (
          _newestFirst(delta.items),
          cursor.advancedTo(delta.newestChange),
        );
      }
    }
    final items = await repo.getAll();
    return (items, SyncCursor.afterFullSync(items.map((v) => v.updatedAt)));
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
    ref.read(cacheServiceProvider).scheduleVocabularyList(updatedList);

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
    ref.read(cacheServiceProvider).scheduleVocabularyList(updatedList);

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
    ref.read(cacheServiceProvider).scheduleVocabularyList(updatedList);
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
    ref.read(cacheServiceProvider).scheduleVocabularyList(updatedList);
  }

  /// Pull-to-refresh. Keeps the current list on screen while loading and
  /// rethrows on failure so the caller can tell the user.
  Future<void> refresh() async {
    final previous = state;
    state =
        const AsyncLoading<List<VocabularyItem>>().copyWithPrevious(previous);
    try {
      final items = await ref.read(vocabularyRepositoryProvider).getAll();
      await ref.read(cacheServiceProvider).cacheVocabularyList(
            items,
            syncCursor: SyncCursor.afterFullSync(items.map((v) => v.updatedAt)),
          );
      _lastSyncedAt = DateTime.now();
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

/// Manages the memory states map with cache-first loading, delta sync and
/// optimistic updates (used by the dashboard, deck, word and review screens).
/// Syncing works like [VocabularyNotifier].
class MemoryStatesMapNotifier extends AsyncNotifier<Map<String, MemoryState>>
    with BuildGeneration {
  Object _build = Object();
  Future<void>? _syncing;
  DateTime? _lastSyncedAt;

  @override
  Future<Map<String, MemoryState>> build() async {
    ref.keepAlive();
    final generation = _build = beginGeneration(ref);
    _syncing = null;
    _lastSyncedAt = null;
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};

    final cacheService = ref.watch(cacheServiceProvider);

    final cached = cacheService.getCachedMemoryStates();
    if (cached != null && cached.isNotEmpty) {
      _startSync(cacheService, generation, cached);
      return {for (final s in cached) s.vocabularyId: s};
    }

    final (states, cursor) = await _fetchFresh(cacheService, null);
    await cacheService.cacheMemoryStates(states, syncCursor: cursor);
    _lastSyncedAt = DateTime.now();
    return {for (final s in states) s.vocabularyId: s};
  }

  /// Brings the states up to date with the server and returns them. Same
  /// contract as [VocabularyNotifier.sync].
  Future<Map<String, MemoryState>> sync() async {
    final loaded = await future;
    final last = _lastSyncedAt;
    final recent =
        last != null && DateTime.now().difference(last) < kResyncAfter;
    if (_syncing == null &&
        !recent &&
        ref.read(currentUserIdProvider) != null) {
      _startSync(
        ref.read(cacheServiceProvider),
        _build,
        (state.valueOrNull ?? loaded).values.toList(),
      );
    }
    await _syncing;
    return state.valueOrNull ?? loaded;
  }

  void _startSync(
    CacheService cacheService,
    Object generation,
    List<MemoryState> base,
  ) {
    final run = _syncWithServer(cacheService, generation, base);
    _syncing = run;
    unawaited(run.whenComplete(() {
      if (identical(_syncing, run)) _syncing = null;
    }));
  }

  Future<void> _syncWithServer(
    CacheService cacheService,
    Object generation,
    List<MemoryState> base,
  ) async {
    try {
      final (states, cursor) = await _fetchFresh(cacheService, base);
      if (!isCurrentGeneration(generation)) return;
      await cacheService.cacheMemoryStates(states, syncCursor: cursor);
      _lastSyncedAt = DateTime.now();
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

  Future<(List<MemoryState>, SyncCursor?)> _fetchFresh(
    CacheService cacheService,
    List<MemoryState>? base,
  ) async {
    final repo = ref.read(memoryStateRepositoryProvider);
    final cursor = cacheService.getMemoryStatesSyncCursor();
    if (base != null && cursor != null && !cursor.isExpired) {
      final delta = await deltaSync<MemoryState>(
        cached: base,
        since: cursor.updatedUpTo,
        keyOf: (s) => s.vocabularyId,
        updatedAtOf: (s) => s.updatedAt,
        fetchChanged: repo.getUpdatedSince,
        fetchCount: repo.count,
        fetchKeys: repo.getAllVocabularyIds,
      );
      if (delta != null) {
        return (delta.items, cursor.advancedTo(delta.newestChange));
      }
    }
    final states = await repo.getAll();
    return (states, SyncCursor.afterFullSync(states.map((s) => s.updatedAt)));
  }

  void _set(Map<String, MemoryState> map) {
    state = AsyncData(map);
    ref.read(cacheServiceProvider).scheduleMemoryStates(map.values.toList());
  }

  /// Add a single memory state (used after adding a word).
  void addState(MemoryState memoryState) => updateState(memoryState);

  /// Insert or replace several states at once (one cache write).
  void addStates(Iterable<MemoryState> states) {
    final current = state.valueOrNull;
    if (current == null || states.isEmpty) return;
    _set({...current, for (final s in states) s.vocabularyId: s});
  }

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
      await ref.read(cacheServiceProvider).cacheMemoryStates(
            states,
            syncCursor:
                SyncCursor.afterFullSync(states.map((s) => s.updatedAt)),
          );
      _lastSyncedAt = DateTime.now();
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
