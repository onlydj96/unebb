import 'package:freezed_annotation/freezed_annotation.dart';

import 'ai_evaluation.dart';

part 'review_result.freezed.dart';
part 'review_result.g.dart';

@freezed
abstract class ReviewResult with _$ReviewResult {
  const factory ReviewResult({
    required String id,
    required String userId,
    required String sessionId,
    required String vocabularyId,
    required String userAnswer,
    required String answerType,
    required AiEvaluation aiEvaluation,
    required double previousMemoryStrength,
    required double updatedMemoryStrength,
    required DateTime reviewedAt,
    @Default('free_recall') String questionType,
    String? questionContext,
  }) = _ReviewResult;

  factory ReviewResult.fromJson(Map<String, dynamic> json) =>
      _$ReviewResultFromJson(json);
}
