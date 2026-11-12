import 'package:unebb/domain/models/memory_state.dart';

abstract interface class MemoryStateRepository {
  /// All memory states of the current user (one row per vocabulary item).
  ///
  /// Review selection/ordering is done by `ReviewQueueBuilder` on top of this
  /// single query, so the review screen needs one round trip instead of two.
  Future<List<MemoryState>> getAll();

  Future<MemoryState?> getByVocabularyId(String vocabularyId);

  Future<MemoryState> create({required String vocabularyId});

  /// Create memory_states for multiple vocabulary IDs in a single batch.
  Future<List<MemoryState>> createBatch({required List<String> vocabularyIds});

  Future<MemoryState> update(MemoryState state);
}
