import 'package:freezed_annotation/freezed_annotation.dart';

part 'deck.freezed.dart';
part 'deck.g.dart';

/// A deck is a themed collection of vocabulary items.
/// Users can create multiple decks for different purposes
/// (e.g., TOEIC words, Japanese vocabulary, Spanish basics).
@freezed
abstract class Deck with _$Deck {
  const factory Deck({
    required String id,
    required String userId,
    required String name,
    String? description,
    required String language,
    @Default(0) int wordCount,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Deck;

  factory Deck.fromJson(Map<String, dynamic> json) => _$DeckFromJson(json);
}
