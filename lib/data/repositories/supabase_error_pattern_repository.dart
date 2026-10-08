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
  Future<Map<String, List<UserErrorPattern>>> getForMultipleWords({
    required List<String> vocabularyIds,
    int limit = 5,
  }) async {
    if (vocabularyIds.isEmpty) return {};

    // Fetch all patterns for the given vocabulary IDs in one query
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
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

  @override
  Future<void> upsertPatterns({
    String? vocabularyId,
    required List<String> patternTexts,
  }) async {
    if (patternTexts.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    // Batch fetch: get all existing patterns in one query
    final baseQuery = _client
        .from(_table)
        .select('id, pattern_text, count')
        .eq('user_id', _userId)
        .inFilter('pattern_text', patternTexts);

    final existingRows = vocabularyId != null
        ? await baseQuery.eq('vocabulary_id', vocabularyId)
        : await baseQuery.isFilter('vocabulary_id', null);

    // Build lookup map: pattern_text -> {id, count}
    final existingMap = <String, Map<String, dynamic>>{};
    for (final row in existingRows) {
      existingMap[row['pattern_text'] as String] = row;
    }

    // Separate into inserts and updates
    final toInsert = <Map<String, dynamic>>[];
    final toUpdate = <Map<String, dynamic>>[];

    for (final text in patternTexts) {
      final existing = existingMap[text];
      if (existing == null) {
        toInsert.add({
          'user_id': _userId,
          if (vocabularyId != null) 'vocabulary_id': vocabularyId,
          'pattern_text': text,
          'count': 1,
          'last_seen_at': now,
        });
      } else {
        toUpdate.add({
          'id': existing['id'],
          'count': (existing['count'] as int) + 1,
          'last_seen_at': now,
        });
      }
    }

    // Execute batch operations in parallel
    await Future.wait([
      if (toInsert.isNotEmpty) _client.from(_table).insert(toInsert),
      // Updates must be done individually (Supabase limitation), but in parallel
      ...toUpdate.map((u) => _client
          .from(_table)
          .update({'count': u['count'], 'last_seen_at': u['last_seen_at']})
          .eq('id', u['id'])),
    ]);
  }
}
