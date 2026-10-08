import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/ai_evaluation.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/review_result.dart';
import 'package:unebb/domain/models/review_session.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';

// ---------------------------------------------------------------------------
// Phase enum — each value maps to a unique UI widget
// ---------------------------------------------------------------------------

enum ReviewPhase {
  loading,
  empty,
  complete,
  error,
  showWord,              // Flash card front — just the word
  askKnowledge,          // Ask user if they know the word (know/don't know)
  generatingExplanation, // AI generating explanation for unknown word
  showExplanation,       // Show explanation for unknown word (user said "don't know")
  meaningInput,          // Card revealed — user types meaning
  evaluatingMeaning,     // Calling AI for meaning eval
  meaningFailed,         // Score < 0.6: show correct meaning + explanation
  generatingTranslation, // AI generating native-language sentence
  translationInput,      // User translates sentence → target language
  evaluatingTranslation, // Calling AI for translation eval
  showResult,            // Final result: combined score + pattern badges
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ReviewUiState {
  const ReviewUiState({
    this.phase = ReviewPhase.loading,
    this.session,
    this.memoryStates = const {},
    this.currentIndex = 0,
    // Cached profile data
    this.nativeLanguage = 'Korean',
    // Step 1 — meaning
    this.meaningAnswer,
    this.meaningEvaluation,
    // Step 2 — translation
    this.translationAnswer,
    this.translationSentence,
    this.wordHint,
    this.translationEvaluation,
    // Result
    this.previousStrength = 0.0,
    this.updatedStrength = 0.0,
    this.correctCount = 0,
    // Error patterns
    this.wordPatterns = const [],
    this.globalPatterns = const [],
    this.allWordPatterns = const {},
    // Error
    this.error,
  });

  final ReviewPhase phase;
  final ReviewSession? session;
  final Map<String, MemoryState> memoryStates;
  final int currentIndex;

  // Cached profile data
  final String nativeLanguage;

  final String? meaningAnswer;
  final AiEvaluation? meaningEvaluation;

  final String? translationAnswer;
  final String? translationSentence;
  final String? wordHint;
  final AiEvaluation? translationEvaluation;

  final double previousStrength;
  final double updatedStrength;
  final int correctCount;

  final List<String> wordPatterns;
  final List<String> globalPatterns;

  // Preloaded patterns for all words in session
  final Map<String, List<String>> allWordPatterns;

  final String? error;

  VocabularyItem? get currentItem =>
      session?.vocabularyItems.elementAtOrNull(currentIndex);

  MemoryState? get currentMemoryState =>
      currentItem != null ? memoryStates[currentItem!.id] : null;

  int get totalItems => session?.vocabularyItems.length ?? 0;

  /// Combined detected patterns from both steps (for result view).
  List<String> get allDetectedPatterns => [
        ...?meaningEvaluation?.detectedPatterns,
        ...?translationEvaluation?.detectedPatterns,
      ];

  ReviewUiState copyWith({
    ReviewPhase? phase,
    ReviewSession? session,
    Map<String, MemoryState>? memoryStates,
    int? currentIndex,
    String? nativeLanguage,
    String? meaningAnswer,
    AiEvaluation? meaningEvaluation,
    String? translationAnswer,
    String? translationSentence,
    String? wordHint,
    AiEvaluation? translationEvaluation,
    double? previousStrength,
    double? updatedStrength,
    int? correctCount,
    List<String>? wordPatterns,
    List<String>? globalPatterns,
    Map<String, List<String>>? allWordPatterns,
    String? error,
    bool clearStepData = false,
  }) {
    return ReviewUiState(
      phase: phase ?? this.phase,
      session: session ?? this.session,
      memoryStates: memoryStates ?? this.memoryStates,
      currentIndex: currentIndex ?? this.currentIndex,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      meaningAnswer: clearStepData ? null : meaningAnswer ?? this.meaningAnswer,
      meaningEvaluation:
          clearStepData ? null : meaningEvaluation ?? this.meaningEvaluation,
      translationAnswer:
          clearStepData ? null : translationAnswer ?? this.translationAnswer,
      translationSentence:
          clearStepData ? null : translationSentence ?? this.translationSentence,
      wordHint: clearStepData ? null : wordHint ?? this.wordHint,
      translationEvaluation: clearStepData
          ? null
          : translationEvaluation ?? this.translationEvaluation,
      previousStrength: previousStrength ?? this.previousStrength,
      updatedStrength: updatedStrength ?? this.updatedStrength,
      correctCount: correctCount ?? this.correctCount,
      wordPatterns: wordPatterns ?? this.wordPatterns,
      globalPatterns: globalPatterns ?? this.globalPatterns,
      allWordPatterns: allWordPatterns ?? this.allWordPatterns,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ReviewNotifier extends StateNotifier<ReviewUiState> {
  ReviewNotifier(this._ref) : super(const ReviewUiState());

  final Ref _ref;

  // ── Public: session lifecycle ──────────────────────────────────────────────

  Future<void> startSession({String mode = 'due', int? limit, String? deckId}) async {
    state = const ReviewUiState(phase: ReviewPhase.loading);
    try {
      final memRepo = _ref.read(memoryStateRepositoryProvider);
      final vocabRepo = _ref.read(vocabularyRepositoryProvider);
      final reviewRepo = _ref.read(reviewRepositoryProvider);

      // 1. Get vocabulary items (optionally filtered by deck)
      final allVocabItems = deckId != null
          ? await vocabRepo.getByDeckId(deckId)
          : await vocabRepo.getAll();
      AppLogger.debug('Vocabulary items loaded', data: {'count': allVocabItems.length, 'deckId': deckId});

      if (allVocabItems.isEmpty) {
        AppLogger.warning('No vocabulary items found');
        state = const ReviewUiState(phase: ReviewPhase.empty);
        return;
      }

      // 2. Parallel: get existing memory states IDs + global patterns + profile
      final [existingVocabIds, globalPats, profile] = await Future.wait([
        memRepo.getExistingVocabularyIds(),
        _loadGlobalPatterns(),
        _ref.read(profileProvider.future),
      ]);
      final nativeLang = (profile as dynamic)?.nativeLanguage ?? 'Korean';

      // 3. Find vocabulary items without memory_states and create them
      final vocabIdsWithoutState = allVocabItems
          .where((v) => !(existingVocabIds as Set<String>).contains(v.id))
          .map((v) => v.id)
          .toList();

      if (vocabIdsWithoutState.isNotEmpty) {
        AppLogger.debug('Creating memory states', data: {'count': vocabIdsWithoutState.length});
        await memRepo.createBatch(vocabularyIds: vocabIdsWithoutState);
      }

      // 4. Get all memory states (existing + newly created)
      final allStates = await (mode == 'all'
          ? memRepo.getAllForReview()
          : memRepo.getDueForReview());

      AppLogger.debug('Memory states loaded', data: {'count': allStates.length});

      if (allStates.isEmpty) {
        AppLogger.warning('No memory states found for review');
        state = const ReviewUiState(phase: ReviewPhase.empty);
        return;
      }

      // 5. Reorder vocabulary items to match shuffled memory state order
      final vocabById = {for (final v in allVocabItems) v.id: v};
      var reviewable = allStates
          .where((ms) => vocabById.containsKey(ms.vocabularyId))
          .map((ms) => vocabById[ms.vocabularyId]!)
          .toList();

      AppLogger.debug('Reviewable vocabulary items ordered by memory states', data: {
        'count': reviewable.length,
        'first_10_words': reviewable.take(10).map((v) => v.word).toList(),
      });

      if (reviewable.isEmpty) {
        state = const ReviewUiState(phase: ReviewPhase.empty);
        return;
      }

      // 6. Apply limit (already in priority order from memory state shuffle)
      final limitedReviewable = limit != null && limit < reviewable.length
          ? reviewable.take(limit).toList()
          : reviewable;

      AppLogger.debug('Final limited reviewable', data: {
        'count': limitedReviewable.length,
        'first_10_words': limitedReviewable.take(10).map((v) => v.word).toList(),
      });

      // Build memory state map for limited items
      final limitedVocabIds = limitedReviewable.map((v) => v.id).toSet();
      final limitedStates = allStates
          .where((ms) => limitedVocabIds.contains(ms.vocabularyId))
          .toList();

      // 7. Create session
      final vocabIds = limitedReviewable.map((v) => v.id).toList();
      final session = await reviewRepo.createSession(vocabularyIds: vocabIds);

      final filteredSession = session.copyWith(
        vocabularyItems: limitedReviewable,
        totalItems: limitedReviewable.length,
      );
      final stateMap = {for (final ms in limitedStates) ms.vocabularyId: ms};

      // 8. Preload patterns for ALL words in one batch query
      final allVocabIdsForPatterns = limitedReviewable.map((v) => v.id).toList();
      final patternsMap = await _loadAllWordPatterns(allVocabIdsForPatterns);

      // Get patterns for the first item
      final firstItem = filteredSession.vocabularyItems.first;
      final wordPats = patternsMap[firstItem.id] ?? [];

      state = ReviewUiState(
        phase: ReviewPhase.showWord,
        session: filteredSession,
        memoryStates: stateMap,
        currentIndex: 0,
        nativeLanguage: nativeLang as String,
        wordPatterns: wordPats,
        globalPatterns: globalPats as List<String>,
        allWordPatterns: patternsMap,
      );
    } catch (e) {
      state = ReviewUiState(phase: ReviewPhase.error, error: e.toString());
    }
  }

  // ── Public: user actions ───────────────────────────────────────────────────

  /// Flip the card: showWord → askKnowledge.
  void tapWord() {
    if (state.phase != ReviewPhase.showWord) return;
    state = state.copyWith(phase: ReviewPhase.askKnowledge);
  }

  /// User says they know the word → proceed to meaning input.
  void answerKnowWord() {
    if (state.phase != ReviewPhase.askKnowledge) return;
    state = state.copyWith(phase: ReviewPhase.meaningInput);
  }

  /// User says they don't know the word → show explanation.
  Future<void> answerDontKnowWord() async {
    if (state.phase != ReviewPhase.askKnowledge) return;

    final item = state.currentItem;
    final memState = state.currentMemoryState;
    final session = state.session;
    if (item == null || memState == null || session == null) return;

    // Check if explanation already exists
    if (item.explanation != null && item.explanation!.isNotEmpty) {
      // Use cached explanation
      state = state.copyWith(phase: ReviewPhase.showExplanation);
    } else {
      // Generate explanation via AI
      state = state.copyWith(phase: ReviewPhase.generatingExplanation);
      await _generateAndCacheExplanation(item);
    }

    // Apply SM-2 penalty for not knowing (score = 0)
    final memService = _ref.read(memoryServiceProvider);
    final previousStrength = memState.memoryStrength;
    final updatedMem = memService.applySmTwo(memState, 0.0);
    await _ref.read(memoryStateRepositoryProvider).update(updatedMem);

    // Save review result
    final result = ReviewResult(
      id: '',
      userId: session.userId,
      sessionId: session.id,
      vocabularyId: item.id,
      userAnswer: '',
      answerType: 'skip',
      questionType: 'knowledge',
      questionContext: null,
      aiEvaluation: const AiEvaluation(
        meaningScore: 0.0,
        usageScore: 0.0,
        exampleScore: 0.0,
        grammarScore: 0.0,
        overallScore: 0.0,
        feedback: 'User indicated they do not know this word',
        detectedPatterns: [],
      ),
      previousMemoryStrength: previousStrength,
      updatedMemoryStrength: updatedMem.memoryStrength,
      reviewedAt: DateTime.now().toUtc(),
    );

    await _ref
        .read(reviewRepositoryProvider)
        .addResult(sessionId: session.id, result: result);

    // Update state with new memory state
    final updatedMap = Map<String, MemoryState>.from(state.memoryStates)
      ..[item.id] = updatedMem;

    state = state.copyWith(
      memoryStates: updatedMap,
      previousStrength: previousStrength,
      updatedStrength: updatedMem.memoryStrength,
    );
  }

  /// Called after viewing explanation to proceed to next word.
  Future<void> nextAfterExplanation() async {
    await nextWord();
  }

  /// Step 1: submit meaning answer.
  Future<void> submitMeaning(String userAnswer) async {
    final item = state.currentItem;
    final memState = state.currentMemoryState;
    final session = state.session;
    if (item == null || memState == null || session == null) return;

    state = state.copyWith(
      phase: ReviewPhase.evaluatingMeaning,
      meaningAnswer: userAnswer,
    );

    try {
      final knownPatterns = [...state.wordPatterns, ...state.globalPatterns];

      final evaluation =
          await _ref.read(aiEvaluationServiceProvider).evaluateAnswer(
                word: item.word,
                language: item.language,
                definition: item.definition!,
                usage: item.usage ?? '',
                userAnswer: userAnswer,
                answerType: 'text',
                evalType: 'meaning',
                knownPatterns: knownPatterns,
                nativeLanguage: state.nativeLanguage,
              );

      if (evaluation.overallScore < 0.6) {
        // FAILED: apply SM-2 immediately, save result, show correct meaning
        await _applyAndPersist(
          item: item,
          memState: memState,
          session: session,
          evaluation: evaluation,
          questionType: 'meaning',
          userAnswer: userAnswer,
        );

        await _persistPatterns(
          vocabularyId: item.id,
          patterns: evaluation.detectedPatterns,
        );

        state = state.copyWith(
          phase: ReviewPhase.meaningFailed,
          meaningEvaluation: evaluation,
        );
      } else {
        // PASSED: proceed to translation generation
        state = state.copyWith(
          phase: ReviewPhase.generatingTranslation,
          meaningEvaluation: evaluation,
        );
        await _generateTranslation(item);
      }
    } catch (e) {
      state = state.copyWith(phase: ReviewPhase.error, error: e.toString());
    }
  }

  /// Called from _MeaningFailedView "Next word" button.
  Future<void> nextAfterFailed() async {
    await nextWord();
  }

  /// Step 2: submit translation answer.
  Future<void> submitTranslation(String userAnswer) async {
    final item = state.currentItem;
    final memState = state.currentMemoryState;
    final session = state.session;
    if (item == null || memState == null || session == null) return;

    state = state.copyWith(
      phase: ReviewPhase.evaluatingTranslation,
      translationAnswer: userAnswer,
    );

    try {
      final knownPatterns = [...state.wordPatterns, ...state.globalPatterns];

      final evaluation =
          await _ref.read(aiEvaluationServiceProvider).evaluateAnswer(
                word: item.word,
                language: item.language,
                definition: item.definition!,
                usage: item.usage ?? '',
                userAnswer: userAnswer,
                answerType: 'text',
                evalType: 'translation',
                questionContext: state.translationSentence,
                knownPatterns: knownPatterns,
                nativeLanguage: state.nativeLanguage,
              );

      // Persist patterns from both steps
      final allPatterns = [
        ...?state.meaningEvaluation?.detectedPatterns,
        ...evaluation.detectedPatterns,
      ];
      await _persistPatterns(
        vocabularyId: item.id,
        patterns: allPatterns,
      );

      await _finalizeWord(
        item: item,
        memState: memState,
        session: session,
        translationEvaluation: evaluation,
        translationUserAnswer: userAnswer,
      );
    } catch (e) {
      state = state.copyWith(phase: ReviewPhase.error, error: e.toString());
    }
  }

  /// Advance to the next word (or complete session).
  Future<void> nextWord() async {
    final current = state;
    final session = current.session;
    if (session == null) return;

    final nextIndex = current.currentIndex + 1;

    if (nextIndex >= session.vocabularyItems.length) {
      try {
        await _ref.read(reviewRepositoryProvider).completeSession(session.id);
      } catch (_) {}
      state = current.copyWith(phase: ReviewPhase.complete);
    } else {
      final nextItem = session.vocabularyItems[nextIndex];

      // Optimistic UI update: show next word immediately
      // Use preloaded patterns from allWordPatterns map
      final wordPats = current.allWordPatterns[nextItem.id] ?? [];

      state = state.copyWith(
        phase: ReviewPhase.showWord,
        currentIndex: nextIndex,
        wordPatterns: wordPats,
        clearStepData: true,
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Generate explanation for a word and cache it in the database.
  Future<void> _generateAndCacheExplanation(VocabularyItem item) async {
    try {
      final updatedItem = await _ref
          .read(aiExplanationServiceProvider)
          .generateExplanation(
            vocabularyId: item.id,
            word: item.word,
            language: item.language,
            nativeLanguage: state.nativeLanguage,
          );

      // Update the session with the new vocabulary item data
      final session = state.session;
      if (session != null) {
        final updatedItems = session.vocabularyItems.map((v) {
          return v.id == item.id ? updatedItem : v;
        }).toList();

        state = state.copyWith(
          phase: ReviewPhase.showExplanation,
          session: session.copyWith(vocabularyItems: updatedItems),
        );
      } else {
        state = state.copyWith(phase: ReviewPhase.showExplanation);
      }
    } catch (e) {
      // If generation fails, still show explanation view with available data
      AppLogger.warning(
        'Failed to generate explanation',
        details: {'vocabularyId': item.id, 'error': e},
      );
      state = state.copyWith(phase: ReviewPhase.showExplanation);
    }
  }

  Future<void> _generateTranslation(VocabularyItem item) async {
    try {
      final question = await _ref
          .read(aiQuestionServiceProvider)
          .generateTranslationQuestion(
            word: item.word,
            language: item.language,
            definition: item.definition!,
            usage: item.usage ?? '',
            examples: item.examples ?? [],
            nativeLanguage: state.nativeLanguage,
          );

      state = state.copyWith(
        phase: ReviewPhase.translationInput,
        translationSentence: question.sentence,
        wordHint: question.wordHint,
      );
    } catch (e, stackTrace) {
      // Log translation generation failure
      AppLogger.warning(
        'Failed to generate translation question',
        details: {'vocabularyId': item.id, 'word': item.word, 'error': e},
      );
      AppLogger.debug('Translation generation stack trace', data: stackTrace);

      // Generation failed — finalize using meaning-only score
      final item2 = state.currentItem;
      final memState2 = state.currentMemoryState;
      final session2 = state.session;
      final evaluation = state.meaningEvaluation;
      if (item2 == null || memState2 == null || session2 == null ||
          evaluation == null) {
        return;
      }

      await _finalizeWord(
        item: item2,
        memState: memState2,
        session: session2,
        translationEvaluation: null,
        translationUserAnswer: null,
      );
    }
  }

  /// Apply SM-2 with combined score and transition to showResult.
  Future<void> _finalizeWord({
    required VocabularyItem item,
    required MemoryState memState,
    required ReviewSession session,
    required AiEvaluation? translationEvaluation,
    required String? translationUserAnswer,
  }) async {
    final meaningScore = state.meaningEvaluation!.overallScore;
    final transScore = translationEvaluation?.overallScore;

    // Combined: meaning 40% + translation 60%
    final combinedScore = transScore != null
        ? meaningScore * 0.4 + transScore * 0.6
        : meaningScore;

    final memService = _ref.read(memoryServiceProvider);
    final previousStrength = memState.memoryStrength;
    final updatedMem = memService.applySmTwo(memState, combinedScore);

    await _ref.read(memoryStateRepositoryProvider).update(updatedMem);

    if (translationEvaluation != null) {
      final result = ReviewResult(
        id: '',
        userId: session.userId,
        sessionId: session.id,
        vocabularyId: item.id,
        userAnswer: translationUserAnswer ?? '',
        answerType: 'text',
        questionType: 'translation',
        questionContext: state.translationSentence,
        aiEvaluation: translationEvaluation,
        previousMemoryStrength: previousStrength,
        updatedMemoryStrength: updatedMem.memoryStrength,
        reviewedAt: DateTime.now().toUtc(),
      );
      await _ref
          .read(reviewRepositoryProvider)
          .addResult(sessionId: session.id, result: result);
    }

    final updatedMap = Map<String, MemoryState>.from(state.memoryStates)
      ..[item.id] = updatedMem;

    final isCorrect = memService.isCorrectAnswer(combinedScore);

    state = state.copyWith(
      phase: ReviewPhase.showResult,
      memoryStates: updatedMap,
      translationEvaluation: translationEvaluation,
      previousStrength: previousStrength,
      updatedStrength: updatedMem.memoryStrength,
      correctCount: isCorrect ? state.correctCount + 1 : state.correctCount,
    );
  }

  /// Apply SM-2 failure immediately (used when meaning step fails).
  Future<void> _applyAndPersist({
    required VocabularyItem item,
    required MemoryState memState,
    required ReviewSession session,
    required AiEvaluation evaluation,
    required String questionType,
    required String userAnswer,
  }) async {
    final memService = _ref.read(memoryServiceProvider);
    final previousStrength = memState.memoryStrength;
    final updatedMem = memService.applySmTwo(memState, evaluation.overallScore);

    await _ref.read(memoryStateRepositoryProvider).update(updatedMem);

    final result = ReviewResult(
      id: '',
      userId: session.userId,
      sessionId: session.id,
      vocabularyId: item.id,
      userAnswer: userAnswer,
      answerType: 'text',
      questionType: questionType,
      questionContext: null,
      aiEvaluation: evaluation,
      previousMemoryStrength: previousStrength,
      updatedMemoryStrength: updatedMem.memoryStrength,
      reviewedAt: DateTime.now().toUtc(),
    );

    await _ref
        .read(reviewRepositoryProvider)
        .addResult(sessionId: session.id, result: result);

    final updatedMap = Map<String, MemoryState>.from(state.memoryStates)
      ..[item.id] = updatedMem;

    state = state.copyWith(
      memoryStates: updatedMap,
      previousStrength: previousStrength,
      updatedStrength: updatedMem.memoryStrength,
    );
  }

  /// Persist detected patterns to Supabase (word-specific + global).
  /// Errors are logged but swallowed — pattern persistence must not break the review flow.
  Future<void> _persistPatterns({
    required String vocabularyId,
    required List<String> patterns,
  }) async {
    if (patterns.isEmpty) return;
    try {
      final repo = _ref.read(errorPatternRepositoryProvider);
      // Run both upsert operations in parallel
      await Future.wait([
        repo.upsertPatterns(
          vocabularyId: vocabularyId,
          patternTexts: patterns,
        ),
        repo.upsertPatterns(
          vocabularyId: null,
          patternTexts: patterns,
        ),
      ]);
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Failed to persist error patterns',
        details: {'vocabularyId': vocabularyId, 'error': e},
      );
      AppLogger.debug('Pattern persistence stack trace', data: stackTrace);
    }
  }

  /// Load patterns for multiple words in one batch query
  Future<Map<String, List<String>>> _loadAllWordPatterns(List<String> vocabularyIds) async {
    try {
      final patternsMap = await _ref
          .read(errorPatternRepositoryProvider)
          .getForMultipleWords(vocabularyIds: vocabularyIds);

      // Convert UserErrorPattern list to string list
      return patternsMap.map((key, value) =>
        MapEntry(key, value.map((p) => p.patternText).toList()));
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Failed to load word patterns in batch',
        details: {'vocabularyIds': vocabularyIds, 'error': e},
      );
      AppLogger.debug('Batch patterns loading stack trace', data: stackTrace);
      return {};
    }
  }

  Future<List<String>> _loadGlobalPatterns() async {
    try {
      final patterns =
          await _ref.read(errorPatternRepositoryProvider).getGlobal();
      return patterns.map((p) => p.patternText).toList();
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Failed to load global error patterns',
        details: e,
      );
      AppLogger.debug('Global patterns loading stack trace', data: stackTrace);
      return [];
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final reviewNotifierProvider =
    StateNotifierProvider<ReviewNotifier, ReviewUiState>(
  (ref) {
    // Keep provider alive during active review sessions
    ref.keepAlive();
    return ReviewNotifier(ref);
  },
);
