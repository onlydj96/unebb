/// Supported languages for vocabulary learning.
abstract class SupportedLanguages {
  SupportedLanguages._();

  /// Languages available for vocabulary words.
  static const List<String> learning = [
    'English',
    'Spanish',
    'French',
    'German',
    'Japanese',
    'Chinese',
    'Korean',
    'Italian',
    'Portuguese',
    'Russian',
  ];

  /// Languages available for native language selection.
  static const List<String> native = [
    'English',
    'Korean',
    'Spanish',
    'French',
    'German',
    'Japanese',
    'Chinese',
    'Italian',
    'Portuguese',
    'Russian',
  ];

  /// Default learning language.
  static const String defaultLearning = 'English';

  /// Default native language.
  static const String defaultNative = 'Korean';

  static const String japanese = 'Japanese';

  static const Map<String, String> _isoCodes = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ja': 'Japanese',
    'jp': 'Japanese',
    'zh': 'Chinese',
    'ko': 'Korean',
    'kr': 'Korean',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
  };

  /// The app's name for [language], also when it is stored as an ISO code
  /// ('ja', 'ja-JP' → 'Japanese'). Unknown values are returned trimmed.
  static String normalize(String language) {
    final value = language.trim();
    final key = value.toLowerCase();
    for (final name in learning) {
      if (name.toLowerCase() == key) return name;
    }
    return _isoCodes[key] ??
        _isoCodes[key.split(RegExp('[-_]')).first] ??
        value;
  }
}
