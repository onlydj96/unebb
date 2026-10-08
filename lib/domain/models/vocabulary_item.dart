import 'package:freezed_annotation/freezed_annotation.dart';

part 'vocabulary_item.freezed.dart';
part 'vocabulary_item.g.dart';

@freezed
abstract class VocabularyItem with _$VocabularyItem {
  const factory VocabularyItem({
    required String id,
    required String userId,
    String? deckId,
    required String word,
    required String language,
    // AI-generated fields — null until generate-explanation runs
    String? pronunciation,
    String? definition,
    String? explanation,
    String? usage,
    List<String>? examples,
    List<String>? synonyms,
    List<String>? collocations,
    List<String>? commonMistakes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _VocabularyItem;

  factory VocabularyItem.fromJson(Map<String, dynamic> json) =>
      _$VocabularyItemFromJson(json);
}
