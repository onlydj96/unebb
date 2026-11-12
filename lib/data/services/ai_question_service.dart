import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a `generate-question` Edge Function call.
class QuestionContent {
  const QuestionContent({
    required this.questionType,
    required this.sentence,
    required this.wordHint,
  });

  final String questionType; // 'translation'
  final String sentence; // native-language sentence to translate
  final String wordHint; // target word hint

  factory QuestionContent.fromJson(Map<String, dynamic> json) {
    return QuestionContent(
      questionType: json['question_type'] as String? ?? 'translation',
      sentence: json['sentence'] as String? ?? '',
      wordHint: json['word_hint'] as String? ?? '',
    );
  }
}

/// Calls the `generate-question` Edge Function.
class AiQuestionService {
  const AiQuestionService(this._client);

  final SupabaseClient _client;

  static const _function = 'generate-question';
  static const _timeout = Duration(seconds: 30);

  Future<QuestionContent> generateTranslationQuestion({
    required String word,
    required String language,
    required String definition,
    required String usage,
    required List<String> examples,
    required String nativeLanguage,
  }) async {
    final response = await _client.functions.invoke(
      _function,
      body: {
        'word': word,
        'language': language,
        'definition': definition,
        'usage': usage,
        'examples': examples,
        'native_language': nativeLanguage,
        'question_type': 'translation',
      },
    ).timeout(
      _timeout,
      onTimeout: () => throw TimeoutException(
        'AI question generation timed out after ${_timeout.inSeconds}s',
        _timeout,
      ),
    );

    if (response.status != 200) {
      throw Exception(
        'generate-question failed (${response.status}): ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return QuestionContent.fromJson(data);
  }
}
