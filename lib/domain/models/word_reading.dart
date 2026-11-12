import 'package:unebb/core/constants/languages.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';

final _kanaOnly = RegExp(r'^[ぁ-ゖァ-ヺー・\s]+$');

/// Readings of Japanese words: kanji are unreadable without them, so every
/// screen outside of a question shows the hiragana reading.
extension WordReading on VocabularyItem {
  bool get isJapanese =>
      SupportedLanguages.normalize(language) == SupportedLanguages.japanese;

  /// Pronunciation to show under the word; null when there is none or when
  /// it would only repeat the word (kana-only Japanese words).
  String? get displayReading {
    final reading = pronunciation?.trim();
    if (reading == null || reading.isEmpty || reading == word.trim()) {
      return null;
    }
    return reading;
  }

  /// Japanese content generated before kanji readings were required (or for
  /// a word stored with the 'ja' code, which skipped them): the pronunciation
  /// is missing or not a kana reading (e.g. IPA "/byōin/"), and the texts
  /// carry no hiragana. New content always has a kana pronunciation.
  bool get lacksKanjiReadings {
    if (!isJapanese) return false;
    final reading = pronunciation?.trim() ?? '';
    return !_kanaOnly.hasMatch(reading);
  }
}
