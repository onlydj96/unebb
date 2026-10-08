import 'dart:math' show Random;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unebb/core/utils/logger.dart';
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

    AppLogger.debug('getDueForReview called', data: {'timestamp': now});

    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .lte('next_review_at', now);

    AppLogger.debug('Memory states fetched', data: {
      'count': rows.length,
      'first_5_vocab_ids': rows.take(5).map((r) => (r['vocabulary_id'] as String).substring(0, 8)).toList(),
    });

    // Convert to MemoryState objects
    final states = rows.map((r) => MemoryState.fromJson(r)).toList();

    // Sort by priority with weighted randomization
    return _priorityShuffleWithWeights(states);
  }

  @override
  Future<List<MemoryState>> getAllForReview() async {
    AppLogger.debug('getAllForReview called');

    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId);

    AppLogger.debug('Memory states fetched (all)', data: {
      'count': rows.length,
      'first_5_vocab_ids': rows.take(5).map((r) => (r['vocabulary_id'] as String).substring(0, 8)).toList(),
    });

    // Convert to MemoryState objects
    final states = rows.map((r) => MemoryState.fromJson(r)).toList();

    // Sort by priority with weighted randomization
    return _priorityShuffleWithWeights(states);
  }

  // Calculate priority score (lower = higher priority)
  double _calculatePriorityScore(MemoryState state) {
    // NEW WORDS: Highest priority (score 0.0-0.3)
    if (state.reviewCount == 0) {
      // New words get high priority with slight randomization
      // Small overdue penalty to prioritize older new words
      final now = DateTime.now().toUtc();
      final overdueDays = now.difference(state.nextReviewAt).inDays;
      final overdueBoost = overdueDays > 0 ? overdueDays * 0.001 : 0.0; // Very small boost
      return 0.15 - overdueBoost; // Score around 0.15 (high priority)
    }

    // REVIEWED WORDS: Base score from memory strength (0.0-1.0)
    double score = 1.0 - state.memoryStrength;

    // Heavy penalty for words with incorrect answers (makes them high priority)
    if (state.incorrectCount > 0) {
      final incorrectRatio = state.incorrectCount / (state.reviewCount + 1);
      score -= incorrectRatio * 0.5; // Up to -0.5 for 100% incorrect
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

    AppLogger.debug('Priority shuffle - Before grouping', data: {
      'total': scored.length,
      'first_5_scores': scored.take(5).map((e) => '${e.key.vocabularyId.substring(0, 8)}: ${e.value.toStringAsFixed(2)}').toList(),
    });

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

    AppLogger.debug('Priority groups', data: {
      'high': highPriority.length,
      'medium': mediumPriority.length,
      'low': lowPriority.length,
    });

    // Shuffle within each group and interleave with weights
    // Use microsecondsSinceEpoch to ensure different seed each time
    final seedValue = DateTime.now().microsecondsSinceEpoch;
    AppLogger.debug('Shuffle seed', data: {'seed': seedValue});

    final random = Random(seedValue);

    // Log before shuffle
    if (mediumPriority.isNotEmpty) {
      AppLogger.debug('Medium priority BEFORE shuffle', data: {
        'first_5': mediumPriority.take(5).map((e) => e.key.vocabularyId.substring(0, 8)).toList(),
      });
    }

    highPriority.shuffle(random);
    mediumPriority.shuffle(random);
    lowPriority.shuffle(random);

    // Log after shuffle
    if (mediumPriority.isNotEmpty) {
      AppLogger.debug('Medium priority AFTER shuffle', data: {
        'first_5': mediumPriority.take(5).map((e) => e.key.vocabularyId.substring(0, 8)).toList(),
      });
    }

    // Weighted random interleaving for better diversity
    // Build a weighted pool where each group has probability based on its size
    final allItems = <MapEntry<MemoryState, String>>[];

    // Add all items with their priority tier as metadata
    for (final entry in highPriority) {
      allItems.add(MapEntry(entry.key, 'high'));
    }
    for (final entry in mediumPriority) {
      allItems.add(MapEntry(entry.key, 'medium'));
    }
    for (final entry in lowPriority) {
      allItems.add(MapEntry(entry.key, 'low'));
    }

    // Shuffle the entire pool for true randomization
    allItems.shuffle(random);

    // Now interleave based on weighted probabilities
    int hIdx = 0, mIdx = 0, lIdx = 0;

    while (hIdx < highPriority.length ||
           mIdx < mediumPriority.length ||
           lIdx < lowPriority.length) {
      // Use random selection with weighted probability
      final dice = random.nextInt(100);

      // 60% chance for high priority (if available)
      if (dice < 60 && hIdx < highPriority.length) {
        result.add(highPriority[hIdx++].key);
      }
      // 30% chance for medium priority (if available)
      else if (dice < 90 && mIdx < mediumPriority.length) {
        result.add(mediumPriority[mIdx++].key);
      }
      // 10% chance for low priority (if available)
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
    }

    AppLogger.debug('Final shuffled result', data: {
      'total': result.length,
      'first_10_vocab_ids': result.take(10).map((e) => e.vocabularyId.substring(0, 8)).toList(),
    });

    return result;
  }

  @override
  Future<Set<String>> getExistingVocabularyIds() async {
    final rows = await _client
        .from(_table)
        .select('vocabulary_id')
        .eq('user_id', _userId);
    return rows.map((r) => r['vocabulary_id'] as String).toSet();
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
  Future<List<MemoryState>> createBatch({required List<String> vocabularyIds}) async {
    if (vocabularyIds.isEmpty) return [];

    final now = DateTime.now().toUtc().toIso8601String();
    final insertData = vocabularyIds.map((vocabId) => {
      'user_id': _userId,
      'vocabulary_id': vocabId,
      'memory_strength': 0.0,
      'recall_probability': 0.0,
      'stage': 4,
      'next_review_at': now,
    }).toList();

    final rows = await _client
        .from(_table)
        .insert(insertData)
        .select();
    return rows.map((r) => MemoryState.fromJson(r)).toList();
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
