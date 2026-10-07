import 'package:unebb/domain/models/memory_state.dart';

abstract interface class MemoryStateRepository {
  Future<List<MemoryState>> getAll();
  Future<MemoryState?> getByVocabularyId(String vocabularyId);
  Future<List<MemoryState>> getDueForReview();
  Future<List<MemoryState>> getAllForReview(); // All words, prioritized
  Future<MemoryState> create({required String vocabularyId});
  Future<MemoryState> update(MemoryState state);
}
