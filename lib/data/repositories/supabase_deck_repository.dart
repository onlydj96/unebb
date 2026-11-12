import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/data/repositories/base_supabase_repository.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/repositories/deck_repository.dart';

class SupabaseDeckRepository
    with SupabaseRepositoryMixin
    implements DeckRepository {
  SupabaseDeckRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  String get tableName => 'decks';

  @override
  Future<List<Deck>> getAll() async {
    // Activity ordering and live word counts are derived client-side by
    // DeckOverview from data already in memory, so one query is enough.
    final rows = await client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) => Deck.fromJson(row)).toList();
  }

  @override
  Future<Deck?> getById(String id) async {
    final rows = await client
        .from(tableName)
        .select()
        .eq('id', id)
        .eq('user_id', userId)
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
    final row = await client
        .from(tableName)
        .insert({
          'user_id': userId,
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
    final row = await client
        .from(tableName)
        .update({
          'name': deck.name,
          'description': deck.description,
          'language': deck.language,
        })
        .eq('id', deck.id)
        .eq('user_id', userId)
        .select()
        .single();

    return Deck.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await client.from(tableName).delete().eq('id', id).eq('user_id', userId);
  }
}
