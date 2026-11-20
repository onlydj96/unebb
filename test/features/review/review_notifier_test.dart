// Flow tests for ReviewNotifier: drives the real state machine against
// in-memory fakes (no Supabase, no network).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/review/providers/review_providers.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

import '../../helpers/fakes.dart';

class _Env {
  _Env({
    required List<String> ids,
    Map<String, String?> definitions = const {},
  }) {
    vocabRepo = FakeVocabularyRepository([
      for (final id in ids)
        vocab(
          id,
          definition:
              definitions.containsKey(id) ? definitions[id] : 'meaning of $id',
          explanation: definitions.containsKey(id) && definitions[id] == null
              ? null
              : 'explanation of $id',
        ),
    ]);
    memRepo = FakeMemoryStateRepository([for (final id in ids) memory(id)]);
    explanationService = FakeAiExplanationService(vocabRepo);
  }

  late final FakeVocabularyRepository vocabRepo;
  late final FakeMemoryStateRepository memRepo;
  final reviewRepo = FakeReviewRepository();
  final patternRepo = FakeErrorPatternRepository();
  final evalService = FakeAiEvaluationService();
  final questionService = FakeAiQuestionService();
  late final FakeAiExplanationService explanationService;

  /// When set, loading the profile throws this (e.g. offline, no cache).
  Object? profileError;
  int profileLoads = 0;

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserIdProvider.overrideWithValue(kTestUserId),
      vocabularyRepositoryProvider.overrideWithValue(vocabRepo),
      memoryStateRepositoryProvider.overrideWithValue(memRepo),
      reviewRepositoryProvider.overrideWithValue(reviewRepo),
      errorPatternRepositoryProvider.overrideWithValue(patternRepo),
      aiEvaluationServiceProvider.overrideWithValue(evalService),
      aiQuestionServiceProvider.overrideWithValue(questionService),
      aiExplanationServiceProvider.overrideWithValue(explanationService),
      profileProvider.overrideWith((ref) async {
        profileLoads++;
        final error = profileError;
        if (error != null) throw error;
        return const UserProfile(
          id: kTestUserId,
          displayName: 'Tester',
          nativeLanguage: 'Japanese',
          learningLanguage: 'English',
        );
      }),
    ]);
    addTearDown(container.dispose);
    return container;
  }
}

/// Keeps the auto-disposed review notifier alive for the whole test.
ReviewNotifier _notifier(ProviderContainer c) {
  c.listen(reviewNotifierProvider, (_, __) {});
  return c.read(reviewNotifierProvider.notifier);
}

ReviewUiState _state(ProviderContainer c) => c.read(reviewNotifierProvider);

