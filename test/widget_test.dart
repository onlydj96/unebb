// Widget tests for individual screens that do not require Supabase or routing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/screens/login_screen.dart';
import 'package:unebb/features/review/providers/review_providers.dart';
import 'package:unebb/features/review/screens/review_screen.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/features/vocabulary/screens/add_word_screen.dart';
import 'package:unebb/features/vocabulary/screens/vocabulary_list_screen.dart';
import 'package:unebb/features/vocabulary/screens/word_detail_screen.dart';

// ---------------------------------------------------------------------------
// Shared test data
// ---------------------------------------------------------------------------

final _kTestItem = VocabularyItem(
  id: 'vocab-1',
  userId: 'user-1',
  word: 'ephemeral',
  language: 'English',
  definition: 'Lasting for a very short time.',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// ---------------------------------------------------------------------------
// Fakes — use subclasses so overrideWith type constraints are satisfied
// ---------------------------------------------------------------------------

class _FakeVocabularyNotifier extends VocabularyNotifier {
  @override
  Future<List<VocabularyItem>> build() async => const [];
}

class _FakeVocabularyWithWordsNotifier extends VocabularyNotifier {
  @override
  Future<List<VocabularyItem>> build() async => [_kTestItem];
}

class _FakeReviewNotifier extends ReviewNotifier {
  _FakeReviewNotifier(super.ref);

  @override
  Future<void> startSession() async {
    state = const ReviewUiState(phase: ReviewPhase.loading);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── LoginScreen ────────────────────────────────────────────────────────────

  testWidgets('LoginScreen renders sign-in button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Sign In'), findsOneWidget);
  });

  // ── VocabularyListScreen ───────────────────────────────────────────────────

  testWidgets('VocabularyListScreen renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyNotifierProvider
              .overrideWith(() => _FakeVocabularyNotifier()),
        ],
        child: const MaterialApp(home: VocabularyListScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('My Words'), findsOneWidget);
  });

  testWidgets('VocabularyListScreen renders word cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyNotifierProvider
              .overrideWith(() => _FakeVocabularyWithWordsNotifier()),
          memoryStatesMapProvider
              .overrideWith((ref) async => <String, MemoryState>{}),
        ],
        child: const MaterialApp(home: VocabularyListScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  // ── AddWordScreen ──────────────────────────────────────────────────────────

  testWidgets('AddWordScreen renders form fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyNotifierProvider
              .overrideWith(() => _FakeVocabularyNotifier()),
        ],
        child: const MaterialApp(home: AddWordScreen()),
      ),
    );
    // AppBar title + submit button both contain 'Add Word'.
    expect(find.text('Add Word'), findsWidgets);
    expect(find.text('Word or phrase'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('AddWordScreen shows validation error on empty submit',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyNotifierProvider
              .overrideWith(() => _FakeVocabularyNotifier()),
        ],
        child: const MaterialApp(home: AddWordScreen()),
      ),
    );
    // Tap submit without entering a word — validation fires.
    await tester.tap(find.widgetWithText(FilledButton, 'Add Word'));
    await tester.pump();
    expect(find.text('Please enter a word'), findsOneWidget);
  });

  // ── WordDetailScreen ───────────────────────────────────────────────────────

  testWidgets('WordDetailScreen renders AI content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyItemProvider.overrideWith((ref, id) async => _kTestItem),
        ],
        child: const MaterialApp(
          home: WordDetailScreen(wordId: 'vocab-1'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('Lasting for a very short time.'), findsOneWidget);
  });

  testWidgets('WordDetailScreen shows word not found for missing item',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vocabularyItemProvider.overrideWith((ref, id) async => null),
        ],
        child: const MaterialApp(
          home: WordDetailScreen(wordId: 'missing'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Word not found.'), findsOneWidget);
  });

  // ── ReviewScreen ───────────────────────────────────────────────────────────

  testWidgets('ReviewScreen renders app bar title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewNotifierProvider
              .overrideWith((ref) => _FakeReviewNotifier(ref)),
        ],
        child: const MaterialApp(home: ReviewScreen()),
      ),
    );
    expect(find.text('Review'), findsOneWidget);
  });
}
