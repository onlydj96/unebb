import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/data/repositories/base_supabase_repository.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/repositories/memory_state_repository.dart';

class SupabaseMemoryStateRepository
    with SupabaseRepositoryMixin
    implements MemoryStateRepository {
  SupabaseMemoryStateRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  String get tableName => 'memory_states';

  @override
  Future<List<MemoryState>> getAll() async {
    final rows = await _client.from(tableName).select().eq('user_id', userId);
    return rows.map((r) => MemoryState.fromJson(r)).toList();
  }

  @override
  Future<MemoryState?> getByVocabularyId(String vocabularyId) async {
    final rows = await _client
        .from(tableName)
        .select()
        .eq('vocabulary_id', vocabularyId)
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return MemoryState.fromJson(rows.first);
  }

  Map<String, dynamic> _newRow(String vocabularyId, String now) => {
        'user_id': userId,
        'vocabulary_id': vocabularyId,
        'memory_strength': 0.0,
        'recall_probability': 0.0,
        'stage': 4,
        // New words are due immediately.
        'next_review_at': now,
      };

  @override
  Future<MemoryState> create({required String vocabularyId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from(tableName)
        .insert(_newRow(vocabularyId, now))
        .select()
        .single();
    return MemoryState.fromJson(row);
  }

  @override
  Future<List<MemoryState>> createBatch({
    required List<String> vocabularyIds,
  }) async {
    if (vocabularyIds.isEmpty) return [];
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from(tableName)
        .insert([for (final id in vocabularyIds) _newRow(id, now)]).select();
    return rows.map((r) => MemoryState.fromJson(r)).toList();
  }

  @override
  Future<MemoryState> update(MemoryState state) async {
    final row = await _client
        .from(tableName)
        .update({
          'memory_strength': state.memoryStrength,
          'recall_probability': state.recallProbability,
          'stage': state.stage,
          'last_reviewed_at': state.lastReviewedAt?.toIso8601String(),
          'next_review_at': state.nextReviewAt.toIso8601String(),
          'review_count': state.reviewCount,
          'correct_count': state.correctCount,
          'incorrect_count': state.incorrectCount,
          'consecutive_correct': state.consecutiveCorrect,
          'ease_factor': state.easeFactor,
          'sm2_interval': state.sm2Interval,
          'sm2_repetitions': state.sm2Repetitions,
        })
        .eq('id', state.id)
        .eq('user_id', userId)
        .select()
        .single();
    return MemoryState.fromJson(row);
  }
}
