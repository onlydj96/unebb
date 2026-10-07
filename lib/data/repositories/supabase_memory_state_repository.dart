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
        .lte('next_review_at', now);

    // Convert to MemoryState objects
    final states = rows.map((r) => MemoryState.fromJson(r)).toList();

    // Sort by priority with weighted randomization
    return _priorityShuffleWithWeights(states);
  }

  @override
  Future<List<MemoryState>> getAllForReview() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId);

    // Convert to MemoryState objects
    final states = rows.map((r) => MemoryState.fromJson(r)).toList();

    // Sort by priority with weighted randomization
    return _priorityShuffleWithWeights(states);
  }

  // Calculate priority score (lower = higher priority)
  double _calculatePriorityScore(MemoryState state) {
    // Base score from memory strength (0.0-1.0, inverted so lower strength = lower score)
    double score = 1.0 - state.memoryStrength;

    // Heavy penalty for words with many incorrect answers
    if (state.incorrectCount > 0) {
      final incorrectRatio = state.incorrectCount / (state.reviewCount + 1);
      score -= incorrectRatio * 0.5; // Up to -0.5 for 100% incorrect
    }

    // Slight boost for new words (never reviewed)
    if (state.reviewCount == 0) {
      score -= 0.2;
    }

    // Small penalty for overdue words
    final now = DateTime.now().toUtc();
    final overdueDays = now.difference(state.nextReviewAt).inDays;
    if (overdueDays > 0) {
      score -= overdueDays * 0.01; // -0.01 per day overdue
    }

    return score;
  }

  // Priority-based weighted shuffle for diverse review order
  List<MemoryState> _priorityShuffleWithWeights(List<MemoryState> states) {
    if (states.isEmpty) return states;

    // Calculate priority scores for all states
    final scored = states.map((state) {
      final priority = _calculatePriorityScore(state);
      return MapEntry(state, priority);
    }).toList();

    // Sort by priority first to establish base order
    scored.sort((a, b) => a.value.compareTo(b.value));

    // Group by priority tiers for weighted randomization
    final result = <MemoryState>[];

    // Split into priority groups
    final highPriority = <MapEntry<MemoryState, double>>[];
    final mediumPriority = <MapEntry<MemoryState, double>>[];
    final lowPriority = <MapEntry<MemoryState, double>>[];

    for (final entry in scored) {
      if (entry.value < 0.3) {
        highPriority.add(entry); // Urgent: struggled words, weak memory
      } else if (entry.value < 0.6) {
        mediumPriority.add(entry); // Moderate: needs review
      } else {
        lowPriority.add(entry); // Low: relatively strong
      }
    }

    // Shuffle within each group and interleave with weights
    highPriority.shuffle();
    mediumPriority.shuffle();
    lowPriority.shuffle();

    // Interleave: 60% high, 30% medium, 10% low priority
    int hIdx = 0, mIdx = 0, lIdx = 0;
    int counter = 0;

    while (hIdx < highPriority.length ||
           mIdx < mediumPriority.length ||
           lIdx < lowPriority.length) {
      final cycle = counter % 10;

      // 60% high priority (cycles 0-5)
      if (cycle < 6 && hIdx < highPriority.length) {
        result.add(highPriority[hIdx++].key);
      }
      // 30% medium priority (cycles 6-8)
      else if (cycle < 9 && mIdx < mediumPriority.length) {
        result.add(mediumPriority[mIdx++].key);
      }
      // 10% low priority (cycle 9)
      else if (lIdx < lowPriority.length) {
        result.add(lowPriority[lIdx++].key);
      }
      // Fill remaining from any available group
      else if (hIdx < highPriority.length) {
        result.add(highPriority[hIdx++].key);
      } else if (mIdx < mediumPriority.length) {
        result.add(mediumPriority[mIdx++].key);
      } else if (lIdx < lowPriority.length) {
        result.add(lowPriority[lIdx++].key);
      }

      counter++;
    }

    return result;
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
