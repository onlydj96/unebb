// Flow tests for vocabulary, AI content and deck providers.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/vocabulary/providers/ai_content_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

import '../../helpers/fakes.dart';

final _userProvider = StateProvider<String?>((ref) => 'user-a');

class _Env {
  _Env({List<VocabularyItem> words = const []}) {
    vocabRepo = FakeVocabularyRepository(words);
    explanationService = FakeAiExplanationService(vocabRepo);
  }

  late final FakeVocabularyRepository vocabRepo;
  late final FakeAiExplanationService explanationService;
  final memRepo = FakeMemoryStateRepository();
  final deckRepo = FakeDeckRepository([deck('d1'), deck('d2')]);

  Future<ProviderContainer> container({
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
      vocabularyRepositoryProvider.overrideWithValue(vocabRepo),
      memoryStateRepositoryProvider.overrideWithValue(memRepo),
      deckRepositoryProvider.overrideWithValue(deckRepo),
      aiExplanationServiceProvider.overrideWithValue(explanationService),
      profileProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(c.dispose);
    c.listen(vocabularyNotifierProvider, (_, __) {});
    c.listen(aiContentProvider, (_, __) {});
    return c;
  }
}

VocabularyNotifier _vocab(ProviderContainer c) =>
    c.read(vocabularyNotifierProvider.notifier);

void main() {
  group('adding words', () {
    test('rejects a case-insensitive duplicate in the same deck locally',
        () async {
      final env = _Env(words: [vocab('a', word: 'Ephemeral', deckId: 'd1')]);
      final c = await env.container();
      await c.read(vocabularyNotifierProvider.future);
      final before = env.vocabRepo.items.length;

      await expectLater(
        _vocab(c)
            .addWord(word: '  ephemeral ', language: 'English', deckId: 'd1'),
        throwsA(isA<DuplicateWordException>()
            .having((e) => e.existingDeckId, 'existingDeckId', 'd1')),
      );
      expect(env.vocabRepo.items, hasLength(before));
    });

    test('maps a database unique violation to DuplicateWordException',
        () async {
      final env = _Env(words: [vocab('a', word: 'ephemeral', deckId: 'd1')]);
      env.vocabRepo.createError = uniqueViolation();
      final c = await env.container();
      await c.read(vocabularyNotifierProvider.future);

      await expectLater(
        _vocab(c).addWord(word: 'ephemeral', language: 'English', deckId: 'd2'),
        throwsA(isA<DuplicateWordException>()
            .having((e) => e.existingDeckId, 'existingDeckId', 'd1')),
      );
    });

    test('new word appears immediately and gets AI content in the background',
        () async {
      final env = _Env();
      final c = await env.container();
      await c.read(vocabularyNotifierProvider.future);

      final id =
          await _vocab(c).addWord(word: 'ubiquitous', language: 'English');

      expect(c.read(vocabularyNotifierProvider).requireValue.first.id, id);
      expect(c.read(aiContentProvider)[id], AiContentStatus.generating);
      await pumpEventQueue();

      final added = c
          .read(vocabularyNotifierProvider)
          .requireValue
          .firstWhere((v) => v.id == id);
      expect(hasAiContent(added), isTrue);
      expect(c.read(aiContentProvider)[id], isNull);
      expect(env.memRepo.states.single.vocabularyId, id);
    });

    test('word counts on decks follow added words without a refetch', () async {
      final env = _Env();
      final c = await env.container();
      c.listen(deckListProvider, (_, __) {});
      await c.read(vocabularyNotifierProvider.future);
      await c.read(deckNotifierProvider.future);

      await _vocab(c).addWord(word: 'one', language: 'English', deckId: 'd1');
      await _vocab(c).addWord(word: 'two', language: 'English', deckId: 'd1');

      final d1 = c.read(deckByIdProvider('d1')).requireValue!;
      expect(d1.wordCount, 2);
    });
  });

  group('AI content', () {
    test('concurrent requests for one word share a single generation',
        () async {
      final env =
          _Env(words: [vocab('a', definition: null, explanation: null)]);
      final gate = Completer<void>();
      env.explanationService.gate = gate;
      final c = await env.container();
      final item = (await c.read(vocabularyNotifierProvider.future)).single;

      final first = c.read(aiContentProvider.notifier).ensure(item);
      final second = c.read(aiContentProvider.notifier).ensure(item);
      gate.complete();
      await Future.wait([first, second]);

      expect(env.explanationService.calls, ['a']);
    });

    test('a failure is reported and can be retried', () async {
      final env =
          _Env(words: [vocab('a', definition: null, explanation: null)]);
      env.explanationService.error = Exception('timeout');
      final c = await env.container();
      final item = (await c.read(vocabularyNotifierProvider.future)).single;

      expect(await c.read(aiContentProvider.notifier).ensure(item), isNull);
      expect(c.read(aiContentProvider)['a'], AiContentStatus.failed);

      env.explanationService.error = null;
      final retried = await c.read(aiContentProvider.notifier).ensure(item);

      expect(retried?.definition, isNotNull);
      expect(c.read(aiContentProvider)['a'], isNull);
      expect(
        hasAiContent(c.read(vocabularyNotifierProvider).requireValue.single),
        isTrue,
      );
    });
  });

  group('editing words', () {
    test('changing the spelling clears stale AI content and regenerates it',
        () async {
      final env = _Env(words: [vocab('a', word: 'affect')]);
      final c = await env.container();
      final item = (await c.read(vocabularyNotifierProvider.future)).single;

      final saved = await _vocab(c).updateWord(item.copyWith(word: 'effect'));

      expect(saved.definition, isNull);
      await pumpEventQueue();
      expect(env.explanationService.calls, ['a']);
      final current = c.read(vocabularyNotifierProvider).requireValue.single;
      expect(current.word, 'effect');
      expect(current.definition, contains('effect'));
    });

    test('word detail reflects edits without waiting for a refetch', () async {
      final env = _Env(words: [vocab('a', word: 'affect')]);
      final c = await env.container();
      c.listen(vocabularyItemProvider('a'), (_, __) {});
      final item = (await c.read(vocabularyItemProvider('a').future))!;

      await _vocab(c).updateWord(item.copyWith(language: 'French'));

      expect((await c.read(vocabularyItemProvider('a').future))!.language,
          'French');
    });

    test('renaming while the old explanation is generating regenerates it',
        () async {
      final env = _Env(words: [
        vocab('a', word: 'affect', definition: null, explanation: null),
      ]);
      final gate = Completer<void>();
      env.explanationService.gate = gate;
      final c = await env.container();
      final item = (await c.read(vocabularyNotifierProvider.future)).single;

      // Generation for the old spelling is in flight…
      unawaited(c.read(aiContentProvider.notifier).ensure(item));
      await pumpEventQueue();
      // …when the learner fixes the spelling.
      await _vocab(c).updateWord(item.copyWith(word: 'effect'));
      gate.complete();
      await pumpEventQueue();

      expect(env.explanationService.calls, ['a', 'a']);
      final current = c.read(vocabularyNotifierProvider).requireValue.single;
      expect(current.word, 'effect');
      expect(current.definition, 'generated definition of effect');
    });

    test('a save from a stale edit screen keeps AI content that arrived since',
        () async {
      final env = _Env(words: [vocab('a', word: 'affect')]);
      final c = await env.container();
      final latest = (await c.read(vocabularyNotifierProvider.future)).single;
      // The edit screen opened before the AI content existed.
      final snapshot = latest.copyWith(definition: null, explanation: null);

      // Capitalisation only: same word, so no regeneration.
      final saved =
          await _vocab(c).updateWord(snapshot.copyWith(word: 'Affect'));

      expect(saved.word, 'Affect');
      expect(saved.definition, latest.definition);
      expect(env.explanationService.calls, isEmpty);
    });
  });

  group('cache', () {
    test('background sync replaces a stale cached list', () async {
      final stale = vocab('a', definition: null, explanation: null);
      final fresh = vocab('a', definition: 'fresh definition');
      final env = _Env(words: [fresh]);
      SharedPreferences.setMockInitialValues({});
      final seed = await SharedPreferences.getInstance();
      final seeded = CacheService(seed)..bindToUser('user-a');
      await seeded.cacheVocabularyList([stale]);

      final c = await env.container(prefsValues: {
        CacheKeys.owner: 'user-a',
        CacheKeys.vocabularyList: seed.getString(CacheKeys.vocabularyList)!,
      });

      // Cached copy first…
      expect(
          (await c.read(vocabularyNotifierProvider.future)).single.definition,
          isNull);
      await pumpEventQueue();
      // …then the server copy.
      expect(c.read(vocabularyNotifierProvider).requireValue.single.definition,
          'fresh definition');
    });

    test('another account never sees the previous account\'s words', () async {
      final env = _Env(words: [vocab('a1', word: 'secret', userId: 'user-a')]);
      final c = await env.container();
      expect(await c.read(vocabularyNotifierProvider.future), hasLength(1));

      // User A signs out, user B signs in on the same device.
      env.vocabRepo.items
        ..clear()
        ..add(vocab('b1', word: 'mine', userId: 'user-b'));
      c.read(_userProvider.notifier).state = null;
      c.read(_userProvider.notifier).state = 'user-b';

      final words = await c.read(vocabularyNotifierProvider.future);
      expect(words.map((w) => w.word), ['mine']);
      expect(
        c.read(cacheServiceProvider).getCachedVocabularyList()!.single.word,
        'mine',
      );
    });
  });

  group('decks', () {
    test('deleting a deck removes its words from the local list', () async {
      final env = _Env(words: [
        vocab('a', deckId: 'd1'),
        vocab('b', deckId: 'd2'),
      ]);
      final c = await env.container();
      await c.read(vocabularyNotifierProvider.future);
      await c.read(deckNotifierProvider.future);

      await c.read(deckNotifierProvider.notifier).deleteDeck('d1');

      expect(
        c.read(vocabularyNotifierProvider).requireValue.map((v) => v.id),
        ['b'],
      );
    });

    test('a duplicate deck name gives a friendly error', () async {
      final env = _Env();
      final c = await env.container();
      await c.read(deckNotifierProvider.future);

      await expectLater(
        c
            .read(deckNotifierProvider.notifier)
            .createDeck(name: 'deck D1 ', language: 'English'),
        throwsA(isA<DuplicateDeckException>()),
      );

      env.deckRepo.createError = uniqueViolation();
      await expectLater(
        c
            .read(deckNotifierProvider.notifier)
            .createDeck(name: 'Brand new', language: 'English'),
        throwsA(isA<DuplicateDeckException>()),
      );
    });
  });
}
