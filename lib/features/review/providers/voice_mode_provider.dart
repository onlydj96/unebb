import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unebb/data/services/voice_mode_service.dart';

/// Voice mode phases for the review workflow
enum VoiceModePhase {
  idle,
  speakingWord,           // TTS: Speaking the vocabulary word
  askingKnowledge,        // TTS: Asking "Do you know this word?"
  listeningKnowledge,     // STT: Listening for yes/no response
  waitingMeaning,         // STT: Waiting for user to explain meaning
  listeningMeaning,       // STT: Actively listening for meaning
  processingMeaning,      // Processing meaning answer
  speakingFeedback,       // TTS: Speaking feedback for meaning
  speakingExample,        // TTS: Speaking the translation sentence
  waitingTranslation,     // STT: Waiting for user to translate
  listeningTranslation,   // STT: Actively listening for translation
  processingTranslation,  // Processing translation answer
  speakingResult,         // TTS: Speaking final feedback
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
  bool get isSpeaking => phase == VoiceModePhase.speakingWord ||
      phase == VoiceModePhase.speakingFeedback ||
      phase == VoiceModePhase.speakingExample ||
      phase == VoiceModePhase.speakingResult;
  bool get isListening => phase == VoiceModePhase.listeningKnowledge ||
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
      currentTranscript: clearTranscript ? '' : (currentTranscript ?? this.currentTranscript),
      error: clearError ? null : (error ?? this.error),
      isTtsReady: isTtsReady ?? this.isTtsReady,
      isSttReady: isSttReady ?? this.isSttReady,
    );
  }
}

/// Notifier for voice mode state management
class VoiceModeNotifier extends StateNotifier<VoiceModeState> {
  VoiceModeNotifier() : super(const VoiceModeState()) {
    _service = VoiceModeService();
    _setupCallbacks();
  }

  late final VoiceModeService _service;

  // Callbacks that can be set by the review notifier
  void Function(bool knowsWord)? onKnowledgeResult;
  void Function(String transcript)? onMeaningResult;
  void Function(String transcript)? onTranslationResult;
  void Function()? onSpeakingComplete;

  void _setupCallbacks() {
    _service.onSpeechResult = (transcript) {
      state = state.copyWith(currentTranscript: transcript);

      if (state.phase == VoiceModePhase.listeningKnowledge) {
        // Parse yes/no response
        final lower = transcript.toLowerCase();
        final knowsWord = _isPositiveResponse(lower);
        onKnowledgeResult?.call(knowsWord);
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

  /// Check if the response indicates "yes/know"
  bool _isPositiveResponse(String text) {
    // English positive responses
    const englishPositive = ['yes', 'yeah', 'yep', 'yup', 'sure', 'know', 'i know', 'yes i know'];
    // Korean positive responses
    const koreanPositive = ['네', '예', '응', '어', '알아', '알아요', '알고 있어', '알고 있어요', '알겠어'];
    // Japanese positive responses
    const japanesePositive = ['はい', 'うん', 'ええ', '知ってる', '分かる', 'わかる'];
    // Chinese positive responses
    const chinesePositive = ['是', '是的', '对', '知道', '我知道', '懂'];
    // Spanish positive responses
    const spanishPositive = ['sí', 'si', 'claro', 'sé', 'lo sé', 'conozco'];

    final allPositive = [
      ...englishPositive,
      ...koreanPositive,
      ...japanesePositive,
      ...chinesePositive,
      ...spanishPositive,
    ];

    return allPositive.any((p) => text.contains(p));
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

    state = state.copyWith(phase: VoiceModePhase.speakingWord, clearTranscript: true);
    await _service.speak(word, language: language);
  }

  /// Ask if user knows the word
  Future<void> askKnowledge(String prompt, String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(phase: VoiceModePhase.askingKnowledge, clearTranscript: true);
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

  /// Speak feedback after meaning evaluation
  Future<void> speakFeedback(String feedback, String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(phase: VoiceModePhase.speakingFeedback);
    await _service.speak(feedback, language: nativeLanguage);
  }

  /// Speak the translation example sentence
  Future<void> speakExample(String sentence, String nativeLanguage) async {
    if (!state.isActive) return;

    state = state.copyWith(phase: VoiceModePhase.speakingExample);
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

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// Provider for voice mode
final voiceModeProvider = StateNotifierProvider<VoiceModeNotifier, VoiceModeState>(
  (ref) => VoiceModeNotifier(),
);
