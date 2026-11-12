import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/data/repositories/base_supabase_repository.dart';
import 'package:unebb/domain/models/review_result.dart';
import 'package:unebb/domain/models/review_session.dart';
import 'package:unebb/domain/repositories/review_repository.dart';

class SupabaseReviewRepository
    with SupabaseRepositoryMixin
    implements ReviewRepository {
  SupabaseReviewRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  String get tableName => 'review_sessions';

  @override
  Future<ReviewSession> createSession({
    required List<String> vocabularyIds,
  }) async {
    // The caller already holds the vocabulary items; only the row is created.
    final sessionRow = await _client
        .from('review_sessions')
        .insert({
          'user_id': userId,
          'total_items': vocabularyIds.length,
          'completed_items': 0,
        })
        .select()
        .single();

    return ReviewSession.fromJson(sessionRow);
  }

  @override
  Future<ReviewSession?> getById(String id) async {
    final rows = await _client
        .from('review_sessions')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;

    final session = ReviewSession.fromJson(rows.first);

    // Load results for this session
    final resultRows = await _client
        .from('review_results')
        .select()
        .eq('session_id', id)
        .eq('user_id', userId);

    final results = resultRows.map((r) {
      final eval = r['ai_evaluation'] as Map<String, dynamic>? ?? {};
      return ReviewResult.fromJson({...r, 'ai_evaluation': eval});
    }).toList();

    return session.copyWith(results: results);
  }

  @override
  Future<ReviewSession> completeSession(String id,
      {int? completedItems}) async {
    final row = await _client
        .from('review_sessions')
        .update({
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          if (completedItems != null) 'completed_items': completedItems,
        })
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return ReviewSession.fromJson(row);
  }

  @override
  Future<ReviewResult> addResult({
    required String sessionId,
    required ReviewResult result,
  }) async {
    // Flatten AiEvaluation fields into the row
    final eval = result.aiEvaluation;
    final row = await _client
        .from('review_results')
        .insert({
          'user_id': userId,
          'session_id': sessionId,
          'vocabulary_id': result.vocabularyId,
          'answer_type': result.answerType,
          'user_answer': result.userAnswer,
          'meaning_score': eval.meaningScore,
          'usage_score': eval.usageScore,
          'example_score': eval.exampleScore,
          'grammar_score': eval.grammarScore,
          'overall_score': eval.overallScore,
          'feedback': eval.feedback,
          'weak_point': eval.weakPoint,
          'previous_memory_strength': result.previousMemoryStrength,
          'updated_memory_strength': result.updatedMemoryStrength,
          'reviewed_at': result.reviewedAt.toIso8601String(),
          'question_type': result.questionType,
          if (result.questionContext != null)
            'question_context': result.questionContext,
        })
        .select()
        .single();

    return ReviewResult.fromJson({
      ...row,
      'ai_evaluation': {
        'meaning_score': eval.meaningScore,
        'usage_score': eval.usageScore,
        'example_score': eval.exampleScore,
        'grammar_score': eval.grammarScore,
        'overall_score': eval.overallScore,
        'feedback': eval.feedback,
        'weak_point': eval.weakPoint,
      },
    });
  }
}
