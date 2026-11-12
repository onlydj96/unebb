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
