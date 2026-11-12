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
  static const String lastSyncTime = 'last_sync_time';
  static const String reviewSessionProgress = 'review_session_progress';

  /// ID of the user the cached data belongs to.
  static const String owner = 'cache_owner_id';

  /// Every key holding user-owned data.
  static const List<String> userScoped = [
    profile,
    vocabularyList,
    memoryStates,
    deckList,
    lastSyncTime,
    reviewSessionProgress,
  ];
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
class CacheService {
  CacheService(this._prefs);

  final SharedPreferences _prefs;

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

  Future<void> cacheVocabularyList(List<VocabularyItem> items) async {
    final jsonList = items.map((e) => e.toJson()).toList();
    await _prefs.setString(CacheKeys.vocabularyList, jsonEncode(jsonList));
  }

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

  Future<void> cacheMemoryStates(List<MemoryState> states) async {
    final jsonList = states.map((e) => e.toJson()).toList();
    await _prefs.setString(CacheKeys.memoryStates, jsonEncode(jsonList));
  }

  List<MemoryState>? getCachedMemoryStates() {
    final jsonStr = _prefs.getString(CacheKeys.memoryStates);
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
  // Sync Timestamp
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> updateLastSyncTime() async {
    await _prefs.setInt(
      CacheKeys.lastSyncTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  DateTime? getLastSyncTime() {
    final ms = _prefs.getInt(CacheKeys.lastSyncTime);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Returns true if cache is stale (older than [maxAge]).
  bool isCacheStale({Duration maxAge = const Duration(minutes: 5)}) {
    final lastSync = getLastSyncTime();
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
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
  service.bindToUser(ref.watch(currentUserIdProvider));
  return service;
});
