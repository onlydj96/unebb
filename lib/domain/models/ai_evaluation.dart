import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_evaluation.freezed.dart';
part 'ai_evaluation.g.dart';

/// The structured output returned by the evaluate-answer Edge Function.
///
/// `stage` is intentionally absent — it is always derived by
/// `MemoryService.stageFromStrength()` and is NOT determined by the LLM.
@freezed
abstract class AiEvaluation with _$AiEvaluation {
  const factory AiEvaluation({
    required double meaningScore,
    required double usageScore,
    required double exampleScore,
    required double grammarScore,
    required double overallScore,
    required String feedback,
    String? weakPoint,
    @Default([]) List<String> detectedPatterns,
  }) = _AiEvaluation;

  factory AiEvaluation.fromJson(Map<String, dynamic> json) =>
      _$AiEvaluationFromJson(json);
}
