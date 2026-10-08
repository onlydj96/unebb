import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Service for handling Text-to-Speech and Speech-to-Text operations
class VoiceModeService {
  VoiceModeService();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _isTtsInitialized = false;
  bool _isSttInitialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  // Callbacks
  void Function(String)? onSpeechResult;
  void Function()? onSpeechEnd;
  void Function()? onTtsDone;
  void Function(String)? onError;

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  bool get isTtsReady => _isTtsInitialized;
  bool get isSttReady => _isSttInitialized;

  /// Initialize TTS engine
  Future<bool> initTts() async {
    if (_isTtsInitialized) return true;

    try {
      await _tts.setSharedInstance(true);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onTtsDone?.call();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        onError?.call('TTS Error: $msg');
      });

      // Default settings
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _isTtsInitialized = true;
      return true;
    } catch (e) {
      onError?.call('Failed to initialize TTS: $e');
      return false;
    }
  }

  /// Initialize STT engine
  Future<bool> initStt() async {
    if (_isSttInitialized) return true;

    try {
      _isSttInitialized = await _stt.initialize(
        onError: (error) {
          _isListening = false;
          onError?.call('STT Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onSpeechEnd?.call();
          }
        },
      );
      return _isSttInitialized;
    } catch (e) {
      onError?.call('Failed to initialize STT: $e');
      return false;
    }
  }

  /// Initialize both TTS and STT
  Future<bool> initialize() async {
    final ttsOk = await initTts();
    final sttOk = await initStt();
    return ttsOk && sttOk;
  }

  /// Set TTS language based on vocabulary language
  Future<void> setTtsLanguage(String language) async {
    if (!_isTtsInitialized) return;

    // Map common language names to locale codes
    final localeMap = {
      'English': 'en-US',
      'Korean': 'ko-KR',
      'Japanese': 'ja-JP',
      'Spanish': 'es-ES',
      'French': 'fr-FR',
      'German': 'de-DE',
      'Chinese': 'zh-CN',
      'Portuguese': 'pt-BR',
      'Italian': 'it-IT',
      'Russian': 'ru-RU',
    };

    final locale = localeMap[language] ?? 'en-US';
    await _tts.setLanguage(locale);
  }

  /// Set STT language for recognition
  String getSttLocale(String language) {
    final localeMap = {
      'English': 'en_US',
      'Korean': 'ko_KR',
      'Japanese': 'ja_JP',
      'Spanish': 'es_ES',
      'French': 'fr_FR',
      'German': 'de_DE',
      'Chinese': 'zh_CN',
      'Portuguese': 'pt_BR',
      'Italian': 'it_IT',
      'Russian': 'ru_RU',
    };
    return localeMap[language] ?? 'en_US';
  }

  /// Speak text using TTS
  Future<void> speak(String text, {String? language}) async {
    if (!_isTtsInitialized) {
      final ok = await initTts();
      if (!ok) return;
    }

    // Stop any ongoing speech
    await stop();

    if (language != null) {
      await setTtsLanguage(language);
    }

    _isSpeaking = true;
    await _tts.speak(text);
  }

  /// Stop TTS
  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  /// Start listening for speech input
  Future<void> startListening({
    required String language,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isSttInitialized) {
      final ok = await initStt();
      if (!ok) return;
    }

    if (_isListening) {
      await stopListening();
    }

    // Stop TTS if speaking
    await stop();

    final locale = getSttLocale(language);

    _isListening = true;
    await _stt.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      onSpeechResult?.call(result.recognizedWords);
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _stt.stop();
      _isListening = false;
    }
  }

  /// Cancel listening without triggering result
  Future<void> cancelListening() async {
    if (_isListening) {
      await _stt.cancel();
      _isListening = false;
    }
  }

  /// Get available TTS languages
  Future<List<String>> getAvailableLanguages() async {
    if (!_isTtsInitialized) return [];
    try {
      final languages = await _tts.getLanguages;
      return List<String>.from(languages);
    } catch (_) {
      return [];
    }
  }

  /// Get available STT locales
  Future<List<String>> getAvailableLocales() async {
    if (!_isSttInitialized) return [];
    try {
      final locales = await _stt.locales();
      return locales.map((l) => l.localeId).toList();
    } catch (_) {
      return [];
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await cancelListening();
    _isTtsInitialized = false;
    _isSttInitialized = false;
    onSpeechResult = null;
    onSpeechEnd = null;
    onTtsDone = null;
    onError = null;
  }
}
