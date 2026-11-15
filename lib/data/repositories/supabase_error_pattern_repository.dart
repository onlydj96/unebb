import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/data/repositories/base_supabase_repository.dart';
import 'package:unebb/domain/models/user_error_pattern.dart';
import 'package:unebb/domain/repositories/error_pattern_repository.dart';

class SupabaseErrorPatternRepository
    with SupabaseRepositoryMixin
    implements ErrorPatternRepository {
  SupabaseErrorPatternRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  String get tableName => 'user_error_patterns';

  @override
  Future<List<UserErrorPattern>> getForWord({
    required String vocabularyId,
    int limit = 5,
  }) async {
    final rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('vocabulary_id', vocabularyId)
        .order('count', ascending: false)
        .limit(limit);
    return rows.map((r) => UserErrorPattern.fromJson(r)).toList();
  }

  @override
  Future<List<UserErrorPattern>> getGlobal({int limit = 5}) async {
    final rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .isFilter('vocabulary_id', null)
        .order('count', ascending: false)
        .limit(limit);
    return rows.map((r) => UserErrorPattern.fromJson(r)).toList();
  }

  @override
  Future<Map<String, List<UserErrorPattern>>> getForMultipleWords({
    required List<String> vocabularyIds,
    int limit = 5,
  }) async {
    if (vocabularyIds.isEmpty) return {};

    // Fetch all patterns for the given vocabulary IDs in one query
    final rows = await _client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .inFilter('vocabulary_id', vocabularyIds)
        .order('count', ascending: false);

    // Group by vocabularyId and apply limit per word
    final result = <String, List<UserErrorPattern>>{};
    for (final row in rows) {
      final pattern = UserErrorPattern.fromJson(row);
      final vocabId = pattern.vocabularyId;
      if (vocabId == null) continue;

      result.putIfAbsent(vocabId, () => []);
      if (result[vocabId]!.length < limit) {
        result[vocabId]!.add(pattern);
      }
    }

    return result;
  }

  /// One round trip: the `record_error_patterns` function upserts the
  /// word-specific and the global row of every pattern atomically
  /// (`INSERT … ON CONFLICT DO UPDATE SET count = count + 1`), so concurrent
  /// answers cannot lose increments or create duplicate rows.
  @override
  Future<void> recordPatterns({
    required String vocabularyId,
    required List<String> patternTexts,
  }) async {
    if (patternTexts.isEmpty) return;
    await _client.rpc('record_error_patterns', params: {
      'p_vocabulary_id': vocabularyId,
      'p_patterns': patternTexts,
    });
  }
}
