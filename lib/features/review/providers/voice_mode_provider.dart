import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unebb/data/services/voice_mode_service.dart';

/// Voice mode phases for the review workflow
enum VoiceModePhase {
  idle,
  speakingWord, // TTS: Speaking the vocabulary word
  askingKnowledge, // TTS: Asking "Do you know this word?"
  listeningKnowledge, // STT: Listening for yes/no response
  waitingMeaning, // STT: Waiting for user to explain meaning
  listeningMeaning, // STT: Actively listening for meaning
  processingMeaning, // Processing meaning answer
  speakingFeedback, // TTS: Speaking feedback for meaning
  speakingExample, // TTS: Speaking the translation sentence
  waitingTranslation, // STT: Waiting for user to translate
  listeningTranslation, // STT: Actively listening for translation
  processingTranslation, // Processing translation answer
  speakingResult, // TTS: Speaking final feedback
}

/// Interprets a spoken answer to "Do you know this word?" (true = knows it).
///
/// Negations are checked first and Latin-script answers are matched by whole
/// words. The previous substring match read "I don't know" (contains
/// "know"), "모르겠어요" (contains "어"), "不知道" (contains "知道") and
/// "no sé" (contains "sé") as "yes". Unclear answers count as "don't know".
bool parseKnowsWordAnswer(String transcript) {
  final text = transcript.toLowerCase().replaceAll('’', "'").trim();
  if (text.isEmpty) return false;

  final words = text
      .split(RegExp(r"[^\p{L}']+", unicode: true))
      .where((w) => w.isNotEmpty)
      .toSet();

  const negativeWords = {
    'no', 'not', 'nope', 'nah', 'never', "don't", 'dont', "doesn't", //
    'idk', 'non', 'nein', 'nada',
  };
  // Scripts without spaces (and Korean endings) need fragment matching.
  const negativeFragments = [
    '몰라', '모르', '모름', '아니', '아뇨', '글쎄', //
    'いいえ', '知らない', 'しらない', '分からない', 'わからない', '分かりません',
    'わかりません', '不知道', '不是', '不懂', '不会', '没有', '不',
  ];
  if (words.any(negativeWords.contains) ||
      negativeFragments.any(text.contains)) {
    return false;
  }

  const positiveWords = {
    'yes', 'yeah', 'yep', 'yup', 'sure', 'know', 'ok', 'okay', //
    'si', 'sí', 'sé', 'claro', 'oui', 'ja',
  };
  const positiveFragments = [
    '네', '예', '응', '알아', '알고', '알지', //
    'はい', 'うん', 'ええ', '知って', '分かる', 'わかる',
    '是', '对', '知道', '懂', '会',
  ];
  // A lone "어" means yes; inside words (e.g. "모르겠어요") it does not.
  return text == '어' ||
      words.any(positiveWords.contains) ||
      positiveFragments.any(text.contains);
}

/// State for voice mode
class VoiceModeState {
  const VoiceModeState({
    this.isEnabled = false,
    this.phase = VoiceModePhase.idle,
    this.isInitialized = false,
    this.currentTranscript = '',
    this.error,
    this.isTtsReady = false,
    this.isSttReady = false,
  });

  final bool isEnabled;
  final VoiceModePhase phase;
  final bool isInitialized;
  final String currentTranscript;
  final String? error;
  final bool isTtsReady;
  final bool isSttReady;

  bool get isActive => isEnabled && isInitialized;
  bool get isSpeaking =>
      phase == VoiceModePhase.speakingWord ||
      phase == VoiceModePhase.speakingFeedback ||
      phase == VoiceModePhase.speakingExample ||
      phase == VoiceModePhase.speakingResult;
  bool get isListening =>
      phase == VoiceModePhase.listeningKnowledge ||
      phase == VoiceModePhase.listeningMeaning ||
      phase == VoiceModePhase.listeningTranslation;

