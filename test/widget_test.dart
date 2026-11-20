// Widget tests for individual screens (no Supabase, no routing).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/auth/screens/login_screen.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/home/screens/dashboard_screen.dart';
import 'package:unebb/features/review/providers/review_providers.dart';
import 'package:unebb/features/review/screens/review_screen.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/features/vocabulary/screens/add_word_screen.dart';
import 'package:unebb/features/vocabulary/screens/edit_word_screen.dart';
import 'package:unebb/features/vocabulary/screens/vocabulary_list_screen.dart';
import 'package:unebb/features/vocabulary/screens/word_detail_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/test_app.dart';

final _kTestItem = VocabularyItem(
  id: 'vocab-1',
  userId: 'user-1',
  word: 'ephemeral',
  language: 'English',
  definition: 'Lasting for a very short time.',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _FakeVocabularyNotifier extends VocabularyNotifier {
  _FakeVocabularyNotifier([this.items = const []]);
  final List<VocabularyItem> items;

  @override
  Future<List<VocabularyItem>> build() async => items;
}

class _FakeDeckNotifier extends DeckNotifier {
  _FakeDeckNotifier([this.decks = const []]);
  final List<Deck> decks;

  @override
  Future<List<Deck>> build() async => decks;
}

class _FakeMemoryNotifier extends MemoryStatesMapNotifier {
  _FakeMemoryNotifier([this.states = const []]);
  final List<MemoryState> states;

  @override
  Future<Map<String, MemoryState>> build() async =>
      {for (final s in states) s.vocabularyId: s};
}

class _LoadingReviewNotifier extends ReviewNotifier {
  _LoadingReviewNotifier(super.ref);

  @override
  Future<void> startSession({
    String mode = 'due',
    int? limit,
    String? deckId,
  }) async {}
}

/// Signed-out, empty data: no provider reaches the network.
List<Override> _offlineOverrides({
  List<VocabularyItem> words = const [],
  List<Deck> decks = const [],
  List<MemoryState> memory = const [],
}) =>
    [
      currentUserIdProvider.overrideWithValue(kTestUserId),
      vocabularyNotifierProvider
          .overrideWith(() => _FakeVocabularyNotifier(words)),
      deckNotifierProvider.overrideWith(() => _FakeDeckNotifier(decks)),
      memoryStatesMapNotifierProvider
          .overrideWith(() => _FakeMemoryNotifier(memory)),
      profileProvider.overrideWith((ref) async => null),
    ];

void main() {
  // ── LoginScreen ────────────────────────────────────────────────────────────

  testWidgets('LoginScreen renders the sign-in form', (tester) async {
    await tester.pumpWidget(await testApp(const LoginScreen()));
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('LoginScreen validates input before calling the server',
      (tester) async {
    await tester.pumpWidget(await testApp(const LoginScreen()));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('LoginScreen is localized in Korean', (tester) async {
    await tester.pumpWidget(
      await testApp(const LoginScreen(), locale: const Locale('ko')),
    );
    expect(find.text('로그인'), findsWidgets);
  });

  // ── DashboardScreen ────────────────────────────────────────────────────────

  testWidgets('Dashboard memory health reflects time since the due date',
      (tester) async {
    final now = DateTime.now().toUtc();
    await tester.pumpWidget(await testApp(
      const DashboardScreen(),
      overrides: _offlineOverrides(
        words: [
          for (final id in [
            'fresh',
            'neglected',
            'just-due',
            'lapsed',
            'unknown',
            'new',
          ])
            vocab(id),
        ],
        memory: [
          memory('fresh',
              reviewCount: 4,
              interval: 45,
              repetitions: 4,
              nextReviewAt: now.add(const Duration(days: 10))),
          // Strong when last reviewed, but 300 days overdue.
          memory('neglected',
              reviewCount: 4,
              interval: 45,
              repetitions: 4,
              nextReviewAt: now.subtract(const Duration(days: 300))),
          // Recalled once and due a minute ago: still good, not critical.
          memory('just-due',
              reviewCount: 1,
              repetitions: 1,
              nextReviewAt: now.subtract(const Duration(minutes: 1))),
          // Recalled before, missed last time.
          memory('lapsed', reviewCount: 3, correctCount: 2, incorrectCount: 1),
          // Never recalled ("I don't know" on first sight).
          memory('unknown', reviewCount: 1, incorrectCount: 1),
          memory('new'),
        ],
      ),
    ));
    await tester.pump();

    expect(find.text('5 words'), findsOneWidget); // reviewed words only
    expect(find.text('Strong 1'), findsOneWidget);
    expect(find.text('Good 1'), findsOneWidget);
    expect(find.text('Weak 1'), findsOneWidget);
    expect(find.text('Critical 1'), findsOneWidget);
    expect(find.text('Learning 1'), findsOneWidget);
    // Mastered tile.
    expect(
      find.descendant(
        of: find.ancestor(
            of: find.text('Mastered'), matching: find.byType(Card)),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  // ── VocabularyListScreen ───────────────────────────────────────────────────

  testWidgets('VocabularyListScreen renders the empty state', (tester) async {
    await tester.pumpWidget(await testApp(
      const VocabularyListScreen(),
      overrides: _offlineOverrides(),
    ));
    await tester.pump();
    expect(find.text('All Words'), findsOneWidget);
    expect(find.textContaining('No words yet'), findsOneWidget);
  });

  testWidgets('VocabularyListScreen renders word cards', (tester) async {
    await tester.pumpWidget(await testApp(
      const VocabularyListScreen(),
      overrides: _offlineOverrides(words: [_kTestItem]),
    ));
    await tester.pump();
    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('word cards show memory only once a word has been reviewed',
      (tester) async {
    await tester.pumpWidget(await testApp(
      const VocabularyListScreen(),
      overrides: _offlineOverrides(
        words: [vocab('new', word: 'fresh'), vocab('seen', word: 'known')],
        memory: [
          memory('new'),
          memory('seen',
              reviewCount: 1,
              repetitions: 1,
              nextReviewAt:
                  DateTime.now().toUtc().add(const Duration(days: 1))),
        ],
      ),
    ));
    await tester.pump();

    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('known'), findsOneWidget);
    // Only the reviewed word has a memory bar.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'a word whose AI content is missing offers a retry, not a spinner',
      (tester) async {
    final missing = vocab('m1', word: 'gauche', definition: null);
    await tester.pumpWidget(await testApp(
      const VocabularyListScreen(),
      overrides: _offlineOverrides(words: [missing]),
    ));
    await tester.pump();

    expect(find.byTooltip('Generate explanation'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ── AddWordScreen ──────────────────────────────────────────────────────────

  testWidgets('AddWordScreen renders form fields', (tester) async {
    await tester.pumpWidget(await testApp(
      const AddWordScreen(),
      overrides: _offlineOverrides(),
    ));
    expect(find.text('Add Word'), findsWidgets);
    expect(find.text('Word or phrase'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('AddWordScreen shows validation error on empty submit',
      (tester) async {
    await tester.pumpWidget(await testApp(
      const AddWordScreen(),
      overrides: _offlineOverrides(),
    ));
    await tester.tap(find.widgetWithText(FilledButton, 'Add Word'));
    await tester.pump();
    expect(find.text('Please enter a word'), findsOneWidget);
  });

  testWidgets('AddWordScreen defaults to the language of the deck',
      (tester) async {
    final overrides = _offlineOverrides(
      decks: [deck('jp', name: 'JLPT N3', language: 'Japanese')],
    );
    // Load the deck list first, as the deck screen does before navigating.
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await container.read(deckNotifierProvider.future);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: (await testApp(const AddWordScreen(deckId: 'jp')) as ProviderScope)
          .child,
    ));
    await tester.pump();

    expect(find.text('Japanese'), findsOneWidget);
  });

  // ── EditWordScreen ─────────────────────────────────────────────────────────

  testWidgets('EditWordScreen opens words in languages outside the list',
      (tester) async {
    final item = vocab('v1', word: 'xin chào', language: 'Vietnamese');
    await tester.pumpWidget(await testApp(
      const EditWordScreen(wordId: 'v1'),
      overrides: [
        ..._offlineOverrides(words: [item]),
      ],
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Vietnamese'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  // ── WordDetailScreen ───────────────────────────────────────────────────────

  testWidgets('WordDetailScreen renders AI content', (tester) async {
    await tester.pumpWidget(await testApp(
      const WordDetailScreen(wordId: 'vocab-1'),
      overrides: _offlineOverrides(words: [_kTestItem]),
    ));
    await tester.pump();
    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('Lasting for a very short time.'), findsOneWidget);
  });

  testWidgets('WordDetailScreen shows word not found for missing item',
      (tester) async {
    await tester.pumpWidget(await testApp(
      const WordDetailScreen(wordId: 'missing'),
      overrides: [
        ..._offlineOverrides(),
        vocabularyRepositoryProvider
            .overrideWithValue(FakeVocabularyRepository()),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Word not found.'), findsOneWidget);
  });

  testWidgets('WordDetailScreen generates missing AI content on demand',
      (tester) async {
    final missing =
        vocab('m1', word: 'gauche', definition: null, explanation: null);
    final repo = FakeVocabularyRepository([missing]);
    final explanations = FakeAiExplanationService(repo);

    await tester.pumpWidget(await testApp(
      const WordDetailScreen(wordId: 'm1'),
      overrides: [
        ..._offlineOverrides(),
        vocabularyNotifierProvider
            .overrideWith(() => _FakeVocabularyNotifier([missing])),
        aiExplanationServiceProvider.overrideWithValue(explanations),
      ],
    ));
    await tester.pump();
    expect(find.text("This word doesn't have an AI explanation yet."),
        findsOneWidget);

    await tester.tap(find.text('Generate explanation'));
    await tester.pump();
    await tester.pump();

    expect(explanations.calls, ['m1']);
    expect(find.text('generated definition of gauche'), findsOneWidget);
  });

  // ── ReviewScreen ───────────────────────────────────────────────────────────

  testWidgets('ReviewScreen renders app bar title', (tester) async {
    await tester.pumpWidget(await testApp(
      const ReviewScreen(),
      overrides: [
        currentUserIdProvider.overrideWithValue(kTestUserId),
        reviewNotifierProvider.overrideWith(_LoadingReviewNotifier.new),
      ],
    ));
    await tester.pump();
    expect(find.text('Review'), findsOneWidget);
  });
}
