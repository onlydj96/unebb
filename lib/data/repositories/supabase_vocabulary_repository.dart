import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/repositories/vocabulary_repository.dart';

class SupabaseVocabularyRepository implements VocabularyRepository {
  const SupabaseVocabularyRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'vocabulary_items';

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<VocabularyItem>> getAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return rows.map((r) => VocabularyItem.fromJson(r)).toList();
  }

  @override
  Future<VocabularyItem?> getById(String id) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return VocabularyItem.fromJson(rows.first);
  }

  @override
  Future<VocabularyItem> create({
    required String word,
    required String language,
    String? deckId,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': _userId,
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
    final row = await _client
        .from(_table)
        .update(item.toJson()
          ..remove('id')
          ..remove('user_id'))
        .eq('id', item.id)
        .eq('user_id', _userId)
        .select()
        .single();
    return VocabularyItem.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id).eq('user_id', _userId);
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
    final row = await _client
        .from(_table)
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
        .eq('user_id', _userId)
        .select()
        .single();
    return VocabularyItem.fromJson(row);
  }
}
