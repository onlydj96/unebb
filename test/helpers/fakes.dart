// In-memory fakes for repositories and AI services.
//
// They implement the domain interfaces so tests can drive providers/notifiers
// through the real Riverpod graph without Supabase or network access.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:unebb/data/services/ai_evaluation_service.dart';
import 'package:unebb/data/services/ai_explanation_service.dart';
import 'package:unebb/data/services/ai_question_service.dart';
import 'package:unebb/domain/models/ai_evaluation.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/review_result.dart';
import 'package:unebb/domain/models/review_session.dart';
import 'package:unebb/domain/models/user_error_pattern.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/repositories/deck_repository.dart';
import 'package:unebb/domain/repositories/error_pattern_repository.dart';
import 'package:unebb/domain/repositories/memory_state_repository.dart';
import 'package:unebb/domain/repositories/review_repository.dart';
import 'package:unebb/domain/repositories/vocabulary_repository.dart';

const kTestUserId = 'user-1';

final _epoch = DateTime.utc(2026, 1, 1);

VocabularyItem vocab(
  String id, {
  String? word,
  String language = 'English',
  String? deckId,
  String? definition = 'a definition',
  String? explanation = 'an explanation',
  String userId = kTestUserId,
  DateTime? createdAt,
}) {
  return VocabularyItem(
    id: id,
    userId: userId,
    deckId: deckId,
    word: word ?? 'word-$id',
    language: language,
    definition: definition,
    explanation: explanation,
    usage: definition == null ? null : 'usage of ${word ?? id}',
    examples: definition == null ? null : ['example for ${word ?? id}'],
    createdAt: createdAt ?? _epoch,
    updatedAt: createdAt ?? _epoch,
  );
}

