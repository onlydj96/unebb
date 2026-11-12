import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/data/services/ai_question_service.dart';
import 'package:unebb/domain/models/ai_evaluation.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/review_result.dart';
import 'package:unebb/domain/models/review_session.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/vocabulary/providers/ai_content_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

// ---------------------------------------------------------------------------
// Phase enum — each value maps to a unique UI widget
// ---------------------------------------------------------------------------

enum ReviewPhase {
  loading,
  empty,
  complete,
  error,
  showWord, // Flash card front — just the word
  askKnowledge, // Ask user if they know the word (know/don't know)
  generatingExplanation, // AI generating explanation for unknown word
  showExplanation, // Show explanation for unknown word (user said "don't know")
  meaningInput, // Card revealed — user types meaning
  evaluatingMeaning, // Calling AI for meaning eval
  meaningFailed, // Score < 0.6: show correct meaning + explanation
  generatingTranslation, // AI generating native-language sentence
  translationInput, // User translates sentence → target language
  evaluatingTranslation, // Calling AI for translation eval
  showResult, // Final result: combined score + pattern badges
}

/// Weight of the meaning step in the combined score (translation = rest).
const double kMeaningWeight = 0.4;

/// Below this AI score an answer counts as wrong (SM-2 grade < 3).
const double kPassScore = 0.6;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ReviewUiState {
  const ReviewUiState({
    this.phase = ReviewPhase.loading,
    this.session,
    this.memoryStates = const {},
    this.currentIndex = 0,
    this.sessionMode = 'due',
    this.sessionDeckId,
    this.sessionLimit,
    this.nativeLanguage = 'Korean',
    this.meaningAnswer,
    this.meaningEvaluation,
    this.translationAnswer,
    this.translationSentence,
    this.wordHint,
    this.translationEvaluation,
    this.combinedScore,
    this.previousStrength = 0.0,
    this.updatedStrength = 0.0,
    this.currentGraded = false,
    this.correctCount = 0,
    this.completedBefore = 0,
    this.wordPatterns = const [],
    this.globalPatterns = const [],
    this.allWordPatterns = const {},
    this.error,
    this.canRetryStep = false,
  });

  final ReviewPhase phase;
  final ReviewSession? session;
  final Map<String, MemoryState> memoryStates;

  /// Index of the current word inside [session].
  final int currentIndex;

  // Session parameters (used for retry / resume)
  final String sessionMode;
  final String? sessionDeckId;
  final int? sessionLimit;

  final String nativeLanguage;

  // Step 1 — meaning
  final String? meaningAnswer;
  final AiEvaluation? meaningEvaluation;

  // Step 2 — translation
  final String? translationAnswer;
  final String? translationSentence;
  final String? wordHint;
  final AiEvaluation? translationEvaluation;

  /// Score the memory model was fed for the current word.
  final double? combinedScore;

  final double previousStrength;
  final double updatedStrength;

  /// Whether the current word's memory state has already been updated.
  final bool currentGraded;

  /// Correct answers in the whole session (including resumed parts).
  final int correctCount;

  /// Words finished before this (resumed) session started.
  final int completedBefore;

  final List<String> wordPatterns;
  final List<String> globalPatterns;
  final Map<String, List<String>> allWordPatterns;

  /// Last failure (mapped to a friendly message by the UI).
  final Object? error;

  /// True when [error] came from a single step that can be retried or
  /// skipped without losing the session.
  final bool canRetryStep;

  VocabularyItem? get currentItem =>
      session?.vocabularyItems.elementAtOrNull(currentIndex);

  MemoryState? get currentMemoryState =>
      currentItem != null ? memoryStates[currentItem!.id] : null;

  /// Words in this (possibly resumed) session.
  int get totalItems => session?.vocabularyItems.length ?? 0;

  /// Words in the whole session, including parts finished before a resume.
  int get sessionTotalCount => completedBefore + totalItems;
  int get sessionCorrectCount => correctCount;

  /// 1-based position of the current word in the whole session.
  int get sessionPosition => completedBefore + currentIndex + 1;

  /// Fraction of the whole session already finished (0.0–1.0).
  double get sessionProgress => sessionTotalCount == 0
      ? 0
      : (completedBefore + currentIndex) / sessionTotalCount;

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
    double? combinedScore,
    double? previousStrength,
    double? updatedStrength,
    bool? currentGraded,
    int? correctCount,
    List<String>? wordPatterns,
    Object? error,
    bool? canRetryStep,
    bool clearError = false,
    bool clearStepData = false,
  }) {
    return ReviewUiState(
      phase: phase ?? this.phase,
      session: session ?? this.session,
      memoryStates: memoryStates ?? this.memoryStates,
      currentIndex: currentIndex ?? this.currentIndex,
      sessionMode: sessionMode,
      sessionDeckId: sessionDeckId,
      sessionLimit: sessionLimit,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      meaningAnswer: clearStepData ? null : meaningAnswer ?? this.meaningAnswer,
      meaningEvaluation:
          clearStepData ? null : meaningEvaluation ?? this.meaningEvaluation,
      translationAnswer:
          clearStepData ? null : translationAnswer ?? this.translationAnswer,
      translationSentence: clearStepData
          ? null
          : translationSentence ?? this.translationSentence,
      wordHint: clearStepData ? null : wordHint ?? this.wordHint,
      translationEvaluation: clearStepData
          ? null
          : translationEvaluation ?? this.translationEvaluation,
      combinedScore: clearStepData ? null : combinedScore ?? this.combinedScore,
      previousStrength: previousStrength ?? this.previousStrength,
      updatedStrength: updatedStrength ?? this.updatedStrength,
      currentGraded:
          clearStepData ? false : currentGraded ?? this.currentGraded,
      correctCount: correctCount ?? this.correctCount,
      completedBefore: completedBefore,
      wordPatterns: wordPatterns ?? this.wordPatterns,
      globalPatterns: globalPatterns,
      allWordPatterns: allWordPatterns,
      error: clearError || clearStepData ? null : error ?? this.error,
      canRetryStep: clearError || clearStepData
          ? false
          : canRetryStep ?? this.canRetryStep,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ReviewNotifier extends StateNotifier<ReviewUiState> {
  ReviewNotifier(this._ref) : super(const ReviewUiState());

  final Ref _ref;

  /// Incremented by every session (re)start so stale loads are discarded.
  int _epoch = 0;

  /// Recovery for the last failed step (null → restart the whole session).
  ReviewPhase? _retryPhase;
  Future<void> Function()? _retryAction;

  /// Translation question requested ahead of time for [_prefetchFor].
  String? _prefetchFor;
  Future<QuestionContent?>? _prefetch;

  /// Words graded in this session (stored as `completed_items`).
  final Set<String> _gradedIds = {};

  /// Ignores updates after the screen closed (the provider is auto-disposed
  /// while AI calls may still be running).
  void _emit(ReviewUiState next) {
    if (mounted) state = next;
  }

  bool _isCurrent(int index) => mounted && state.currentIndex == index;

  // ── Session lifecycle ──────────────────────────────────────────────────────

  Future<void> startSession({
    String mode = 'due',
    int? limit,
    String? deckId,
  }) async {
    final epoch = _resetForNewSession();
    _emit(ReviewUiState(
      phase: ReviewPhase.loading,
      sessionMode: mode,
      sessionDeckId: deckId,
      sessionLimit: limit,
    ));

    try {
      final vocabRepo = _ref.read(vocabularyRepositoryProvider);
      final memRepo = _ref.read(memoryStateRepositoryProvider);

      // 1. Everything independent in parallel: words, memory states (one
      //    query, ordered client-side), global patterns and the learner's
      //    native language (falls back to the default if the profile fails).
      final results = await Future.wait<Object?>([
        deckId != null ? vocabRepo.getByDeckId(deckId) : vocabRepo.getAll(),
        memRepo.getAll(),
        _loadGlobalPatterns(),
        readNativeLanguage(_ref),
      ]);
      if (!_isLive(epoch)) return;

      final words = results[0] as List<VocabularyItem>;
      var states = results[1] as List<MemoryState>;
      final globalPatterns = results[2] as List<String>;
      final nativeLanguage = results[3] as String;

      if (words.isEmpty) {
        _emit(state.copyWith(phase: ReviewPhase.empty));
        return;
      }

      // 2. Words that never got a memory state (older data, failed insert).
      final known = {for (final s in states) s.vocabularyId};
      final missing = [
        for (final w in words)
          if (!known.contains(w.id)) w.id,
      ];
      if (missing.isNotEmpty) {
        states = [
          ...states,
          ...await memRepo.createBatch(vocabularyIds: missing),
        ];
        if (!_isLive(epoch)) return;
      }

      // 3. Select and order (new words first, then weighted priority).
      final wordsById = {for (final w in words) w.id: w};
      final queue = _ref.read(reviewQueueBuilderProvider).build(
            states.where((s) => wordsById.containsKey(s.vocabularyId)).toList(),
            mode: mode,
          );
      final selected =
          limit != null && limit < queue.length ? queue.take(limit) : queue;
      if (selected.isEmpty) {
        _emit(state.copyWith(phase: ReviewPhase.empty));
        return;
      }

      await _beginSession(
        epoch: epoch,
        items: [for (final s in selected) wordsById[s.vocabularyId]!],
        states: {for (final s in selected) s.vocabularyId: s},
        mode: mode,
        deckId: deckId,
        limit: limit,
        nativeLanguage: nativeLanguage,
        globalPatterns: globalPatterns,
      );
    } catch (e, st) {
      if (_isLive(epoch)) _fail(e, st);
    }
  }

  /// Restart the session with the same parameters.
  Future<void> retrySession() => startSession(
        mode: state.sessionMode,
        limit: state.sessionLimit,
        deckId: state.sessionDeckId,
      );

  /// Resume a previously interrupted session from cached progress.
  Future<void> resumeSession(ReviewSessionProgress progress) async {
    final epoch = _resetForNewSession();
    _emit(ReviewUiState(
      phase: ReviewPhase.loading,
      sessionMode: progress.mode,
      sessionDeckId: progress.deckId,
      sessionLimit: progress.limit,
    ));

    try {
      final vocabRepo = _ref.read(vocabularyRepositoryProvider);
      final memRepo = _ref.read(memoryStateRepositoryProvider);
      final deckId = progress.deckId;

      final results = await Future.wait<Object?>([
        deckId != null ? vocabRepo.getByDeckId(deckId) : vocabRepo.getAll(),
        memRepo.getAll(),
        _loadGlobalPatterns(),
        readNativeLanguage(_ref),
      ]);
      if (!_isLive(epoch)) return;

      final wordsById = {
        for (final w in results[0] as List<VocabularyItem>) w.id: w,
      };
      final statesById = {
        for (final s in results[1] as List<MemoryState>) s.vocabularyId: s,
      };

      final start =
          progress.currentIndex.clamp(0, progress.vocabularyIds.length);
      final items = [
        for (final id in progress.vocabularyIds.sublist(start))
          if (wordsById.containsKey(id) && statesById.containsKey(id))
            wordsById[id]!,
      ];

      if (items.isEmpty) {
        await clearSavedProgress();
        _emit(state.copyWith(phase: ReviewPhase.empty));
        return;
      }

      await _beginSession(
        epoch: epoch,
        items: items,
        states: {for (final item in items) item.id: statesById[item.id]!},
        mode: progress.mode,
        deckId: deckId,
        limit: progress.limit,
        nativeLanguage: results[3] as String,
        globalPatterns: results[2] as List<String>,
        correctCount: progress.correctCount,
        completedBefore: progress.completedCount,
      );
      await clearSavedProgress();
    } catch (e, st) {
      if (_isLive(epoch)) _fail(e, st);
    }
  }

  Future<void> _beginSession({
    required int epoch,
    required List<VocabularyItem> items,
    required Map<String, MemoryState> states,
    required String mode,
    required String? deckId,
    required int? limit,
    required String? nativeLanguage,
    required List<String> globalPatterns,
    int correctCount = 0,
    int completedBefore = 0,
  }) async {
    final ids = [for (final item in items) item.id];
    final results = await Future.wait<Object?>([
      _ref.read(reviewRepositoryProvider).createSession(vocabularyIds: ids),
      _loadAllWordPatterns(ids),
    ]);
    if (!_isLive(epoch)) return;

    final session = (results[0] as ReviewSession).copyWith(
      vocabularyItems: items,
      totalItems: items.length,
    );
    final patterns = results[1] as Map<String, List<String>>;

    _emit(ReviewUiState(
      phase: ReviewPhase.showWord,
      session: session,
      memoryStates: states,
      sessionMode: mode,
      sessionDeckId: deckId,
      sessionLimit: limit,
      nativeLanguage: nativeLanguage ?? 'Korean',
      wordPatterns: patterns[items.first.id] ?? const [],
      globalPatterns: globalPatterns,
      allWordPatterns: patterns,
      correctCount: correctCount,
      completedBefore: completedBefore,
    ));
    _prepareAhead();
  }

  int _resetForNewSession() {
    _clearRecovery();
    _prefetch = null;
    _prefetchFor = null;
    _gradedIds.clear();
    return ++_epoch;
  }

  bool _isLive(int epoch) => mounted && epoch == _epoch;

  // ── Progress persistence ───────────────────────────────────────────────────

  /// Save the current position so the session can be resumed later.
  Future<void> saveProgress() async {
    final session = state.session;
    if (session == null) return;
    const nonSaveablePhases = {
      ReviewPhase.loading,
      ReviewPhase.empty,
      ReviewPhase.complete,
    };
    if (nonSaveablePhases.contains(state.phase)) return;

    // A word whose answer was already graded must not be asked again.
    final nextIndex = state.currentIndex + (state.currentGraded ? 1 : 0);
    if (nextIndex >= session.vocabularyItems.length) {
      await clearSavedProgress();
      return;
    }

    try {
      await _ref.read(cacheServiceProvider).saveReviewProgress(
            ReviewSessionProgress(
              mode: state.sessionMode,
              deckId: state.sessionDeckId,
              limit: state.sessionLimit,
              vocabularyIds: [for (final v in session.vocabularyItems) v.id],
              currentIndex: nextIndex,
              correctCount: state.correctCount,
              completedBefore: state.completedBefore,
              savedAt: DateTime.now(),
            ),
          );
    } catch (e) {
      AppLogger.warning('Failed to save review progress', details: e);
    }
  }

  /// Clear saved progress (called when a session completes normally).
  Future<void> clearSavedProgress() async {
    try {
      await _ref.read(cacheServiceProvider).clearReviewProgress();
    } catch (e) {
      AppLogger.warning('Failed to clear review progress', details: e);
    }
  }

  /// Saved progress matching the given parameters, if any.
  ReviewSessionProgress? getSavedProgress({
    String mode = 'due',
    int? limit,
    String? deckId,
  }) {
    try {
      return _ref.read(cacheServiceProvider).getMatchingReviewProgress(
            mode: mode,
            limit: limit,
            deckId: deckId,
          );
    } catch (e) {
      AppLogger.warning('Failed to read review progress', details: e);
      return null;
    }
  }

  // ── User actions ───────────────────────────────────────────────────────────

  /// Flip the card: showWord → askKnowledge.
  void tapWord() {
    if (state.phase != ReviewPhase.showWord) return;
    _emit(state.copyWith(phase: ReviewPhase.askKnowledge));
  }

  /// User says they know the word → meaning input.
  void answerKnowWord() {
    if (state.phase != ReviewPhase.askKnowledge) return;
    _emit(state.copyWith(phase: ReviewPhase.meaningInput));
    prefetchTranslation();
  }

  /// Starts generating the translation exercise while the learner types the
  /// meaning, so step 2 usually opens without waiting for the AI.
  void prefetchTranslation() {
    final item = state.currentItem;
    if (item == null || !hasAiContent(item) || _prefetchFor == item.id) return;
    _prefetchFor = item.id;
    _prefetch = _generateQuestion(item);
  }

  /// User says they don't know the word → grade as a miss and show the
  /// explanation. Also accepted from [ReviewPhase.showWord] (voice mode
  /// answers without flipping the card).
  Future<void> answerDontKnowWord() async {
    if (state.phase != ReviewPhase.askKnowledge &&
        state.phase != ReviewPhase.showWord) {
      return;
    }
    final item = state.currentItem;
    if (item == null || state.currentMemoryState == null) return;
    final index = state.currentIndex;

    // Grade right away; the explanation is loaded in parallel.
    final grading = _grade(
      item: item,
      index: index,
      score: 0.0,
      evaluation: const AiEvaluation(
        feedback: 'User indicated they do not know this word',
      ),
      answerType: 'skip',
      questionType: 'knowledge',
      userAnswer: '',
    );

    if (!needsAiContentUpdate(item) &&
        (item.explanation?.isNotEmpty ?? false)) {
      _emit(state.copyWith(phase: ReviewPhase.showExplanation));
    } else {
      _emit(state.copyWith(phase: ReviewPhase.generatingExplanation));
      await _ensureContent(item);
      if (_isCurrent(index) &&
          state.phase == ReviewPhase.generatingExplanation) {
        // Shows whatever is available if generation failed.
        _emit(state.copyWith(phase: ReviewPhase.showExplanation));
      }
    }
    await grading;
  }

  /// Called after viewing the explanation.
  Future<void> nextAfterExplanation() => nextWord();

  /// Called from the "meaning failed" view.
  Future<void> nextAfterFailed() => nextWord();

  /// Step 1: submit the meaning. Also accepted from [ReviewPhase.showWord] /
  /// [ReviewPhase.askKnowledge] for voice answers.
  Future<void> submitMeaning(String userAnswer) async {
    const allowed = {
      ReviewPhase.meaningInput,
      ReviewPhase.showWord,
      ReviewPhase.askKnowledge,
    };
    final fromPhase = state.phase;
    if (!allowed.contains(fromPhase)) return;
    final item = state.currentItem;
    if (item == null || state.currentMemoryState == null) return;
    final index = state.currentIndex;

    _emit(state.copyWith(
      phase: ReviewPhase.evaluatingMeaning,
      meaningAnswer: userAnswer,
    ));

    try {
      // Words whose AI content is missing (generation failed or still
      // running) cannot be evaluated — produce it first.
      final ready = await _ensureContent(item);
      if (ready == null) throw AiContentUnavailableException(word: item.word);

      final evaluation =
          await _ref.read(aiEvaluationServiceProvider).evaluateAnswer(
                word: ready.word,
                language: ready.language,
                definition: ready.definition ?? '',
                usage: ready.usage ?? '',
                userAnswer: userAnswer,
                answerType: 'text',
                evalType: 'meaning',
                knownPatterns: [...state.wordPatterns, ...state.globalPatterns],
                nativeLanguage: state.nativeLanguage,
              );
      if (!_isCurrent(index)) return;

      if (evaluation.overallScore < kPassScore) {
        unawaited(_persistPatterns(ready.id, evaluation.detectedPatterns));
        await _grade(
          item: ready,
          index: index,
          score: evaluation.overallScore,
          evaluation: evaluation,
          answerType: 'text',
          questionType: 'meaning',
          userAnswer: userAnswer,
          onGraded: (s) => s.copyWith(
            phase: ReviewPhase.meaningFailed,
            meaningEvaluation: evaluation,
            combinedScore: evaluation.overallScore,
          ),
        );
        return;
      }

      _emit(state.copyWith(
        phase: ReviewPhase.generatingTranslation,
        meaningEvaluation: evaluation,
      ));
      final question = await _translationQuestion(ready);
      if (!_isCurrent(index)) return;

      if (question == null) {
        // No exercise available — grade on the meaning alone.
        await _finalizeWord(item: ready, index: index);
      } else {
        _emit(state.copyWith(
          phase: ReviewPhase.translationInput,
          translationSentence: question.sentence,
          wordHint: question.wordHint,
        ));
      }
    } catch (e, st) {
      if (!_isCurrent(index)) return;
      _fail(
        e,
        st,
        retryPhase: fromPhase,
        retry: () => submitMeaning(userAnswer),
      );
    }
  }

  /// Step 2: submit the translation.
  Future<void> submitTranslation(String userAnswer) async {
    if (state.phase != ReviewPhase.translationInput) return;
    final item = state.currentItem;
    if (item == null || state.currentMemoryState == null) return;
    final index = state.currentIndex;

    _emit(state.copyWith(
      phase: ReviewPhase.evaluatingTranslation,
      translationAnswer: userAnswer,
    ));

    try {
      final evaluation =
          await _ref.read(aiEvaluationServiceProvider).evaluateAnswer(
                word: item.word,
                language: item.language,
                definition: item.definition ?? '',
                usage: item.usage ?? '',
                userAnswer: userAnswer,
                answerType: 'text',
                evalType: 'translation',
                questionContext: state.translationSentence,
                knownPatterns: [...state.wordPatterns, ...state.globalPatterns],
                nativeLanguage: state.nativeLanguage,
              );
      if (!_isCurrent(index)) return;

      // Pattern bookkeeping must not delay the result.
      unawaited(_persistPatterns(item.id, [
        ...?state.meaningEvaluation?.detectedPatterns,
        ...evaluation.detectedPatterns,
      ]));

      await _finalizeWord(
        item: item,
        index: index,
        translationEvaluation: evaluation,
        translationAnswer: userAnswer,
      );
    } catch (e, st) {
      if (!_isCurrent(index)) return;
      _fail(
        e,
        st,
        retryPhase: ReviewPhase.translationInput,
        retry: () => submitTranslation(userAnswer),
      );
    }
  }

  /// Advance to the next word (or complete the session).
  ///
  /// Only valid once the current word is finished (or from an error, which
  /// skips the word) — repeated taps during a transition are ignored.
  Future<void> nextWord() async {
    const allowed = {
      ReviewPhase.showResult,
      ReviewPhase.meaningFailed,
      ReviewPhase.showExplanation,
      ReviewPhase.error,
    };
    final session = state.session;
    if (!allowed.contains(state.phase) ||
        session == null ||
        state.currentItem == null) {
      return;
    }

    _clearRecovery();
    _prefetch = null;
    _prefetchFor = null;

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= session.vocabularyItems.length) {
      _emit(state.copyWith(phase: ReviewPhase.complete, clearError: true));
      try {
        await _ref
            .read(reviewRepositoryProvider)
            .completeSession(session.id, completedItems: _gradedIds.length);
      } catch (e) {
        AppLogger.warning('Failed to complete review session', details: e);
      }
      await clearSavedProgress();
      return;
    }

    final nextItem = session.vocabularyItems[nextIndex];
    _emit(state.copyWith(
      phase: ReviewPhase.showWord,
      currentIndex: nextIndex,
      wordPatterns: state.allWordPatterns[nextItem.id] ?? const [],
      clearStepData: true,
    ));
    _prepareAhead();
  }

  /// Retry after an error: re-runs the failed step when possible, otherwise
  /// restarts the session.
  Future<void> retry() async {
    final phase = _retryPhase;
    final action = _retryAction;
    _clearRecovery();
    if (phase == null || action == null || state.session == null) {
      await retrySession();
      return;
    }
    _emit(state.copyWith(phase: phase, clearError: true));
    await action();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _fail(
    Object error,
    StackTrace stackTrace, {
    ReviewPhase? retryPhase,
    Future<void> Function()? retry,
  }) {
    AppLogger.error('Review step failed', error: error, stackTrace: stackTrace);
    _retryPhase = retryPhase;
    _retryAction = retry;
    _emit(state.copyWith(
      phase: ReviewPhase.error,
      error: error,
      canRetryStep: retry != null && state.session != null,
    ));
  }

  void _clearRecovery() {
    _retryPhase = null;
    _retryAction = null;
  }

  /// Returns [item] with AI content (generating it when missing, adding kanji
  /// readings to older Japanese content) and keeps the session copy in sync.
  /// Null when the content cannot be produced.
  Future<VocabularyItem?> _ensureContent(VocabularyItem item) async {
    if (!needsAiContentUpdate(item)) return item;
    final ready =
        await _ref.read(aiContentProvider.notifier).ensureCurrent(item);
    // The screen may have closed while generating (often via _prepareAhead,
    // which does not await): reading `state` then would throw.
    if (ready == null || !mounted) return ready;
    final session = state.session;
    if (session != null) {
      _emit(state.copyWith(
        session: session.copyWith(vocabularyItems: [
          for (final v in session.vocabularyItems) v.id == ready.id ? ready : v,
        ]),
      ));
    }
    return ready;
  }

  /// Makes sure the current and the next two words have up-to-date AI
  /// content before the learner reaches them.
  void _prepareAhead() {
    final items = state.session?.vocabularyItems ?? const <VocabularyItem>[];
    for (var i = state.currentIndex;
        i < items.length && i <= state.currentIndex + 2;
        i++) {
      if (needsAiContentUpdate(items[i])) unawaited(_ensureContent(items[i]));
    }
  }

  Future<QuestionContent?> _translationQuestion(VocabularyItem item) async {
    final prefetched = _prefetchFor == item.id ? _prefetch : null;
    _prefetch = null;
    _prefetchFor = null;
    final question = prefetched != null ? await prefetched : null;
    if (question != null || !mounted) return question;
    // A failed prefetch gets one fresh attempt.
    return _generateQuestion(item);
  }

  /// Never throws; null means "no exercise available".
  Future<QuestionContent?> _generateQuestion(VocabularyItem item) async {
    try {
      final question = await _ref
          .read(aiQuestionServiceProvider)
          .generateTranslationQuestion(
            word: item.word,
            language: item.language,
            definition: item.definition ?? '',
            usage: item.usage ?? '',
            examples: item.examples ?? const [],
            nativeLanguage: state.nativeLanguage,
          );
      return question.sentence.trim().isEmpty ? null : question;
    } catch (e, st) {
      AppLogger.warning(
        'Failed to generate translation question',
        details: {'vocabularyId': item.id, 'error': e},
      );
      AppLogger.debug('Translation generation stack trace', data: st);
      return null;
    }
  }

  /// Combines both steps, grades the word and shows the result.
  Future<void> _finalizeWord({
    required VocabularyItem item,
    required int index,
    AiEvaluation? translationEvaluation,
    String? translationAnswer,
  }) async {
    final meaningEvaluation = state.meaningEvaluation ?? const AiEvaluation();
    final transScore = translationEvaluation?.overallScore;
    final combined = transScore != null
        ? meaningEvaluation.overallScore * kMeaningWeight +
            transScore * (1 - kMeaningWeight)
        : meaningEvaluation.overallScore;
    final correct = _ref.read(memoryServiceProvider).isCorrectAnswer(combined);

    await _grade(
      item: item,
      index: index,
      score: combined,
      evaluation: translationEvaluation ?? meaningEvaluation,
      answerType: 'text',
      questionType: translationEvaluation != null ? 'translation' : 'meaning',
      userAnswer: translationAnswer ?? state.meaningAnswer ?? '',
      questionContext:
          translationEvaluation != null ? state.translationSentence : null,
      onGraded: (s) => s.copyWith(
        phase: ReviewPhase.showResult,
        translationEvaluation: translationEvaluation,
        combinedScore: combined,
        correctCount: correct ? s.correctCount + 1 : s.correctCount,
      ),
    );
  }

  /// Applies SM-2 for one word, shows the outcome immediately and persists
  /// it. Persistence failures are logged, never surfaced as a broken session:
  /// the memory state drives scheduling, the history row is best-effort.
  Future<void> _grade({
    required VocabularyItem item,
    required int index,
    required double score,
    required AiEvaluation evaluation,
    required String answerType,
    required String questionType,
    required String userAnswer,
    String? questionContext,
    ReviewUiState Function(ReviewUiState graded)? onGraded,
  }) async {
    final memState = state.memoryStates[item.id];
    final session = state.session;
    if (memState == null || session == null) return;

    final updated =
        _ref.read(memoryServiceProvider).applySmTwo(memState, score);
    _gradedIds.add(item.id);

    var next = state.copyWith(
      memoryStates: {...state.memoryStates, item.id: updated},
    );
    if (_isCurrent(index)) {
      next = next.copyWith(
        previousStrength: memState.memoryStrength,
        updatedStrength: updated.memoryStrength,
        currentGraded: true,
      );
      if (onGraded != null) next = onGraded(next);
    }
    _emit(next);

    // Keep dashboard / deck screens in sync without a refetch.
    if (_ref.exists(memoryStatesMapNotifierProvider)) {
      _ref.read(memoryStatesMapNotifierProvider.notifier).updateState(updated);
    }

    await Future.wait([
      _persistMemoryState(updated),
      _persistResult(ReviewResult(
        id: '',
        userId: session.userId,
        sessionId: session.id,
        vocabularyId: item.id,
        userAnswer: userAnswer,
        answerType: answerType,
        questionType: questionType,
        questionContext: questionContext,
        aiEvaluation: evaluation,
        previousMemoryStrength: memState.memoryStrength,
        updatedMemoryStrength: updated.memoryStrength,
        reviewedAt: DateTime.now().toUtc(),
      )),
    ]);
  }

  Future<void> _persistMemoryState(MemoryState updated) async {
    try {
      await _ref.read(memoryStateRepositoryProvider).update(updated);
    } catch (e, st) {
      AppLogger.error('Failed to save memory state', error: e, stackTrace: st);
    }
  }

  Future<void> _persistResult(ReviewResult result) async {
    try {
      await _ref
          .read(reviewRepositoryProvider)
          .addResult(sessionId: result.sessionId, result: result);
    } catch (e, st) {
      AppLogger.warning('Failed to save review history', details: e);
      AppLogger.debug('Review history stack trace', data: st);
    }
  }

  /// Persist detected patterns (word-specific + global). Errors are logged
  /// and swallowed — pattern bookkeeping must not break the review flow.
  Future<void> _persistPatterns(
    String vocabularyId,
    List<String> patterns,
  ) async {
    if (patterns.isEmpty) return;
    try {
      final repo = _ref.read(errorPatternRepositoryProvider);
      await Future.wait([
        repo.upsertPatterns(vocabularyId: vocabularyId, patternTexts: patterns),
        repo.upsertPatterns(vocabularyId: null, patternTexts: patterns),
      ]);
    } catch (e, st) {
      AppLogger.warning(
        'Failed to persist error patterns',
        details: {'vocabularyId': vocabularyId, 'error': e},
      );
      AppLogger.debug('Pattern persistence stack trace', data: st);
    }
  }

  /// Patterns for all session words in one batch query.
  Future<Map<String, List<String>>> _loadAllWordPatterns(
    List<String> vocabularyIds,
  ) async {
    try {
      final patternsMap = await _ref
          .read(errorPatternRepositoryProvider)
          .getForMultipleWords(vocabularyIds: vocabularyIds);
      return patternsMap.map(
        (key, value) => MapEntry(key, [for (final p in value) p.patternText]),
      );
    } catch (e, st) {
      AppLogger.warning('Failed to load word patterns in batch', details: e);
      AppLogger.debug('Batch patterns loading stack trace', data: st);
      return const {};
    }
  }

  Future<List<String>> _loadGlobalPatterns() async {
    try {
      final patterns =
          await _ref.read(errorPatternRepositoryProvider).getGlobal();
      return [for (final p in patterns) p.patternText];
    } catch (e, st) {
      AppLogger.warning('Failed to load global error patterns', details: e);
      AppLogger.debug('Global patterns loading stack trace', data: st);
      return const [];
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Scoped to the review screen: a new visit starts from a clean state instead
/// of flashing the previous session.
final reviewNotifierProvider =
    StateNotifierProvider.autoDispose<ReviewNotifier, ReviewUiState>(
  (ref) => ReviewNotifier(ref),
);
