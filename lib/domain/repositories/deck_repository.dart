import 'package:unebb/domain/models/deck.dart';

/// Repository interface for deck operations.
abstract class DeckRepository {
  /// Get all decks for the current user.
  Future<List<Deck>> getAll();

  /// Get a single deck by ID.
  Future<Deck?> getById(String id);

  /// Create a new deck.
  Future<Deck> create({
    required String name,
    required String language,
    String? description,
  });

  /// Update an existing deck.
  Future<Deck> update(Deck deck);

  /// Delete a deck and all its vocabulary items.
  Future<void> delete(String id);
}