  VoiceModeState copyWith({
    bool? isEnabled,
    VoiceModePhase? phase,
    bool? isInitialized,
    String? currentTranscript,
    String? error,
    bool? isTtsReady,
    bool? isSttReady,
    bool clearError = false,
    bool clearTranscript = false,
  }) {
    return VoiceModeState(
      isEnabled: isEnabled ?? this.isEnabled,
      phase: phase ?? this.phase,
      isInitialized: isInitialized ?? this.isInitialized,
      currentTranscript:
          clearTranscript ? '' : (currentTranscript ?? this.currentTranscript),
      error: clearError ? null : (error ?? this.error),
      isTtsReady: isTtsReady ?? this.isTtsReady,
      isSttReady: isSttReady ?? this.isSttReady,
    );
  }
}

/// Notifier for voice mode state management
class VoiceModeNotifier extends StateNotifier<VoiceModeState> {
  VoiceModeNotifier({VoiceModeService? service})
      : _service = service ?? VoiceModeService(),
        super(const VoiceModeState()) {
    _setupCallbacks();
  }

  final VoiceModeService _service;

  // Callbacks registered by the active voice view (see [bindCallbacks]).
  void Function(bool knowsWord)? onKnowledgeResult;
  void Function(String transcript)? onMeaningResult;
  void Function(String transcript)? onTranslationResult;
  void Function()? onSpeakingComplete;

  /// The view that registered the current callbacks.
  Object? _callbackOwner;

  /// Registers the callbacks of [owner], replacing any previous view's.
  ///
  /// During an AnimatedSwitcher transition the outgoing view is disposed
  /// *after* the incoming one registered; ownership makes sure the outgoing
  /// view's [clearCallbacks] cannot wipe the new view's callbacks.
  void bindCallbacks(
    Object owner, {
    void Function(bool knowsWord)? onKnowledgeResult,
    void Function(String transcript)? onMeaningResult,
    void Function(String transcript)? onTranslationResult,
    void Function()? onSpeakingComplete,
  }) {
    _callbackOwner = owner;
    this.onKnowledgeResult = onKnowledgeResult;
    this.onMeaningResult = onMeaningResult;
    this.onTranslationResult = onTranslationResult;
    this.onSpeakingComplete = onSpeakingComplete;
  }

  void _setupCallbacks() {
    _service.onSpeechResult = (transcript) {
      state = state.copyWith(currentTranscript: transcript);

      if (state.phase == VoiceModePhase.listeningKnowledge) {
        onKnowledgeResult?.call(parseKnowsWordAnswer(transcript));
      } else if (state.phase == VoiceModePhase.listeningMeaning) {
        onMeaningResult?.call(transcript);
      } else if (state.phase == VoiceModePhase.listeningTranslation) {
        onTranslationResult?.call(transcript);
      }
    };

    _service.onSpeechEnd = () {
      if (state.phase == VoiceModePhase.listeningKnowledge) {
        // If no clear response, default to "don't know"
        if (state.currentTranscript.isEmpty) {
          onKnowledgeResult?.call(false);
        }
      } else if (state.phase == VoiceModePhase.listeningMeaning) {
        state = state.copyWith(phase: VoiceModePhase.processingMeaning);
      } else if (state.phase == VoiceModePhase.listeningTranslation) {
        state = state.copyWith(phase: VoiceModePhase.processingTranslation);
      }
    };

    _service.onTtsDone = () {
      onSpeakingComplete?.call();
    };

    _service.onError = (error) {
      state = state.copyWith(error: error);
    };
  }

  /// Initialize voice services
  Future<bool> initialize() async {
    if (state.isInitialized) return true;

    final success = await _service.initialize();
    state = state.copyWith(
      isInitialized: success,
      isTtsReady: _service.isTtsReady,
      isSttReady: _service.isSttReady,
    );
    return success;
  }