void main() {
  group('ReviewNotifier', () {
    test('a double tap on "next" advances exactly one word', () async {
      final env = _Env(ids: ['a', 'b', 'c']);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      expect(_state(c).phase, ReviewPhase.showWord);

      n.tapWord();
      await n.answerDontKnowWord();
      expect(_state(c).phase, ReviewPhase.showExplanation);

      // Both taps land before the first one finishes (AnimatedSwitcher keeps
      // the outgoing view tappable for 250ms).
      await Future.wait([n.nextAfterExplanation(), n.nextAfterExplanation()]);

      expect(_state(c).currentIndex, 1);
      expect(_state(c).phase, ReviewPhase.showWord);
    });

    test('duplicate meaning submissions trigger one evaluation', () async {
      final env = _Env(ids: ['a']);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await Future.wait([n.submitMeaning('x'), n.submitMeaning('x')]);

      expect(
        env.evalService.calls.where((call) => call.evalType == 'meaning'),
        hasLength(1),
      );
    });

    test('"don\'t know" survives a rejected history insert', () async {
      final env = _Env(ids: ['a', 'b']);
      env.reviewRepo.addResultError = checkViolation();
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      await expectLater(n.answerDontKnowWord(), completes);

      expect(_state(c).phase, ReviewPhase.showExplanation);
      // The memory state (the part that drives scheduling) is still saved.
      expect(env.memRepo.updates.single.incorrectCount, 1);
    });

    test('"don\'t know" is recorded as a knowledge skip', () async {
      final env = _Env(ids: ['a']);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      await n.answerDontKnowWord();

      final result = env.reviewRepo.results.single;
      expect(result.answerType, 'skip');
      expect(result.questionType, 'knowledge');
    });

    test('a failed meaning answer is shown even if the DB rejects history',
        () async {
      final env = _Env(ids: ['a']);
      env.evalService.meaningScore = 0.2;
      env.reviewRepo.addResultError = checkViolation();
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('wrong');

      expect(_state(c).phase, ReviewPhase.meaningFailed);
      expect(env.memRepo.updates.single.incorrectCount, 1);
    });

    test('a correct review refreshes the shared memory-state map', () async {
      final env = _Env(ids: ['a']);
      final c = await env.container();
      // The dashboard keeps this map alive.
      c.listen(memoryStatesMapNotifierProvider, (_, __) {});
      await c.read(memoryStatesMapNotifierProvider.future);
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('meaning');
      expect(_state(c).phase, ReviewPhase.translationInput);
      await n.submitTranslation('translation');
      expect(_state(c).phase, ReviewPhase.showResult);

      final map = c.read(memoryStatesMapNotifierProvider).requireValue;
      expect(map['a']!.reviewCount, 1);
      expect(map['a']!.lastReviewedAt, isNotNull);
    });

    test('a recalled meaning stays correct despite a weak translation',
        () async {
      final env = _Env(ids: ['a']);
      env.evalService.translationScore = 0.1; // weighted: 0.9*0.4+0.1*0.6=0.42
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('meaning');
      await n.submitTranslation('weak sentence');

      final state = _state(c);
      expect(state.phase, ReviewPhase.showResult);
      expect(state.combinedScore, kPassScore);
      expect(state.correctCount, 1);
      final saved = env.memRepo.updates.single;
      expect(saved.correctCount, 1);
      expect(saved.incorrectCount, 0);
      expect(saved.sm2Repetitions, 1);
    });

    test('a correct answer before the word is due keeps its schedule',
        () async {
      final env = _Env(ids: ['a']);
      final due = DateTime.now().toUtc().add(const Duration(days: 3));
      env.memRepo.states[0] = memory('a',
          reviewCount: 2, interval: 6, repetitions: 2, nextReviewAt: due);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('meaning');
      await n.submitTranslation('translation');
      expect(_state(c).phase, ReviewPhase.showResult);

      final saved = env.memRepo.updates.single;
      expect(saved.reviewCount, 3);
      expect(saved.sm2Interval, 6);
      expect(saved.nextReviewAt, due);
      expect(_state(c).updatedStrength, _state(c).previousStrength);
    });

    test('a correct answer after a miss earlier that day leaves "learning"',
        () async {
      final env = _Env(ids: ['a']);
      // Missed this morning: due again tomorrow, so not due in this session.
      env.memRepo.states[0] = memory('a',
          reviewCount: 1,
          incorrectCount: 1,
          nextReviewAt: DateTime.now().toUtc().add(const Duration(hours: 20)));
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('meaning');
      await n.submitTranslation('translation');
      expect(_state(c).phase, ReviewPhase.showResult);

      final saved = env.memRepo.updates.single;
      expect(saved.sm2Repetitions, 1);
      expect(saved.correctCount, 1);
      expect(_state(c).previousStrength, 0.0);
      // A correct answer shows at least "good".
      expect(_state(c).updatedStrength, greaterThanOrEqualTo(0.6));
    });

    test('a review that fails to save stays visible and is saved later',
        () async {
      final env = _Env(ids: ['a']);
      env.memRepo.updateError = Exception('offline');
      final c = await env.container();
      c.listen(memoryStatesMapNotifierProvider, (_, __) {});
      final memoryStates = c.read(memoryStatesMapNotifierProvider.notifier);
      await c.read(memoryStatesMapNotifierProvider.future);
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      await n.answerDontKnowWord();

      final cache = c.read(cacheServiceProvider);
      expect(cache.getPendingMemoryStates().single.vocabularyId, 'a');

      // Still offline: a sync must not bring back the server's old copy.
      await memoryStates.refresh();
      expect(
          c
              .read(memoryStatesMapNotifierProvider)
              .requireValue['a']!
              .reviewCount,
          1);

      // Back online: the next sync saves it.
      env.memRepo.updateError = null;
      await memoryStates.refresh();
      expect(env.memRepo.states.single.reviewCount, 1);
      expect(env.memRepo.states.single.incorrectCount, 1);
      expect(cache.getPendingMemoryStates(), isEmpty);
      expect(
          c
              .read(memoryStatesMapNotifierProvider)
              .requireValue['a']!
              .reviewCount,
          1);
    });

    test('a pending review never overwrites a newer one from another device',
        () async {
      final env = _Env(ids: ['a']);
      env.memRepo.updateError = Exception('offline');
      final c = await env.container();
      c.listen(memoryStatesMapNotifierProvider, (_, __) {});
      final memoryStates = c.read(memoryStatesMapNotifierProvider.notifier);
      await c.read(memoryStatesMapNotifierProvider.future);
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      await n.answerDontKnowWord();

      // Meanwhile the word was reviewed again elsewhere.
      env.memRepo.states[0] = memory('a',
          reviewCount: 5,
          lastReviewedAt: DateTime.now().toUtc().add(const Duration(hours: 1)));
      env.memRepo.updateError = null;
      await memoryStates.refresh();

      expect(env.memRepo.updates, isEmpty);
      expect(c.read(cacheServiceProvider).getPendingMemoryStates(), isEmpty);
      expect(
          c
              .read(memoryStatesMapNotifierProvider)
              .requireValue['a']!
              .reviewCount,
          5);
    });

    test('a session reuses the loaded word list instead of downloading it',
        () async {
      final env = _Env(ids: ['a', 'b']);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      await n.startSession(mode: 'all');

      expect(_state(c).phase, ReviewPhase.showWord);
      expect(env.vocabRepo.getAllCalls, 1);
      expect(env.memRepo.getAllCalls, 1);
    });

    test('a deck session only contains that deck\'s words', () async {
      final env = _Env(ids: ['a', 'b']);
      env.vocabRepo.items[1] = env.vocabRepo.items[1].copyWith(deckId: 'd1');
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all', deckId: 'd1');

      expect(_state(c).session!.vocabularyItems.map((v) => v.id), ['b']);
    });

    test('missing AI content is generated before the answer is evaluated',
        () async {
      final env = _Env(ids: ['a'], definitions: {'a': null});
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('my answer');

      expect(env.explanationService.calls, contains('a'));
      final meaningCall = env.evalService.calls
          .firstWhere((call) => call.evalType == 'meaning');
      expect(meaningCall.definition, isNotEmpty);
      expect(_state(c).phase, isNot(ReviewPhase.error));
    });

    test('Japanese content without kanji readings is regenerated once',
        () async {
      final env = _Env(ids: ['a']);
      // Imported word: 'ja' code, definition only, no kana reading.
      env.vocabRepo.items[0] = vocab(
        'a',
        word: '人',
        language: 'ja',
        definition: '사람',
        explanation: '사람',
        pronunciation: '/hito/',
      );
      env.explanationService.pronunciation = 'ひと';
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all'); // starts the refresh ahead of time
      n.tapWord();
      await n.answerDontKnowWord();

      expect(_state(c).phase, ReviewPhase.showExplanation);
      expect(_state(c).currentItem!.pronunciation, 'ひと');
      expect(_state(c).currentItem!.definition, 'generated definition of 人');
      expect(env.explanationService.calls, ['a']);
    });

    test('a failed reading refresh falls back to the existing content',
        () async {
      final env = _Env(ids: ['a']);
      env.vocabRepo.items[0] = vocab(
        'a',
        word: '人',
        language: 'Japanese',
        definition: '사람',
      );
      env.explanationService.error = Exception('AI down');
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('사람');

      expect(_state(c).phase, isNot(ReviewPhase.error));
      final meaningCall = env.evalService.calls
          .firstWhere((call) => call.evalType == 'meaning');
      expect(meaningCall.definition, '사람');
      // One attempt per word: no regeneration loop.
      expect(env.explanationService.calls, ['a']);
    });

    test('completing a session records how many words were reviewed', () async {
      final env = _Env(ids: ['a']);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      await n.answerDontKnowWord();
      await n.nextAfterExplanation();

      expect(_state(c).phase, ReviewPhase.complete);
      expect(env.reviewRepo.completedItemCounts, [1]);
    });

    test('a resumed session reports totals that include earlier progress',
        () async {
      final env = _Env(ids: ['a', 'b', 'c', 'd']);
      final c = await env.container();
      final n = _notifier(c);

      await n.resumeSession(ReviewSessionProgress(
        mode: 'all',
        vocabularyIds: const ['a', 'b', 'c', 'd'],
        currentIndex: 3,
        correctCount: 3,
        savedAt: DateTime.now(),
      ));
      expect(_state(c).currentItem!.id, 'd');

      n.tapWord();
      n.answerKnowWord();
      await n.submitMeaning('m');
      await n.submitTranslation('t');
      await n.nextWord();

      final state = _state(c);
      expect(state.phase, ReviewPhase.complete);
      expect(state.sessionCorrectCount, 4);
      expect(state.sessionTotalCount, 4);
    });

    test('progress saved after an answered word resumes at the next word',
        () async {
      final env = _Env(ids: ['a', 'b']);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');
      n.tapWord();
      await n.answerDontKnowWord(); // word "a" is now graded
      await n.saveProgress();

      final saved = c.read(cacheServiceProvider).getReviewProgress()!;
      expect(saved.currentIndex, 1);
    });

    test('the profile language is used for AI prompts', () async {
      final env = _Env(ids: ['a']);
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');

      expect(_state(c).nativeLanguage, 'Japanese');
    });

    test('a failed profile fetch does not block reviews and is retried',
        () async {
      final env = _Env(ids: ['a', 'b'], definitions: {'b': null});
      env.profileError = Exception('offline');
      final c = await env.container();
      final n = _notifier(c);

      await n.startSession(mode: 'all');

      // Falls back to the default language instead of an error screen…
      expect(_state(c).phase, ReviewPhase.showWord);
      expect(_state(c).nativeLanguage, 'Korean');
      await pumpEventQueue();
      // …AI generation for the word without content still runs…
      expect(env.explanationService.calls, contains('b'));

      // …and the next call retries the profile instead of reusing the error.
      env.profileError = null;
      final loadsBefore = env.profileLoads;
      await n.retrySession();
      expect(env.profileLoads, greaterThan(loadsBefore));
      expect(_state(c).nativeLanguage, 'Japanese');
    });

    group('writing practice after a wrong answer', () {
      test('"don\'t know" → practice gives feedback without regrading',
          () async {
        final env = _Env(ids: ['a', 'b']);
        final c = await env.container();
        final n = _notifier(c);

        await n.startSession(mode: 'all');
        n.tapWord();
        await n.answerDontKnowWord();
        expect(_state(c).canPractice, isTrue);

        await n.startPractice();
        expect(_state(c).phase, ReviewPhase.translationInput);
        expect(_state(c).isPractice, isTrue);
        expect(
          _state(c).translationSentence,
          'sentence for ${_state(c).currentItem!.word}',
        );

        await n.submitTranslation('my sentence');
        final state = _state(c);
        expect(state.phase, ReviewPhase.showPracticeResult);
        expect(state.translationEvaluation!.overallScore, 0.9);
        expect(state.translationAnswer, 'my sentence');

        expect(
          env.evalService.calls.map((call) => call.evalType),
          ['translation'],
        );
        // Graded once as a miss: no second SM-2 update, no extra history row,
        // and a good practice sentence does not count as a correct answer.
        expect(env.memRepo.updates.single.incorrectCount, 1);
        expect(env.reviewRepo.results.single.questionType, 'knowledge');
        expect(state.correctCount, 0);

        await n.nextWord();
        expect(_state(c).phase, ReviewPhase.showWord);
        expect(_state(c).currentIndex, 1);
        expect(_state(c).isPractice, isFalse);
      });

      test('after a failed meaning the prefetched exercise is reused',
          () async {
        final env = _Env(ids: ['a']);
        env.evalService.meaningScore = 0.2;
        final c = await env.container();
        final n = _notifier(c);

        await n.startSession(mode: 'all');
        n.tapWord();
        n.answerKnowWord(); // prefetches the exercise
        await n.submitMeaning('wrong');
        expect(_state(c).phase, ReviewPhase.meaningFailed);

        await n.startPractice();
        expect(_state(c).phase, ReviewPhase.translationInput);
        expect(env.questionService.calls, 1);

        await n.submitTranslation('sentence');
        expect(_state(c).phase, ReviewPhase.showPracticeResult);
        expect(env.memRepo.updates, hasLength(1));
        expect(env.reviewRepo.results.single.questionType, 'meaning');
      });

      test('patterns found in the practice sentence are remembered', () async {
        final env = _Env(ids: ['a']);
        env.evalService.translationScore = 0.3;
        final c = await env.container();
        final n = _notifier(c);

        await n.startSession(mode: 'all');
        n.tapWord();
        await n.answerDontKnowWord();
        await n.startPractice();
        await n.submitTranslation('bad sentence');
        await pumpEventQueue();

        expect(_state(c).phase, ReviewPhase.showPracticeResult);
        // One call records the word-specific and the global pattern.
        expect(env.patternRepo.upserts, [
          ['pattern'],
        ]);
      });

      test('practice can be left unanswered, the graded exercise cannot',
          () async {
        final env = _Env(ids: ['a', 'b']);
        final c = await env.container();
        final n = _notifier(c);

        await n.startSession(mode: 'all');
        n.tapWord();
        await n.answerDontKnowWord();
        await n.startPractice();
        await n.nextWord();
        expect(_state(c).currentIndex, 1);
        expect(_state(c).phase, ReviewPhase.showWord);

        // Word "b": the regular translation step must be answered.
        n.tapWord();
        n.answerKnowWord();
        await n.submitMeaning('meaning');
        expect(_state(c).phase, ReviewPhase.translationInput);
        expect(_state(c).isPractice, isFalse);
        await n.nextWord();
        expect(_state(c).phase, ReviewPhase.translationInput);
        expect(_state(c).currentIndex, 1);
      });

      test('a failed exercise can be retried or skipped', () async {
        final env = _Env(ids: ['a']);
        env.questionService.error = Exception('AI down');
        final c = await env.container();
        final n = _notifier(c);

        await n.startSession(mode: 'all');
        n.tapWord();
        await n.answerDontKnowWord();
        await n.startPractice();

        expect(_state(c).phase, ReviewPhase.error);
        expect(_state(c).canRetryStep, isTrue);
        expect(_state(c).error, isA<PracticeUnavailableException>());

        env.questionService.error = null;
        await n.retry();
        expect(_state(c).phase, ReviewPhase.translationInput);
        expect(_state(c).isPractice, isTrue);
      });

      test('not offered when the word has no AI content', () async {
        final env = _Env(ids: ['a'], definitions: {'a': null});
        env.explanationService.error = Exception('AI down');
        final c = await env.container();
        final n = _notifier(c);

        await n.startSession(mode: 'all');
        n.tapWord();
        await n.answerDontKnowWord();
        expect(_state(c).phase, ReviewPhase.showExplanation);
        expect(_state(c).canPractice, isFalse);

        await n.startPractice();
        expect(_state(c).phase, ReviewPhase.showExplanation);
        expect(env.questionService.calls, 0);
      });

      test('not offered before the word is graded', () async {
        final env = _Env(ids: ['a']);
        final c = await env.container();
        final n = _notifier(c);

        await n.startSession(mode: 'all');
        expect(_state(c).canPractice, isFalse);
        await n.startPractice();
        expect(_state(c).phase, ReviewPhase.showWord);
      });
    });

    test('closing the screen while AI content is generated is safe', () async {
      final env = _Env(ids: ['a'], definitions: {'a': null});
      final gate = Completer<void>();
      env.explanationService.gate = gate;
      final c = await env.container();
      final sub = c.listen(reviewNotifierProvider, (_, __) {});
      final n = c.read(reviewNotifierProvider.notifier);

      await n.startSession(mode: 'all'); // starts generation in the background
      await pumpEventQueue();
      expect(env.explanationService.calls, ['a']);

      sub.close(); // the review screen goes away
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();
      // Reaching here without an unhandled "used after dispose" error is the
      // assertion (the test zone fails on uncaught async errors).
    });
  });
}
