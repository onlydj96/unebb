import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';

/// Keys for SharedPreferences storage.
abstract class CacheKeys {
  static const String profile = 'cached_profile';
  static const String vocabularyList = 'cached_vocabulary_list';
  static const String memoryStates = 'cached_memory_states';
  static const String deckList = 'cached_deck_list';
  static const String vocabularySync = 'vocabulary_sync_cursor';
  static const String memoryStatesSync = 'memory_states_sync_cursor';
  static const String reviewSessionProgress = 'review_session_progress';
  static const String pendingMemoryStates = 'pending_memory_states';

  /// ID of the user the cached data belongs to.
  static const String owner = 'cache_owner_id';

  /// Every key holding user-owned data.
  static const List<String> userScoped = [
    profile,
    vocabularyList,
    memoryStates,
    deckList,
    vocabularySync,
    memoryStatesSync,
    reviewSessionProgress,
    pendingMemoryStates,
  ];
}

/// How far a cached list is known to match the server.
///
/// Delta sync downloads only rows whose server `updated_at` is at or after
/// [updatedUpTo] (minus a small overlap). A full download is still forced
/// once [fullSyncInterval] has passed since [fullSyncAt], as a safety net
/// against any divergence a delta cannot see.
class SyncCursor {
  const SyncCursor({required this.updatedUpTo, required this.fullSyncAt});

  /// Cursor for a list that was just downloaded in full, or null when the
  /// list is empty (nothing to anchor a delta on).
  static SyncCursor? afterFullSync(Iterable<DateTime> updatedAts) {
    final newest = latest(updatedAts);
    if (newest == null) return null;
    return SyncCursor(updatedUpTo: newest, fullSyncAt: DateTime.now().toUtc());
  }

  static DateTime? latest(Iterable<DateTime> values) {
    DateTime? newest;
    for (final value in values) {
      if (newest == null || value.isAfter(newest)) newest = value;
    }
    return newest;
  }

  static const Duration fullSyncInterval = Duration(hours: 24);

  /// Newest server `updated_at` contained in the cached list.
  final DateTime updatedUpTo;

  /// When the cached list was last replaced by a full download.
  final DateTime fullSyncAt;

  /// True when a full download is due (also when the clock moved backwards).
  bool get isExpired {
    final age = DateTime.now().toUtc().difference(fullSyncAt);
    return age.isNegative || age > fullSyncInterval;
  }

  /// This cursor moved forward to include rows changed up to [newest].
  SyncCursor advancedTo(DateTime? newest) =>
      newest == null || !newest.isAfter(updatedUpTo)
          ? this
          : SyncCursor(updatedUpTo: newest, fullSyncAt: fullSyncAt);

  Map<String, dynamic> toJson() => {
        'updated_up_to': updatedUpTo.toUtc().toIso8601String(),
        'full_sync_at': fullSyncAt.toUtc().toIso8601String(),
      };

  factory SyncCursor.fromJson(Map<String, dynamic> json) => SyncCursor(
        updatedUpTo: DateTime.parse(json['updated_up_to'] as String),
        fullSyncAt: DateTime.parse(json['full_sync_at'] as String),
      );
}

/// Cached review session progress for resuming interrupted sessions.
class ReviewSessionProgress {
  const ReviewSessionProgress({
    required this.mode,
    this.deckId,
    this.limit,
    required this.vocabularyIds,
    required this.currentIndex,
    required this.correctCount,
    required this.savedAt,
    this.completedBefore = 0,
  });

  final String mode;
  final String? deckId;
  final int? limit;

  /// Words of the (possibly already resumed) session, in review order.
  final List<String> vocabularyIds;

  /// Index of the first word in [vocabularyIds] that still needs a review.
  final int currentIndex;

  /// Correct answers across the whole session, including earlier resumes.
  final int correctCount;
  final DateTime savedAt;

  /// Words finished in earlier parts of the session that are no longer in
  /// [vocabularyIds] (non-zero after resuming more than once).
  final int completedBefore;

  int get remainingCount => vocabularyIds.length - currentIndex;
  int get completedCount => completedBefore + currentIndex;
  int get totalCount => completedBefore + vocabularyIds.length;

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'deck_id': deckId,
        'limit': limit,
        'vocabulary_ids': vocabularyIds,
        'current_index': currentIndex,
        'correct_count': correctCount,
        'completed_before': completedBefore,
        'saved_at': savedAt.toIso8601String(),
      };

  factory ReviewSessionProgress.fromJson(Map<String, dynamic> json) {
    return ReviewSessionProgress(
      mode: json['mode'] as String,
      deckId: json['deck_id'] as String?,
      limit: json['limit'] as int?,
      vocabularyIds: (json['vocabulary_ids'] as List<dynamic>).cast<String>(),
      currentIndex: json['current_index'] as int,
      correctCount: json['correct_count'] as int,
      completedBefore: json['completed_before'] as int? ?? 0,
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }

  /// Check if this progress matches the given session parameters.
  bool matchesSession({String mode = 'due', int? limit, String? deckId}) {
    return this.mode == mode && this.deckId == deckId;
  }

  /// Check if the saved progress is still valid (not too old).
  bool get isValid {
    final age = DateTime.now().difference(savedAt);
    // Progress expires after 24 hours
    return age.inHours < 24;
  }
}

