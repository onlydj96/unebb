import 'package:freezed_annotation/freezed_annotation.dart';

import 'review_result.dart';
import 'vocabulary_item.dart';

part 'review_session.freezed.dart';
part 'review_session.g.dart';

@freezed
abstract class ReviewSession with _$ReviewSession {
  const factory ReviewSession({
    required String id,
    required String userId,
    required DateTime startedAt,
    DateTime? completedAt,
    required int totalItems,
    required int completedItems,

    /// Full VocabularyItem objects loaded at session start (DECISION-8).
    @Default([]) List<VocabularyItem> vocabularyItems,
    @Default([]) List<ReviewResult> results,
  }) = _ReviewSession;

  factory ReviewSession.fromJson(Map<String, dynamic> json) =>
      _$ReviewSessionFromJson(json);
}
