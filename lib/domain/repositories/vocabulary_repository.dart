import 'package:unebb/domain/models/vocabulary_item.dart';

abstract interface class VocabularyRepository {
  Future<List<VocabularyItem>> getAll();
  Future<VocabularyItem?> getById(String id);
  Future<VocabularyItem> create({
    required String word,
    required String language,
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
