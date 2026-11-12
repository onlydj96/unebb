import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unebb/data/repositories/base_supabase_repository.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/repositories/vocabulary_repository.dart';

class SupabaseVocabularyRepository
    with SupabaseRepositoryMixin
    implements VocabularyRepository {
  SupabaseVocabularyRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  String get tableName => 'vocabulary_items';

  @override
  Future<List<VocabularyItem>> getAll() async {
    final rows = await client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => VocabularyItem.fromJson(r)).toList();
  }

  @override
  Future<List<VocabularyItem>> getByDeckId(String deckId) async {
    final rows = await client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('deck_id', deckId)
        .order('created_at', ascending: false);
    return rows.map((r) => VocabularyItem.fromJson(r)).toList();
  }

  @override
  Future<VocabularyItem?> getById(String id) async {
    final rows = await client
        .from(tableName)
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return VocabularyItem.fromJson(rows.first);
  }

  @override
  Future<VocabularyItem?> findDuplicate({
    required String word,
    required String language,
    String? deckId,
  }) async {
    // Normalize the word for comparison (trim and case-insensitive)
    final normalizedWord = word.trim().toLowerCase();

    var query = client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .eq('language', language);

    // If deckId is provided, only check within that deck
    // If deckId is null, check across all user's vocabulary
    if (deckId != null) {
      query = query.eq('deck_id', deckId);
    }

    final rows = await query;

    // Find match with case-insensitive comparison
    for (final row in rows) {
      final existingWord = (row['word'] as String?)?.trim().toLowerCase();
      if (existingWord == normalizedWord) {
        return VocabularyItem.fromJson(row);
      }
    }

    return null;
  }

  @override
  Future<VocabularyItem> create({
    required String word,
    required String language,
    String? deckId,
  }) async {
    final row = await client
        .from(tableName)
        .insert({
          'user_id': userId,
          'word': word,
          'language': language,
          if (deckId != null) 'deck_id': deckId,
        })
        .select()
        .single();
    return VocabularyItem.fromJson(row);
  }

  @override
  Future<VocabularyItem> update(VocabularyItem item) async {
    final row = await client
        .from(tableName)
        .update(item.toJson()
          ..remove('id')
          ..remove('user_id'))
        .eq('id', item.id)
        .eq('user_id', userId)
        .select()
        .single();
    return VocabularyItem.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await client.from(tableName).delete().eq('id', id).eq('user_id', userId);
  }

  @override
  Future<VocabularyItem> updateAiContent({
    required String id,
    required String definition,
    required String explanation,
    required String usage,
    required List<String> examples,
    required List<String> synonyms,
    required List<String> collocations,
    required List<String> commonMistakes,
  }) async {
    final row = await client
        .from(tableName)
        .update({
          'definition': definition,
          'explanation': explanation,
          'usage': usage,
          'examples': examples,
          'synonyms': synonyms,
          'collocations': collocations,
          'common_mistakes': commonMistakes,
        })
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return VocabularyItem.fromJson(row);
  }
}
