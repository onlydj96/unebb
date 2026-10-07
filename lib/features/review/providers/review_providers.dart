import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Error
    this.error,
  });

  final ReviewPhase phase;
  final ReviewSession? session;
  final Map<String, MemoryState> memoryStates;
  final int currentIndex;

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
    String? error,
    bool clearStepData = false,
  }) {
    return ReviewUiState(
      phase: phase ?? this.phase,
      session: session ?? this.session,
      memoryStates: memoryStates ?? this.memoryStates,
      currentIndex: currentIndex ?? this.currentIndex,
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

  Future<void> startSession() async {
    state = const ReviewUiState(phase: ReviewPhase.loading);
    try {
      final memRepo = _ref.read(memoryStateRepositoryProvider);
      final reviewRepo = _ref.read(reviewRepositoryProvider);

      final dueStates = await memRepo.getDueForReview();
      if (dueStates.isEmpty) {
        state = const ReviewUiState(phase: ReviewPhase.empty);
        return;
      }

      final vocabIds = dueStates.map((s) => s.vocabularyId).toList();
      final session = await reviewRepo.createSession(vocabularyIds: vocabIds);

      final reviewable = session.vocabularyItems
          .where((item) => item.definition != null)
          .toList();

      if (reviewable.isEmpty) {
        state = const ReviewUiState(phase: ReviewPhase.empty);
        return;
      }

      final filteredSession = session.copyWith(
        vocabularyItems: reviewable,
        totalItems: reviewable.length,
      );
      final stateMap = {for (final ms in dueStates) ms.vocabularyId: ms};

      // Load patterns for the first item
      final firstItem = filteredSession.vocabularyItems.first;
      final wordPats = await _loadWordPatterns(firstItem.id);
      final globalPats = await _loadGlobalPatterns();

      state = ReviewUiState(
        phase: ReviewPhase.showWord,
        session: filteredSession,
        memoryStates: stateMap,
        currentIndex: 0,
        wordPatterns: wordPats,
        globalPatterns: globalPats,
      );
    } catch (e) {
      state = ReviewUiState(phase: ReviewPhase.error, error: e.toString());
    }
  }

  // ── Public: user actions ───────────────────────────────────────────────────

  /// Flip the card: showWord → meaningInput.
  void tapWord() {
    if (state.phase != ReviewPhase.showWord) return;
    state = state.copyWith(phase: ReviewPhase.meaningInput);
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
      final wordPats = await _loadWordPatterns(nextItem.id);

      state = state.copyWith(
        phase: ReviewPhase.showWord,
        currentIndex: nextIndex,
        wordPatterns: wordPats,
        clearStepData: true,
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _generateTranslation(VocabularyItem item) async {
    try {
      final profile = await _ref.read(profileProvider.future);
      final nativeLanguage = profile?.nativeLanguage ?? 'Korean';

      final question = await _ref
          .read(aiQuestionServiceProvider)
          .generateTranslationQuestion(
            word: item.word,
            language: item.language,
            definition: item.definition!,
            usage: item.usage ?? '',
            examples: item.examples ?? [],
            nativeLanguage: nativeLanguage,
          );

      state = state.copyWith(
        phase: ReviewPhase.translationInput,
        translationSentence: question.sentence,
        wordHint: question.wordHint,
      );
    } catch (_) {
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
  /// Errors are swallowed — pattern persistence must not break the review flow.
  Future<void> _persistPatterns({
    required String vocabularyId,
    required List<String> patterns,
  }) async {
    if (patterns.isEmpty) return;
    try {
      final repo = _ref.read(errorPatternRepositoryProvider);
      await repo.upsertPatterns(
        vocabularyId: vocabularyId,
        patternTexts: patterns,
      );
      await repo.upsertPatterns(
        vocabularyId: null,
        patternTexts: patterns,
      );
    } catch (_) {}
  }

  Future<List<String>> _loadWordPatterns(String vocabularyId) async {
    try {
      final patterns = await _ref
          .read(errorPatternRepositoryProvider)
          .getForWord(vocabularyId: vocabularyId);
      return patterns.map((p) => p.patternText).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _loadGlobalPatterns() async {
    try {
      final patterns =
          await _ref.read(errorPatternRepositoryProvider).getGlobal();
      return patterns.map((p) => p.patternText).toList();
    } catch (_) {
      return [];
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final reviewNotifierProvider =
    StateNotifierProvider<ReviewNotifier, ReviewUiState>(
  (ref) => ReviewNotifier(ref),
);
