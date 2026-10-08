import 'package:unebb/domain/models/memory_state.dart';

abstract interface class MemoryStateRepository {
  Future<List<MemoryState>> getAll();
  Future<MemoryState?> getByVocabularyId(String vocabularyId);
  Future<List<MemoryState>> getDueForReview();
  Future<List<MemoryState>> getAllForReview(); // All words, prioritized

  /// Get all vocabulary IDs that have memory_states for this user.
  Future<Set<String>> getExistingVocabularyIds();

  Future<MemoryState> create({required String vocabularyId});

  /// Create memory_states for multiple vocabulary IDs in a single batch.
  Future<List<MemoryState>> createBatch({required List<String> vocabularyIds});

  Future<MemoryState> update(MemoryState state);
}
