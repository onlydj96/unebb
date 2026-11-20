import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unebb/core/services/cache_service.dart';

import '../helpers/fakes.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('CacheService.bindToUser', () {
    test('keeps data that belongs to the same user', () async {
      final cache = CacheService(prefs)..bindToUser('user-a');
      await cache.cacheVocabularyList([vocab('a1', userId: 'user-a')]);

      CacheService(prefs).bindToUser('user-a');

      expect(CacheService(prefs).getCachedVocabularyList(), hasLength(1));
    });

    test('drops the previous user\'s data when another user signs in',
        () async {
      final cache = CacheService(prefs)..bindToUser('user-a');
      await cache.cacheVocabularyList([vocab('a1', userId: 'user-a')]);
      await cache.cacheDeckList([deck('d1')]);
      await cache.cacheMemoryStates([memory('a1', userId: 'user-a')]);

      final next = CacheService(prefs)..bindToUser('user-b');

      expect(next.getCachedVocabularyList(), isNull);
      expect(next.getCachedDeckList(), isNull);
      expect(next.getCachedMemoryStates(), isNull);
    });

    test('drops everything on sign-out', () async {
      final cache = CacheService(prefs)..bindToUser('user-a');
      await cache.saveReviewProgress(ReviewSessionProgress(
        mode: 'due',
        vocabularyIds: const ['a1', 'a2'],
        currentIndex: 1,
        correctCount: 1,
        savedAt: DateTime.now(),
      ));

      final signedOut = CacheService(prefs)..bindToUser(null);

      expect(signedOut.getReviewProgress(), isNull);
      expect(prefs.getString(CacheKeys.owner), isNull);
    });
  });

  group('CacheService deferred writes', () {
    const delay = Duration(milliseconds: 5);
    Future<void> afterDelay() =>
        Future<void>.delayed(delay + const Duration(milliseconds: 50));

    test('a burst of edits is written once, with the latest list', () async {
      final cache = CacheService(prefs, writeDelay: delay)
        ..bindToUser(kTestUserId);

      cache.scheduleVocabularyList([vocab('a')]);
      cache.scheduleVocabularyList([vocab('a'), vocab('b')]);
      expect(cache.getCachedVocabularyList(), isNull);

      await afterDelay();
      expect(cache.getCachedVocabularyList()!.map((v) => v.id), ['a', 'b']);
    });

    test('flush writes pending edits immediately', () async {
      final cache = CacheService(prefs, writeDelay: const Duration(hours: 1));

      cache.scheduleMemoryStates([memory('a')]);
      await cache.flush();

      expect(cache.getCachedMemoryStates(), hasLength(1));
    });

    test('a direct write replaces a pending one', () async {
      final cache = CacheService(prefs, writeDelay: delay);

      cache.scheduleVocabularyList([vocab('old')]);
      await cache.cacheVocabularyList([vocab('new')]);
      await afterDelay();

      expect(cache.getCachedVocabularyList()!.single.id, 'new');
    });

    test('dispose drops pending writes (account switch)', () async {
      final cache = CacheService(prefs, writeDelay: delay)
        ..bindToUser('user-a');

      cache.scheduleVocabularyList([vocab('a1', userId: 'user-a')]);
      cache.dispose();
      final next = CacheService(prefs)..bindToUser('user-b');
      await afterDelay();

      expect(next.getCachedVocabularyList(), isNull);
    });
  });

  group('SyncCursor', () {
    final cursor = SyncCursor(
      updatedUpTo: DateTime.utc(2026, 1, 15),
      fullSyncAt: DateTime.now().toUtc(),
    );

    test('is stored with a synced list and cleared by an unsynced write',
        () async {
      final cache = CacheService(prefs);

      await cache.cacheVocabularyList([vocab('a')], syncCursor: cursor);
      expect(cache.getVocabularySyncCursor()!.updatedUpTo, cursor.updatedUpTo);

      await cache.cacheVocabularyList([vocab('a')]);
      expect(cache.getVocabularySyncCursor(), isNull);
    });

    test('scheduled writes keep the cursor', () async {
      final cache = CacheService(prefs, writeDelay: Duration.zero);

      await cache.cacheMemoryStates([memory('a')], syncCursor: cursor);
      cache.scheduleMemoryStates([memory('a'), memory('b')]);
      await cache.flush();

      expect(cache.getMemoryStatesSyncCursor(), isNotNull);
    });

    test('is dropped when another user signs in', () async {
      final cache = CacheService(prefs)..bindToUser('user-a');
      await cache.cacheMemoryStates([memory('a')], syncCursor: cursor);

      final next = CacheService(prefs)..bindToUser('user-b');

      expect(next.getMemoryStatesSyncCursor(), isNull);
    });

    test('expires a day after the last full download', () {
      expect(cursor.isExpired, isFalse);
      final old = SyncCursor(
        updatedUpTo: cursor.updatedUpTo,
        fullSyncAt: DateTime.now().toUtc().subtract(const Duration(hours: 25)),
      );
      expect(old.isExpired, isTrue);
    });

    test('only moves forward', () {
      final later = DateTime.utc(2026, 2, 1);
      expect(cursor.advancedTo(later).updatedUpTo, later);
      expect(
        cursor.advancedTo(DateTime.utc(2026, 1, 1)).updatedUpTo,
        cursor.updatedUpTo,
      );
      expect(cursor.advancedTo(null), same(cursor));
    });
  });

  group('pending memory states', () {
    final reviewed = DateTime.utc(2026, 11, 20, 9);

    test('keep the newest review per word', () async {
      final cache = CacheService(prefs);
      await cache.addPendingMemoryState(
          memory('a', reviewCount: 1, lastReviewedAt: reviewed));
      await cache.addPendingMemoryState(memory('b', reviewCount: 1));
      await cache.addPendingMemoryState(memory('a', reviewCount: 2));

      final pending = CacheService(prefs).getPendingMemoryStates();
      expect(pending.map((s) => (s.vocabularyId, s.reviewCount)),
          unorderedEquals([('a', 2), ('b', 1)]));
    });

    test('removing settled entries keeps a newer review of the same word',
        () async {
      final cache = CacheService(prefs);
      await cache.addPendingMemoryState(memory('a', reviewCount: 1));
      await cache.addPendingMemoryState(memory('b', reviewCount: 1));
      final settled = cache.getPendingMemoryStates();
      await cache.addPendingMemoryState(memory('a', reviewCount: 2));

      await cache.removePendingMemoryStates(settled);

      final pending = cache.getPendingMemoryStates();
      expect(pending.single.vocabularyId, 'a');
      expect(pending.single.reviewCount, 2);
    });

    test('are dropped when another user signs in', () async {
      final cache = CacheService(prefs)..bindToUser('user-a');
      await cache.addPendingMemoryState(memory('a', userId: 'user-a'));

      final next = CacheService(prefs)..bindToUser('user-b');

      expect(next.getPendingMemoryStates(), isEmpty);
    });
  });

  group('ReviewSessionProgress', () {
    test('round-trips through JSON including earlier progress', () {
      final progress = ReviewSessionProgress(
        mode: 'all',
        deckId: 'deck-1',
        limit: 10,
        vocabularyIds: const ['a', 'b', 'c'],
        currentIndex: 1,
        correctCount: 4,
        completedBefore: 5,
        savedAt: DateTime.utc(2026, 11, 9),
      );

      final restored = ReviewSessionProgress.fromJson(progress.toJson());

      expect(restored.completedCount, 6);
      expect(restored.totalCount, 8);
      expect(restored.remainingCount, 2);
      expect(restored.correctCount, 4);
    });

    test('reads progress saved by older app versions', () {
      final restored = ReviewSessionProgress.fromJson({
        'mode': 'due',
        'deck_id': null,
        'limit': null,
        'vocabulary_ids': ['a', 'b'],
        'current_index': 1,
        'correct_count': 1,
        'saved_at': DateTime.utc(2026, 11, 9).toIso8601String(),
      });

      expect(restored.completedBefore, 0);
      expect(restored.completedCount, 1);
    });
  });
}
