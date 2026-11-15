import 'package:unebb/domain/models/user_error_pattern.dart';

abstract interface class ErrorPatternRepository {
  /// Returns up to [limit] patterns for a specific word (most frequent first).
  Future<List<UserErrorPattern>> getForWord({
    required String vocabularyId,
    int limit = 5,
  });

  /// Returns up to [limit] global patterns (vocabularyId IS NULL), most frequent first.
  Future<List<UserErrorPattern>> getGlobal({int limit = 5});

  /// Returns patterns for multiple words in a single query.
  /// Returns a map where key = vocabularyId, value = list of patterns.
  Future<Map<String, List<UserErrorPattern>>> getForMultipleWords({
    required List<String> vocabularyIds,
    int limit = 5,
  });

  /// Records [patternTexts] seen in an answer about [vocabularyId], both as
  /// word-specific and as global patterns, in one atomic server call:
  /// existing patterns get their count incremented, new ones are inserted.
  Future<void> recordPatterns({
    required String vocabularyId,
    required List<String> patternTexts,
  });
}
