// Navigation flows that need a real GoRouter.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/review/screens/review_screen.dart';
import 'package:unebb/features/vocabulary/screens/edit_word_screen.dart';
import 'package:unebb/features/vocabulary/screens/word_detail_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

final _home = GoRoute(
  path: '/',
  builder: (_, __) => const Scaffold(body: Center(child: Text('HOME'))),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('deleting a word from the edit screen returns past its detail',
      (tester) async {
    final vocabRepo = FakeVocabularyRepository([vocab('a', word: 'ephemeral')]);
    await tester.pumpWidget(await testRouterApp(
      routes: [
        _home,
        GoRoute(
          path: '/words/:id',
          builder: (_, s) => WordDetailScreen(wordId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/words/:id/edit',
          builder: (_, s) => EditWordScreen(wordId: s.pathParameters['id']!),
        ),
      ],
      overrides: [
        currentUserIdProvider.overrideWithValue(kTestUserId),
        vocabularyRepositoryProvider.overrideWithValue(vocabRepo),
        memoryStateRepositoryProvider
            .overrideWithValue(FakeMemoryStateRepository([memory('a')])),
        profileProvider.overrideWith((ref) async => null),
      ],
    ));
    await _settle(tester);

    GoRouter.of(tester.element(find.text('HOME'))).push('/words/a');
    await _settle(tester);
    expect(find.text('ephemeral'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Word'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await _settle(tester);

    expect(vocabRepo.items, isEmpty);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(WordDetailScreen), findsNothing);
  });

  testWidgets('dismissing the resume dialog keeps the saved progress',
      (tester) async {
    final progress = ReviewSessionProgress(
      mode: 'due',
      vocabularyIds: const ['a', 'b'],
      currentIndex: 1,
      correctCount: 1,
      savedAt: DateTime.now(),
    );
    await tester.pumpWidget(await testRouterApp(
      routes: [
        _home,
        GoRoute(path: '/review', builder: (_, __) => const ReviewScreen()),
      ],
      prefs: {
        CacheKeys.owner: kTestUserId,
        CacheKeys.reviewSessionProgress: jsonEncode(progress.toJson()),
      },
      overrides: [
        currentUserIdProvider.overrideWithValue(kTestUserId),
        vocabularyRepositoryProvider.overrideWithValue(
            FakeVocabularyRepository([vocab('a'), vocab('b')])),
        memoryStateRepositoryProvider.overrideWithValue(
            FakeMemoryStateRepository([memory('a'), memory('b')])),
        reviewRepositoryProvider.overrideWithValue(FakeReviewRepository()),
        errorPatternRepositoryProvider
            .overrideWithValue(FakeErrorPatternRepository()),
        profileProvider.overrideWith((ref) async => null),
      ],
    ));
    await _settle(tester);

    GoRouter.of(tester.element(find.text('HOME'))).push('/review');
    await _settle(tester);
    expect(find.text('Continue Previous Session?'), findsOneWidget);

    // Android back closes the dialog without choosing.
    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(find.text('HOME'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.text('HOME')),
    );
    expect(container.read(cacheServiceProvider).getReviewProgress(), isNotNull);
  });
}
