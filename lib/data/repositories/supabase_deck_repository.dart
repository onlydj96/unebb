import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/repositories/deck_repository.dart';

class SupabaseDeckRepository implements DeckRepository {
  const SupabaseDeckRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Deck>> getAll() async {
    // Get all decks
    final rows = await _client
        .from('decks')
        .select()
        .eq('user_id', _userId);

    final decks = rows.map((row) => Deck.fromJson(row)).toList();

    if (decks.isEmpty) return decks;

    // Get most recent review for each deck via vocabulary_items
    // review_results -> vocabulary_items -> deck_id
    final reviewResults = await _client
        .from('review_results')
        .select('vocabulary_id, reviewed_at')
        .eq('user_id', _userId)
        .order('reviewed_at', ascending: false);

    if (reviewResults.isEmpty) {
      // No reviews yet, just sort by created_at
      decks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return decks;
    }

    // Get vocabulary_id to deck_id mapping
    final vocabularyIds = reviewResults
        .map((r) => r['vocabulary_id'] as String)
        .toSet()
        .toList();

    final vocabularyItems = await _client
        .from('vocabulary_items')
        .select('id, deck_id')
        .inFilter('id', vocabularyIds);

    final vocabToDeckMap = <String, String>{};
    for (final item in vocabularyItems) {
      final vocabId = item['id'] as String;
      final deckId = item['deck_id'] as String?;
      if (deckId != null) {
        vocabToDeckMap[vocabId] = deckId;
      }
    }

    // Map deck_id to most recent review time
    final deckLastReviewMap = <String, DateTime>{};
    for (final result in reviewResults) {
      final vocabId = result['vocabulary_id'] as String;
      final deckId = vocabToDeckMap[vocabId];
      if (deckId != null && !deckLastReviewMap.containsKey(deckId)) {
        deckLastReviewMap[deckId] = DateTime.parse(result['reviewed_at'] as String);
      }
    }

    // Sort: decks with reviews (by most recent review) → decks without reviews (by created_at)
    decks.sort((a, b) {
      final aLastReview = deckLastReviewMap[a.id];
      final bLastReview = deckLastReviewMap[b.id];

      // Both have reviews: sort by most recent review
      if (aLastReview != null && bLastReview != null) {
        return bLastReview.compareTo(aLastReview);
      }

      // Only a has review: a comes first
      if (aLastReview != null) return -1;

      // Only b has review: b comes first
      if (bLastReview != null) return 1;

      // Neither has review: sort by created_at (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return decks;
  }

  @override
  Future<Deck?> getById(String id) async {
    final rows = await _client
        .from('decks')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .limit(1);

    if (rows.isEmpty) return null;
    return Deck.fromJson(rows.first);
  }

  @override
  Future<Deck> create({
    required String name,
    required String language,
    String? description,
  }) async {
    final row = await _client
        .from('decks')
        .insert({
          'user_id': _userId,
          'name': name,
          'language': language,
          if (description != null) 'description': description,
        })
        .select()
        .single();

    return Deck.fromJson(row);
  }

  @override
  Future<Deck> update(Deck deck) async {
    final row = await _client
        .from('decks')
        .update({
          'name': deck.name,
          'description': deck.description,
          'language': deck.language,
        })
        .eq('id', deck.id)
        .eq('user_id', _userId)
        .select()
        .single();

    return Deck.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('decks').delete().eq('id', id).eq('user_id', _userId);
  }
}
