// Flow tests for ReviewNotifier: drives the real state machine against
// in-memory fakes (no Supabase, no network).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