  /// Toggle voice mode on/off
  Future<void> toggleVoiceMode() async {
    if (!state.isEnabled) {
      // Turning on
      if (!state.isInitialized) {
        final ok = await initialize();
        if (!ok) {
          state = state.copyWith(error: 'Failed to initialize voice services');
          return;
        }
      }
      state = state.copyWith(isEnabled: true, clearError: true);
    } else {
      // Turning off
      await _service.stop();
      await _service.cancelListening();
      state = state.copyWith(
        isEnabled: false,
        phase: VoiceModePhase.idle,
        clearTranscript: true,
      );
    }
  }

  /// Speak the vocabulary word
  Future<void> speakWord(String word, String language) async {
    if (!state.isActive) return;

    state = state.copyWith(
        phase: VoiceModePhase.speakingWord, clearTranscript: true);
    await _service.speak(word, language: language);
  }

  /// Ask if user knows the word
  Future<void> askKnowledge(String prompt, String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(
        phase: VoiceModePhase.askingKnowledge, clearTranscript: true);
    await _service.speak(prompt, language: nativeLanguage);
  }

  /// Start listening for knowledge confirmation (yes/no)
  Future<void> startListeningKnowledge(String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(
      phase: VoiceModePhase.listeningKnowledge,
      clearTranscript: true,
    );
    await _service.startListening(
      language: nativeLanguage,
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
    );
  }

  /// Start listening for meaning explanation
  Future<void> startListeningMeaning(String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(
      phase: VoiceModePhase.listeningMeaning,
      clearTranscript: true,
    );
    await _service.startListening(language: nativeLanguage);
  }

  /// Speak feedback after meaning evaluation (or a prompt for the next step).
  ///
  /// Clears the transcript: the previous step's answer (e.g. "yes") must not
  /// be offered for submission as the answer to the next prompt.
  Future<void> speakFeedback(String feedback, String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(
      phase: VoiceModePhase.speakingFeedback,
      clearTranscript: true,
    );
    await _service.speak(feedback, language: nativeLanguage);
  }

  /// Speak the translation example sentence. Clears the meaning transcript so
  /// it cannot be submitted as the translation.
  Future<void> speakExample(String sentence, String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(
      phase: VoiceModePhase.speakingExample,
      clearTranscript: true,
    );
    await _service.speak(sentence, language: nativeLanguage);
  }

  /// Start listening for translation
  Future<void> startListeningTranslation(String targetLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(
      phase: VoiceModePhase.listeningTranslation,
      clearTranscript: true,
    );
    await _service.startListening(language: targetLanguage);
  }

  /// Speak the final result feedback
  Future<void> speakResult(String feedback, String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(phase: VoiceModePhase.speakingResult);
    await _service.speak(feedback, language: nativeLanguage);
  }

  /// Stop any ongoing speech or listening
  Future<void> stop() async {
    await _service.stop();
    await _service.cancelListening();
    state = state.copyWith(phase: VoiceModePhase.idle);
  }

  /// Set waiting state for meaning
  void setWaitingMeaning() {
    state = state.copyWith(phase: VoiceModePhase.waitingMeaning);
  }

  /// Set waiting state for translation
  void setWaitingTranslation() {
    state = state.copyWith(phase: VoiceModePhase.waitingTranslation);
  }

  /// Set idle state
  void setIdle() {
    state = state.copyWith(phase: VoiceModePhase.idle, clearTranscript: true);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clears the callbacks — only if [owner] registered them (or when no
  /// owner is given, e.g. on dispose).
  void clearCallbacks([Object? owner]) {
    if (owner != null && !identical(owner, _callbackOwner)) return;
    _callbackOwner = null;
    onKnowledgeResult = null;
    onMeaningResult = null;
    onTranslationResult = null;
    onSpeakingComplete = null;
  }

  @override
  void dispose() {
    clearCallbacks();
    // Use unawaited since StateNotifier.dispose() is synchronous
    // The service will clean up TTS/STT resources asynchronously
    unawaited(_service.dispose());
    super.dispose();
  }
}

/// Provider for voice mode
final voiceModeProvider =
    StateNotifierProvider<VoiceModeNotifier, VoiceModeState>(
  (ref) => VoiceModeNotifier(),
);
