import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_error_pattern.freezed.dart';
part 'user_error_pattern.g.dart';

/// Tracks a recurring grammar/usage error pattern for a learner.
///
/// [vocabularyId] null = global pattern (applies across all words).
/// Non-null = word-specific pattern (e.g., "be used to: infinitive mistake").
@freezed
abstract class UserErrorPattern with _$UserErrorPattern {
  const factory UserErrorPattern({
    required String id,
    required String userId,
    String? vocabularyId,
    required String patternText,
    required int count,
    required DateTime lastSeenAt,
    required DateTime createdAt,
  }) = _UserErrorPattern;

  factory UserErrorPattern.fromJson(Map<String, dynamic> json) =>
      _$UserErrorPatternFromJson(json);
}
