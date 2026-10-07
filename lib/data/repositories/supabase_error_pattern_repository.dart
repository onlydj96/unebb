import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unebb/domain/models/user_error_pattern.dart';
import 'package:unebb/domain/repositories/error_pattern_repository.dart';

class SupabaseErrorPatternRepository implements ErrorPatternRepository {
  const SupabaseErrorPatternRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'user_error_patterns';

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<UserErrorPattern>> getForWord({
    required String vocabularyId,
    int limit = 5,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .eq('vocabulary_id', vocabularyId)
        .order('count', ascending: false)
        .limit(limit);
    return rows.map((r) => UserErrorPattern.fromJson(r)).toList();
  }

  @override
  Future<List<UserErrorPattern>> getGlobal({int limit = 5}) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .isFilter('vocabulary_id', null)
        .order('count', ascending: false)
        .limit(limit);
    return rows.map((r) => UserErrorPattern.fromJson(r)).toList();
  }

  @override
  Future<void> upsertPatterns({
    String? vocabularyId,
    required List<String> patternTexts,
  }) async {
    if (patternTexts.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    for (final text in patternTexts) {
      // Check if this pattern already exists
      final query = _client
          .from(_table)
          .select('id, count')
          .eq('user_id', _userId)
          .eq('pattern_text', text);

      final existing = vocabularyId != null
          ? await query.eq('vocabulary_id', vocabularyId).limit(1)
          : await query.isFilter('vocabulary_id', null).limit(1);

      if (existing.isEmpty) {
        await _client.from(_table).insert({
          'user_id': _userId,
          if (vocabularyId != null) 'vocabulary_id': vocabularyId,
          'pattern_text': text,
          'count': 1,
          'last_seen_at': now,
        });
      } else {
        final id = existing.first['id'] as String;
        final count = (existing.first['count'] as int) + 1;
        await _client
            .from(_table)
            .update({'count': count, 'last_seen_at': now}).eq('id', id);
      }
    }
  }
}
