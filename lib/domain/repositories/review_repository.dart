import 'package:unebb/domain/models/review_result.dart';
import 'package:unebb/domain/models/review_session.dart';

abstract interface class ReviewRepository {
  Future<ReviewSession> createSession({
    required List<String> vocabularyIds,
  });
  Future<ReviewSession?> getById(String id);
  Future<ReviewSession> completeSession(String id);
  Future<ReviewResult> addResult({
    required String sessionId,
    required ReviewResult result,
  });
}
