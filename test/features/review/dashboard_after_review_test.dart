// The dashboard's memory health chart follows reviews as they are graded.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/home/screens/dashboard_screen.dart';
import 'package:unebb/features/review/providers/review_providers.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('a review moves the word in the memory health chart',
      (tester) async {
    final vocabRepo = FakeVocabularyRepository([vocab('a', word: 'word a')]);
    // Missed earlier today ("I don't know"): still learning, due tomorrow.
    final memRepo = FakeMemoryStateRepository([
      memory('a',
          reviewCount: 1,
          incorrectCount: 1,
          nextReviewAt: DateTime.now().toUtc().add(const Duration(hours: 20))),
    ]);
    final evalService = FakeAiEvaluationService();

    await tester.pumpWidget(await testApp(
      const DashboardScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue(kTestUserId),
        vocabularyRepositoryProvider.overrideWithValue(vocabRepo),
        memoryStateRepositoryProvider.overrideWithValue(memRepo),
        deckRepositoryProvider.overrideWithValue(FakeDeckRepository()),
        reviewRepositoryProvider.overrideWithValue(FakeReviewRepository()),
        errorPatternRepositoryProvider
            .overrideWithValue(FakeErrorPatternRepository()),
        aiEvaluationServiceProvider.overrideWithValue(evalService),
        aiQuestionServiceProvider.overrideWithValue(FakeAiQuestionService()),
        aiExplanationServiceProvider
            .overrideWithValue(FakeAiExplanationService(vocabRepo)),
        profileProvider.overrideWith((ref) async => null),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Learning 1'), findsOneWidget);
    expect(find.text('Good 0'), findsOneWidget);

    // Review the word while the dashboard stays mounted underneath.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    final keepAlive = container.listen(reviewNotifierProvider, (_, __) {});
    final review = container.read(reviewNotifierProvider.notifier);

    Future<void> answer({required bool correct}) async {
      evalService.meaningScore = correct ? 0.9 : 0.2;
      await review.startSession(mode: 'all');
      review.tapWord();
      review.answerKnowWord();
      await review.submitMeaning('my answer');
      if (correct) await review.submitTranslation('my sentence');
      await tester.pumpAndSettle();
    }

    // Recalled: learning → good.
    await answer(correct: true);
    expect(find.text('Good 1'), findsOneWidget);
    expect(find.textContaining('Learning'), findsNothing);
    expect(find.text('Critical 0'), findsOneWidget);

    // Forgotten again: good → critical.
    await answer(correct: false);
    expect(find.text('Critical 1'), findsOneWidget);
    expect(find.text('Good 0'), findsOneWidget);

    keepAlive.close();
  });
}
