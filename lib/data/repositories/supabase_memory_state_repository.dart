import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/repositories/memory_state_repository.dart';

class SupabaseMemoryStateRepository implements MemoryStateRepository {
  const SupabaseMemoryStateRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'memory_states';

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<MemoryState>> getAll() async {
    final rows = await _client.from(_table).select().eq('user_id', _userId);
    return rows.map((r) => MemoryState.fromJson(r)).toList();
  }

  @override
  Future<MemoryState?> getByVocabularyId(String vocabularyId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('vocabulary_id', vocabularyId)
        .eq('user_id', _userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return MemoryState.fromJson(rows.first);
  }

  @override
  Future<List<MemoryState>> getDueForReview() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .lte('next_review_at', now)
        .order('next_review_at');
    return rows.map((r) => MemoryState.fromJson(r)).toList();
  }

  @override
  Future<MemoryState> create({required String vocabularyId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from(_table)
        .insert({
          'user_id': _userId,
          'vocabulary_id': vocabularyId,
          'memory_strength': 0.0,
          'recall_probability': 0.0,
          'stage': 4,
          // New words are due immediately (Stage 4 → 10 min, but start now)
          'next_review_at': now,
        })
        .select()
        .single();
    return MemoryState.fromJson(row);
  }

  @override
  Future<MemoryState> update(MemoryState state) async {
    final row = await _client
        .from(_table)
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
        .eq('user_id', _userId)
        .select()
        .single();
    return MemoryState.fromJson(row);
  }
}
