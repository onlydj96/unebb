import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/core/constants/languages.dart';
import 'package:unebb/domain/models/word_reading.dart';

import '../helpers/fakes.dart';

void main() {
  group('SupportedLanguages.normalize', () {
    test('maps ISO codes to the app names', () {
      expect(SupportedLanguages.normalize('ja'), 'Japanese');
      expect(SupportedLanguages.normalize(' JA-jp '), 'Japanese');
      expect(SupportedLanguages.normalize('ja_JP'), 'Japanese');
      expect(SupportedLanguages.normalize('en'), 'English');
      expect(SupportedLanguages.normalize('es'), 'Spanish');
    });

    test('keeps names and unknown values', () {
      expect(SupportedLanguages.normalize('Japanese'), 'Japanese');
      expect(SupportedLanguages.normalize('japanese'), 'Japanese');
      expect(SupportedLanguages.normalize('Klingon'), 'Klingon');
    });
  });

  group('WordReading', () {
    test('Japanese is recognised by name or code', () {
      expect(vocab('a', language: 'ja').isJapanese, isTrue);
      expect(vocab('a', language: 'Japanese').isJapanese, isTrue);
      expect(vocab('a', language: 'English').isJapanese, isFalse);
    });

    test('displayReading hides missing and redundant readings', () {
      expect(
          vocab('a', word: '相手', pronunciation: 'あいて').displayReading, 'あいて');
      expect(
          vocab('a', word: 'うつ', pronunciation: 'うつ').displayReading, isNull);
      expect(vocab('a', word: '相手', pronunciation: ' ').displayReading, isNull);
      expect(vocab('a', word: '相手').displayReading, isNull);
    });

    test('lacksKanjiReadings flags Japanese content without a kana reading',
        () {
      bool lacks(String? reading) => vocab(
            'a',
            word: '病院',
            language: 'ja',
            pronunciation: reading,
          ).lacksKanjiReadings;

      expect(lacks(null), isTrue);
      expect(lacks('/byōin/'), isTrue);
      expect(lacks('病院'), isTrue);
      expect(lacks('びょういん'), isFalse);
      expect(lacks('コーヒー'), isFalse);
      expect(
        vocab('a', language: 'English', pronunciation: '/əˈdʒeɪsənt/')
            .lacksKanjiReadings,
        isFalse,
      );
    });
  });
}