/// Service for managing local cache with SharedPreferences.
///
/// Lists are stored as one JSON string each. Writes caused by single-item
/// edits go through [scheduleVocabularyList] / [scheduleMemoryStates], which
/// coalesce a burst of edits (e.g. grading words in a review) into one
/// encode + write after [writeDelay]. A lost deferred write is harmless: the
/// next delta sync downloads every row changed on the server since the
/// cursor again.
class CacheService {
  CacheService(this._prefs, {this.writeDelay = const Duration(seconds: 1)});

  final SharedPreferences _prefs;
  final Duration writeDelay;

  final Map<String, String Function()> _pendingWrites = {};
  final Map<String, Timer> _pendingTimers = {};

  void _scheduleWrite(String key, String Function() encode) {
    _pendingWrites[key] = encode;
    _pendingTimers.remove(key)?.cancel();
    _pendingTimers[key] = Timer(writeDelay, () => unawaited(_flushKey(key)));
  }

  void _cancelWrite(String key) {
    _pendingTimers.remove(key)?.cancel();
    _pendingWrites.remove(key);
  }

  Future<void> _flushKey(String key) async {
    _pendingTimers.remove(key)?.cancel();
    final encode = _pendingWrites.remove(key);
    if (encode != null) await _prefs.setString(key, encode());
  }

  /// Writes every deferred update now.
  Future<void> flush() => Future.wait([
        for (final key in [..._pendingWrites.keys]) _flushKey(key)
      ]);

  /// Drops deferred writes. Called when the account changes: they hold the
  /// previous account's data and must never reach the new account's cache.
  void dispose() {
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _pendingWrites.clear();
  }

