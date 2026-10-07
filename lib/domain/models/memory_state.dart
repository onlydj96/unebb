import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_state.freezed.dart';
part 'memory_state.g.dart';

/// Current memory state for one vocabulary item.
/// This is a mutable snapshot updated after every review.
@freezed
abstract class MemoryState with _$MemoryState {
  const factory MemoryState({
    required String id,
    required String userId,
    required String vocabularyId,
    required int stage,
    required double memoryStrength,

    /// MVP: mirrors memoryStrength. Reserved for future time-decay calculation.
    required double recallProbability,
    DateTime? lastReviewedAt,
    required DateTime nextReviewAt,
    required int reviewCount,
    required int correctCount,
    required int incorrectCount,
    required int consecutiveCorrect,

    /// SM-2: ease factor, starts at 2.5, min 1.3
    @Default(2.5) double easeFactor,

    /// SM-2: current interval in days
    @Default(1) int sm2Interval,

    /// SM-2: number of consecutive successful reviews
    @Default(0) int sm2Repetitions,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _MemoryState;

  factory MemoryState.fromJson(Map<String, dynamic> json) =>
      _$MemoryStateFromJson(json);
}
