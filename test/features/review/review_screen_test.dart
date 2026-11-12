// End-to-end widget tests of the review screen against in-memory fakes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/data/services/voice_mode_service.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/review/providers/voice_mode_provider.dart';
import 'package:unebb/features/review/screens/review_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

/// Voice service that never touches the platform.
class _SilentVoiceService extends VoiceModeService {
  @override
  Future<void> speak(String text, {String? language}) async {}
  @override
  Future<void> startListening({
    required String language,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancelListening() async {}
  @override
  Future<void> dispose() async {}
}

class _EnabledVoiceNotifier extends VoiceModeNotifier {
  _EnabledVoiceNotifier() : super(service: _SilentVoiceService()) {
    state = const VoiceModeState(isEnabled: true, isInitialized: true);
  }
}

class _Env {
  _Env(List<String> ids) {
    vocabRepo = FakeVocabularyRepository([
      for (final id in ids) vocab(id, word: 'word $id'),
    ]);
    memRepo = FakeMemoryStateRepository([for (final id in ids) memory(id)]);
  }

  late final FakeVocabularyRepository vocabRepo;
  late final FakeMemoryStateRepository memRepo;
  final reviewRepo = FakeReviewRepository();
  final evalService = FakeAiEvaluationService();
  final questionService = FakeAiQuestionService();

  List<Override> overrides({bool voice = false}) => [
        currentUserIdProvider.overrideWithValue(kTestUserId),
        vocabularyRepositoryProvider.overrideWithValue(vocabRepo),
        memoryStateRepositoryProvider.overrideWithValue(memRepo),
        reviewRepositoryProvider.overrideWithValue(reviewRepo),
        errorPatternRepositoryProvider
            .overrideWithValue(FakeErrorPatternRepository()),
        aiEvaluationServiceProvider.overrideWithValue(evalService),
        aiQuestionServiceProvider.overrideWithValue(questionService),
        aiExplanationServiceProvider
            .overrideWithValue(FakeAiExplanationService(vocabRepo)),
        profileProvider.overrideWith((ref) async => null),
        if (voice)
          voiceModeProvider.overrideWith((ref) => _EnabledVoiceNotifier()),
      ];
}

Future<void> _settle(WidgetTester tester) async {
  // AnimatedSwitcher transitions + async notifier work.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('a full review: know → meaning → translation → result → done',
      (tester) async {
    final env = _Env(['a']);
    await tester.pumpWidget(await testApp(
      const ReviewScreen(mode: 'all'),
      overrides: env.overrides(),
    ));
    await _settle(tester);

    expect(find.text('1 / 1'), findsOneWidget);
    await tester.tap(find.text('word a'));
    await _settle(tester);

    await tester.tap(find.text('I know it'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'meaning');
    await tester.pump();
    await tester.tap(find.text('Submit answer'));
    await _settle(tester);

    expect(find.text('sentence for word a'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'my translation');
    await tester.pump();
    await tester.tap(find.text('Submit translation'));
    await _settle(tester);

    expect(find.text('90%'), findsWidgets);
    expect(find.text('Word usage'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await _settle(tester);

    expect(find.text('Session complete!'), findsOneWidget);
    expect(find.text('1 out of 1 correct'), findsOneWidget);
    expect(env.memRepo.updates.single.reviewCount, 1);
  });

  testWidgets('a blank answer cannot be submitted', (tester) async {
    final env = _Env(['a']);
    await tester.pumpWidget(await testApp(
      const ReviewScreen(mode: 'all'),
      overrides: env.overrides(),
    ));
    await _settle(tester);
    await tester.tap(find.text('word a'));
    await _settle(tester);
    await tester.tap(find.text('I know it'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit answer'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('when nothing is due the learner can review all words instead',
      (tester) async {
    final env = _Env(['a']);
    env.memRepo.states[0] = memory(
      'a',
      reviewCount: 2,
      nextReviewAt: DateTime.now().toUtc().add(const Duration(days: 3)),
    );
    await tester.pumpWidget(await testApp(
      const ReviewScreen(mode: 'due'),
      overrides: env.overrides(),
    ));
    await _settle(tester);

    expect(find.text('All caught up!'), findsOneWidget);
    await tester.tap(find.text('Review all words'));
    await _settle(tester);

    expect(find.text('word a'), findsOneWidget);
  });

  testWidgets('an AI failure can be retried without losing the session',
      (tester) async {
    final env = _Env(['a', 'b']);
    await tester.pumpWidget(await testApp(
      const ReviewScreen(mode: 'all'),
      overrides: env.overrides(),
    ));
    await _settle(tester);
    await tester.tap(find.textContaining('word '));
    await _settle(tester);
    await tester.tap(find.text('I know it'));
    await _settle(tester);

    // The next evaluation times out once.
    env.evalService.nextError = TimeoutException('AI evaluation timed out');

    await tester.enterText(find.byType(TextField), 'meaning');
    await tester.pump();
    await tester.tap(find.text('Submit answer'));
    await _settle(tester);

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Skip word'), findsOneWidget);
    expect(find.textContaining('AI service'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await _settle(tester);

    // Back on track: the translation exercise is shown, same word.
    expect(find.textContaining('sentence for word'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('voice mode: answering "don\'t know" shows the explanation',
      (tester) async {
    final env = _Env(['a']);
    await tester.pumpWidget(await testApp(
      const ReviewScreen(mode: 'all'),
      overrides: env.overrides(voice: true),
    ));
    await _settle(tester);

    // The voice flow asks the knowledge question.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReviewScreen)),
    );
    await container
        .read(voiceModeProvider.notifier)
        .askKnowledge('Do you know this word?', 'Korean');
    await tester.pump();

    // The two buttons sit side by side without a layout exception.
    expect(tester.takeException(), isNull);
    expect(find.text("I don't know it"), findsOneWidget);

    await tester.tap(find.text("I don't know it"));
    await _settle(tester);

    expect(find.text('Got it'), findsOneWidget);
    expect(env.reviewRepo.results.single.answerType, 'skip');
  });
}