  SyncCursor? _readCursor(String key) {
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return null;
    try {
      return SyncCursor.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCursor(String key, SyncCursor? cursor) => cursor == null
      ? _prefs.remove(key)
      : _prefs.setString(key, jsonEncode(cursor.toJson()));

  // ─────────────────────────────────────────────────────────────────────────
  // Ownership
  // ─────────────────────────────────────────────────────────────────────────

  /// Ties the cache to [userId].
  ///
  /// If the cached data belongs to someone else — or the user signed out
  /// ([userId] is null) — every user-owned entry is dropped so one account
  /// never sees another account's words, decks or review progress.
  ///
  /// SharedPreferences updates its in-memory copy synchronously, so reads
  /// right after this call already see the cleared state.
  void bindToUser(String? userId) {
    final owner = _prefs.getString(CacheKeys.owner);
    if (owner == userId) return;
    for (final key in CacheKeys.userScoped) {
      unawaited(_prefs.remove(key));
    }
    unawaited(
      userId == null
          ? _prefs.remove(CacheKeys.owner)
          : _prefs.setString(CacheKeys.owner, userId),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profile Cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> cacheProfile(UserProfile profile) async {
    final json = {
      'id': profile.id,
      'display_name': profile.displayName,
      'native_language': profile.nativeLanguage,
      'learning_language': profile.learningLanguage,
    };
    await _prefs.setString(CacheKeys.profile, jsonEncode(json));
  }

  UserProfile? getCachedProfile() {
    final jsonStr = _prefs.getString(CacheKeys.profile);
    if (jsonStr == null) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearProfile() async {
    await _prefs.remove(CacheKeys.profile);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Vocabulary Cache
  // ─────────────────────────────────────────────────────────────────────────

  /// Stores the list now, replacing any deferred write.
  ///
  /// [syncCursor] records how far [items] match the server; without one the
  /// next sync downloads everything.
  Future<void> cacheVocabularyList(
    List<VocabularyItem> items, {
    SyncCursor? syncCursor,
  }) async {
    _cancelWrite(CacheKeys.vocabularyList);
    final jsonList = items.map((e) => e.toJson()).toList();
    await Future.wait([
      _prefs.setString(CacheKeys.vocabularyList, jsonEncode(jsonList)),
      _writeCursor(CacheKeys.vocabularySync, syncCursor),
    ]);
  }

  /// Stores the list after [writeDelay]; a newer call replaces this one.
  /// The sync cursor is kept: local edits mirror rows already saved on the
  /// server.
  void scheduleVocabularyList(List<VocabularyItem> items) {
    _scheduleWrite(
      CacheKeys.vocabularyList,
      () => jsonEncode([for (final item in items) item.toJson()]),
    );
  }

  SyncCursor? getVocabularySyncCursor() =>
      _readCursor(CacheKeys.vocabularySync);

  List<VocabularyItem>? getCachedVocabularyList() {
    final jsonStr = _prefs.getString(CacheKeys.vocabularyList);
    if (jsonStr == null) return null;
    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Memory States Cache
  // ─────────────────────────────────────────────────────────────────────────

  /// Stores the states now, replacing any deferred write (see
  /// [cacheVocabularyList]).
  Future<void> cacheMemoryStates(
    List<MemoryState> states, {
    SyncCursor? syncCursor,
  }) async {
    _cancelWrite(CacheKeys.memoryStates);
    final jsonList = states.map((e) => e.toJson()).toList();
    await Future.wait([
      _prefs.setString(CacheKeys.memoryStates, jsonEncode(jsonList)),
      _writeCursor(CacheKeys.memoryStatesSync, syncCursor),
    ]);
  }

  /// Stores the states after [writeDelay]; a newer call replaces this one.
  void scheduleMemoryStates(List<MemoryState> states) {
    _scheduleWrite(
      CacheKeys.memoryStates,
      () => jsonEncode([for (final state in states) state.toJson()]),
    );
  }

  SyncCursor? getMemoryStatesSyncCursor() =>
      _readCursor(CacheKeys.memoryStatesSync);

  List<MemoryState>? getCachedMemoryStates() =>
      _readMemoryStates(CacheKeys.memoryStates);

  List<MemoryState>? _readMemoryStates(String key) {
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return null;
    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => MemoryState.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pending Memory States (reviews not saved to the server yet)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reviewed states whose save failed (offline, server error), at most one
  /// per word. They are saved by the next memory-state sync and shown
  /// instead of the server's copy until then, so the progress is not lost.
  List<MemoryState> getPendingMemoryStates() =>
      _readMemoryStates(CacheKeys.pendingMemoryStates) ?? const [];

  /// Queues [state], replacing an older pending review of the same word.
  Future<void> addPendingMemoryState(MemoryState state) => _writePending([
        for (final s in getPendingMemoryStates())
          if (s.vocabularyId != state.vocabularyId) s,
        state,
      ]);

  /// Removes [settled] entries; a newer review of the same word queued in
  /// the meantime stays.
  Future<void> removePendingMemoryStates(Iterable<MemoryState> settled) {
    if (settled.isEmpty) return Future.value();
    final done = settled.toSet();
    return _writePending([
      for (final s in getPendingMemoryStates())
        if (!done.contains(s)) s,
    ]);
  }

  Future<void> _writePending(List<MemoryState> states) => states.isEmpty
      ? _prefs.remove(CacheKeys.pendingMemoryStates)
      : _prefs.setString(
          CacheKeys.pendingMemoryStates,
          jsonEncode([for (final s in states) s.toJson()]),
        );

  // ─────────────────────────────────────────────────────────────────────────
  // Deck Cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> cacheDeckList(List<Deck> decks) async {
    final jsonList = decks.map((e) => e.toJson()).toList();
    await _prefs.setString(CacheKeys.deckList, jsonEncode(jsonList));
  }

  List<Deck>? getCachedDeckList() {
    final jsonStr = _prefs.getString(CacheKeys.deckList);
    if (jsonStr == null) return null;
    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => Deck.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Review Session Progress Cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveReviewProgress(ReviewSessionProgress progress) async {
    await _prefs.setString(
      CacheKeys.reviewSessionProgress,
      jsonEncode(progress.toJson()),
    );
  }

  ReviewSessionProgress? getReviewProgress() {
    final jsonStr = _prefs.getString(CacheKeys.reviewSessionProgress);
    if (jsonStr == null) return null;
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final progress = ReviewSessionProgress.fromJson(json);
      // Return null if progress is expired
      if (!progress.isValid) {
        clearReviewProgress();
        return null;
      }
      return progress;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearReviewProgress() async {
    await _prefs.remove(CacheKeys.reviewSessionProgress);
  }

  /// Check if there's a saved progress that matches the given session parameters.
  ReviewSessionProgress? getMatchingReviewProgress({
    String mode = 'due',
    int? limit,
    String? deckId,
  }) {
    final progress = getReviewProgress();
    if (progress == null) return null;
    if (!progress.matchesSession(mode: mode, limit: limit, deckId: deckId)) {
      return null;
    }
    return progress;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Clear All Cache
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    dispose();
    await Future.wait([
      for (final key in CacheKeys.userScoped) _prefs.remove(key),
      _prefs.remove(CacheKeys.owner),
    ]);
  }
}

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  );
});

/// Provider for CacheService, bound to the signed-in user.
///
/// Rebuilds when the account changes; [CacheService.bindToUser] then wipes the
/// previous account's data before anything reads it.
final cacheServiceProvider = Provider<CacheService>((ref) {
  final service = CacheService(ref.watch(sharedPreferencesProvider));
  ref.onDispose(service.dispose);
  service.bindToUser(ref.watch(currentUserIdProvider));
  return service;
});
