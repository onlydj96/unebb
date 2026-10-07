import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/repositories/deck_repository.dart';

class SupabaseDeckRepository implements DeckRepository {
  const SupabaseDeckRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Deck>> getAll() async {
    final rows = await _client
        .from('decks')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return rows.map((row) => Deck.fromJson(row)).toList();
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