MemoryState memory(
  String vocabularyId, {
  int reviewCount = 0,
  double strength = 0.0,
  int incorrectCount = 0,
  DateTime? nextReviewAt,
  DateTime? lastReviewedAt,
  String userId = kTestUserId,
}) {
  return MemoryState(
    id: 'ms-$vocabularyId',
    userId: userId,
    vocabularyId: vocabularyId,
    stage: 4,
    memoryStrength: strength,
    recallProbability: strength,
    lastReviewedAt: lastReviewedAt,
    nextReviewAt: nextReviewAt ??
        DateTime.now().toUtc().subtract(
              const Duration(minutes: 1),
            ),
    reviewCount: reviewCount,
    correctCount: 0,
    incorrectCount: incorrectCount,
    consecutiveCorrect: 0,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

Deck deck(
  String id, {
  String? name,
  String language = 'English',
  int wordCount = 0,
  DateTime? createdAt,
}) {
  return Deck(
    id: id,
    userId: kTestUserId,
    name: name ?? 'Deck $id',
    language: language,
    wordCount: wordCount,
    createdAt: createdAt ?? _epoch,
    updatedAt: createdAt ?? _epoch,
  );
}

/// Postgres CHECK-constraint violation, as surfaced by postgrest.
PostgrestException checkViolation() => const PostgrestException(
      message: 'new row for relation "review_results" violates check '
          'constraint "question_type_valid"',
      code: '23514',
    );

/// Postgres unique violation, as surfaced by postgrest.
PostgrestException uniqueViolation() => const PostgrestException(
      message: 'duplicate key value violates unique constraint',
      code: '23505',
    );

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

class FakeVocabularyRepository implements VocabularyRepository {
  FakeVocabularyRepository([List<VocabularyItem> items = const []])
      : items = [...items];

  final List<VocabularyItem> items;
  int getAllCalls = 0;
  Object? createError;
  int _seq = 0;

  @override
  Future<List<VocabularyItem>> getAll() async {
    getAllCalls++;
    return [...items];
  }

  @override
  Future<List<VocabularyItem>> getByDeckId(String deckId) async =>
      items.where((v) => v.deckId == deckId).toList();

  @override
  Future<VocabularyItem?> getById(String id) async =>
      items.where((v) => v.id == id).firstOrNull;

  @override
  Future<VocabularyItem?> findDuplicate({
    required String word,
    required String language,
    String? deckId,
  }) async {
    final normalized = word.trim().toLowerCase();
    return items
        .where((v) =>
            v.language == language &&
            v.word.trim().toLowerCase() == normalized &&
            (deckId == null || v.deckId == deckId))
        .firstOrNull;
  }

  @override
  Future<VocabularyItem> create({
    required String word,
    required String language,
    String? deckId,
  }) async {
    if (createError != null) throw createError!;
    final item = vocab(
      'new-${_seq++}',
      word: word,
      language: language,
      deckId: deckId,
      definition: null,
      explanation: null,
    );
    items.insert(0, item);
    return item;
  }

  @override
  Future<VocabularyItem> update(VocabularyItem item) async {
    final index = items.indexWhere((v) => v.id == item.id);
    items[index] = item;
    return item;
  }

  @override
  Future<void> delete(String id) async => items.removeWhere((v) => v.id == id);

  @override
  Future<VocabularyItem> updateAiContent({
    required String id,
    required String definition,
    required String explanation,
    required String usage,
    required List<String> examples,
    required List<String> synonyms,
    required List<String> collocations,
    required List<String> commonMistakes,
  }) {
    throw UnimplementedError();
  }
}

class FakeMemoryStateRepository implements MemoryStateRepository {
  FakeMemoryStateRepository([List<MemoryState> states = const []])
      : states = [...states];

  final List<MemoryState> states;
  final List<MemoryState> updates = [];
  int getAllCalls = 0;

  @override
  Future<List<MemoryState>> getAll() async {
    getAllCalls++;
    return [...states];
  }

  @override
  Future<MemoryState?> getByVocabularyId(String vocabularyId) async =>
      states.where((s) => s.vocabularyId == vocabularyId).firstOrNull;

  @override
  Future<MemoryState> create({required String vocabularyId}) async {
    final state = memory(vocabularyId);
    states.add(state);
    return state;
  }

  @override
  Future<List<MemoryState>> createBatch({
    required List<String> vocabularyIds,
  }) async {
    final created = vocabularyIds.map((id) => memory(id)).toList();
    states.addAll(created);
    return created;
  }

  @override
  Future<MemoryState> update(MemoryState state) async {
    updates.add(state);
    final index = states.indexWhere((s) => s.id == state.id);
    if (index >= 0) states[index] = state;
    return state;
  }
}

class FakeReviewRepository implements ReviewRepository {
  final List<ReviewResult> results = [];
  final List<String> completedSessions = [];
  final List<int> completedItemCounts = [];
  Object? addResultError;
  int _seq = 0;

  @override
  Future<ReviewSession> createSession({
    required List<String> vocabularyIds,
  }) async {
    return ReviewSession(
      id: 'session-${_seq++}',
      userId: kTestUserId,
      startedAt: DateTime.now().toUtc(),
      totalItems: vocabularyIds.length,
      completedItems: 0,
    );
  }

  @override
  Future<ReviewSession?> getById(String id) async => null;

  @override
  Future<ReviewSession> completeSession(
    String id, {
    int? completedItems,
  }) async {
    completedSessions.add(id);
    if (completedItems != null) completedItemCounts.add(completedItems);
    return ReviewSession(
      id: id,
      userId: kTestUserId,
      startedAt: DateTime.now().toUtc(),
      completedAt: DateTime.now().toUtc(),
      totalItems: 0,
      completedItems: completedItems ?? 0,
    );
  }

  @override
  Future<ReviewResult> addResult({
    required String sessionId,
    required ReviewResult result,
  }) async {
    if (addResultError != null) throw addResultError!;
    results.add(result);
    return result;
  }
}

class FakeErrorPatternRepository implements ErrorPatternRepository {
  final List<List<String>> upserts = [];

  @override
  Future<List<UserErrorPattern>> getForWord({
    required String vocabularyId,
    int limit = 5,
  }) async =>
      const [];

  @override
  Future<List<UserErrorPattern>> getGlobal({int limit = 5}) async => const [];

  @override
  Future<Map<String, List<UserErrorPattern>>> getForMultipleWords({
    required List<String> vocabularyIds,
    int limit = 5,
  }) async =>
      const {};

  @override
  Future<void> upsertPatterns({
    String? vocabularyId,
    required List<String> patternTexts,
  }) async {
    upserts.add(patternTexts);
  }
}

class FakeDeckRepository implements DeckRepository {
  FakeDeckRepository([List<Deck> decks = const []]) : decks = [...decks];

  final List<Deck> decks;
  Object? createError;
  int _seq = 0;

  @override
  Future<List<Deck>> getAll() async => [...decks];

  @override
  Future<Deck?> getById(String id) async =>
      decks.where((d) => d.id == id).firstOrNull;

  @override
  Future<Deck> create({
    required String name,
    required String language,
    String? description,
  }) async {
    if (createError != null) throw createError!;
    final created = deck('deck-new-${_seq++}', name: name, language: language);
    decks.insert(0, created);
    return created;
  }

  @override
  Future<Deck> update(Deck deck) async => deck;

  @override
  Future<void> delete(String id) async => decks.removeWhere((d) => d.id == id);
}

// ---------------------------------------------------------------------------
// AI services
// ---------------------------------------------------------------------------

class EvalCall {
  EvalCall({
    required this.word,
    required this.definition,
    required this.evalType,
    required this.userAnswer,
  });

  final String word;
  final String definition;
  final String evalType;
  final String userAnswer;
}

class FakeAiEvaluationService implements AiEvaluationService {
  FakeAiEvaluationService(
      {this.meaningScore = 0.9, this.translationScore = 0.9});

  double meaningScore;
  double translationScore;
  final List<EvalCall> calls = [];

  /// When set, evaluations wait for this completer (lets tests fire
  /// concurrent actions while a call is in flight).
  Completer<void>? gate;

  /// Thrown by the next evaluation only (simulates a transient failure).
  Object? nextError;

  @override
  Future<AiEvaluation> evaluateAnswer({
    required String word,
    required String language,
    required String definition,
    required String usage,
    required String userAnswer,
    required String answerType,
    String evalType = 'meaning',
    String? questionContext,
    List<String> knownPatterns = const [],
    String? nativeLanguage,
  }) async {
    calls.add(EvalCall(
      word: word,
      definition: definition,
      evalType: evalType,
      userAnswer: userAnswer,
    ));
    if (gate != null) await gate!.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    final score = evalType == 'translation' ? translationScore : meaningScore;
    return AiEvaluation(
      meaningScore: score,
      usageScore: score,
      exampleScore: score,
      grammarScore: score,
      overallScore: score,
      feedback: 'feedback for $word',
      detectedPatterns: score < 0.6 ? const ['pattern'] : const [],
    );
  }
}

class FakeAiQuestionService implements AiQuestionService {
  int calls = 0;
  Object? error;

  @override
  Future<QuestionContent> generateTranslationQuestion({
    required String word,
    required String language,
    required String definition,
    required String usage,
    required List<String> examples,
    required String nativeLanguage,
  }) async {
    calls++;
    if (error != null) throw error!;
    return QuestionContent(
      questionType: 'translation',
      sentence: 'sentence for $word',
      wordHint: word,
    );
  }
}

class FakeAiExplanationService implements AiExplanationService {
  FakeAiExplanationService(this.vocabRepo);

  final FakeVocabularyRepository vocabRepo;
  final List<String> calls = [];
  Object? error;
  Completer<void>? gate;

  @override
  Future<VocabularyItem> generateExplanation({
    required String vocabularyId,
    required String word,
    required String language,
    required String nativeLanguage,
  }) async {
    calls.add(vocabularyId);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    final current = vocabRepo.items.firstWhere((v) => v.id == vocabularyId);
    final updated = current.copyWith(
      definition: 'generated definition of $word',
      explanation: 'generated explanation of $word',
      usage: 'generated usage of $word',
      examples: ['generated example of $word'],
    );
    await vocabRepo.update(updated);
    return updated;
  }
}
