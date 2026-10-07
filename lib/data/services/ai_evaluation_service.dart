import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/domain/models/ai_evaluation.dart';

/// Calls the `evaluate-answer` Edge Function and returns a typed [AiEvaluation].
class AiEvaluationService {
  const AiEvaluationService(this._client);

  final SupabaseClient _client;

  static const _function = 'evaluate-answer';

  Future<AiEvaluation> evaluateAnswer({
    required String word,
    required String language,
    required String definition,
    required String usage,
    required String userAnswer,
    required String answerType,
    String evalType = 'meaning', // 'meaning' | 'translation'
    String? questionContext,     // Korean sentence for translation eval
    List<String> knownPatterns = const [],
    String? nativeLanguage,      // Learner's native language
  }) async {
    final response = await _client.functions.invoke(
      _function,
      body: {
        'word': word,
        'language': language,
        'definition': definition,
        'usage': usage,
        'user_answer': userAnswer,
        'answer_type': answerType,
        'eval_type': evalType,
        if (questionContext != null) 'question_context': questionContext,
        if (knownPatterns.isNotEmpty) 'known_patterns': knownPatterns,
        if (nativeLanguage != null) 'native_language': nativeLanguage,
      },
    );

    if (response.status != 200) {
      throw Exception(
        'evaluate-answer failed (${response.status}): ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return AiEvaluation.fromJson(data);
  }
}
