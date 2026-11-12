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
    @Default(0.0) double meaningScore,
    @Default(0.0) double usageScore,
    @Default(0.0) double exampleScore,
    @Default(0.0) double grammarScore,
    @Default(0.0) double overallScore,
    @Default('') String feedback,
    String? weakPoint,
    @Default([]) List<String> detectedPatterns,
  }) = _AiEvaluation;

  /// Creates an empty evaluation with default values.
  /// Used when AI evaluation data is missing or invalid.
  static const empty = AiEvaluation();

  factory AiEvaluation.fromJson(Map<String, dynamic> json) =>
      _$AiEvaluationFromJson(json);
}
