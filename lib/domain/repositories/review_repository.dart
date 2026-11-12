import 'package:unebb/domain/models/review_result.dart';
import 'package:unebb/domain/models/review_session.dart';

abstract interface class ReviewRepository {
  /// Creates the session row. Callers attach the already-loaded vocabulary
  /// items themselves, so this does not re-fetch them.
  Future<ReviewSession> createSession({
    required List<String> vocabularyIds,
  });
  Future<ReviewSession?> getById(String id);

  /// Marks the session finished and records how many words were reviewed.
  Future<ReviewSession> completeSession(String id, {int? completedItems});
  Future<ReviewResult> addResult({
    required String sessionId,
    required ReviewResult result,
  });
}
