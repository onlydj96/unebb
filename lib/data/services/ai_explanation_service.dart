import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/domain/models/vocabulary_item.dart';

/// Calls the `generate-explanation` Edge Function to populate
/// AI fields for a vocabulary item.
///
/// The Edge Function writes directly to the database and returns the
/// updated row; this service surfaces the result as a [VocabularyItem].
class AiExplanationService {
  const AiExplanationService(this._client);

  final SupabaseClient _client;

  static const _function = 'generate-explanation';

  Future<VocabularyItem> generateExplanation({
    required String vocabularyId,
    required String word,
    required String language,
    required String nativeLanguage,
  }) async {
    final response = await _client.functions.invoke(
      _function,
      body: {
        'vocabulary_id': vocabularyId,
        'word': word,
        'language': language,
        'native_language': nativeLanguage,
      },
    );

    if (response.status != 200) {
      throw Exception(
        'generate-explanation failed (${response.status}): ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return VocabularyItem.fromJson(data);
  }
}
