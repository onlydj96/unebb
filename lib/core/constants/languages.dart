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
}
