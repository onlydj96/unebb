import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/features/review/providers/voice_mode_provider.dart';

void main() {
  group('parseKnowsWordAnswer', () {
    for (final answer in [
      'yes',
      'Yeah, I know it',
      'sure',
      '네',
      '알아요',
      '어',
      'はい',
      '知ってる',
      '知道',
      '是的',
      'sí, lo sé',
    ]) {
      test('"$answer" means the learner knows the word', () {
        expect(parseKnowsWordAnswer(answer), isTrue);
      });
    }

    for (final answer in [
      "I don't know",
      'I don’t know',
      'no',
      'not really',
      'nope',
      '몰라요',
      '모르겠어요',
      '아니요',
      'いいえ',
      'わからない',
      '不知道',
      '不是',
      'no sé',
      '',
      'umm',
    ]) {
      test('"$answer" means the learner does not know the word', () {
        expect(parseKnowsWordAnswer(answer), isFalse);
      });
    }
  });
}
