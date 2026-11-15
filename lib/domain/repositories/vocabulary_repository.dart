import 'package:unebb/domain/models/vocabulary_item.dart';

abstract interface class VocabularyRepository {
  Future<List<VocabularyItem>> getAll();

  /// Words inserted or updated at or after [since] (server `updated_at`).
  /// Used by delta sync instead of downloading every word again.
  Future<List<VocabularyItem>> getUpdatedSince(DateTime since);

  /// Number of the user's words, counted on the server (no rows returned).
  Future<int> count();

  /// IDs of all the user's words (detects words deleted elsewhere).
  Future<Set<String>> getAllIds();

  Future<List<VocabularyItem>> getByDeckId(String deckId);
  Future<VocabularyItem?> getById(String id);

  /// Check if a word already exists in the specified deck (or globally if deckId is null).
  /// Returns the existing item if found, null otherwise.
  Future<VocabularyItem?> findDuplicate({
    required String word,
    required String language,
    String? deckId,
  });

  Future<VocabularyItem> create({
    required String word,
    required String language,
    String? deckId,
  });
  Future<VocabularyItem> update(VocabularyItem item);
  Future<void> delete(String id);
  Future<VocabularyItem> updateAiContent({
    required String id,
    required String definition,
    required String explanation,
    required String usage,
    required List<String> examples,
    required List<String> synonyms,
    required List<String> collocations,
    required List<String> commonMistakes,
  });
}
