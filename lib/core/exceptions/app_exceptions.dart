import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Base exception class for application-specific errors.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when attempting to add a word that already exists.
///
/// [existingDeckId] is the deck that already contains the word, when known
/// (null for words outside any deck or when the server did not say).
class DuplicateWordException extends AppException {
  const DuplicateWordException({
    required this.word,
    this.existingDeckId,
  }) : super('Word "$word" already exists');

  final String word;
  final String? existingDeckId;
}

/// Thrown when creating a deck whose name is already used by the user.
class DuplicateDeckException extends AppException {
  const DuplicateDeckException({required this.name})
      : super('A deck named "$name" already exists');

  final String name;
}

/// Thrown when AI content (definition, explanation…) could not be produced.
class AiContentUnavailableException extends AppException {
  const AiContentUnavailableException({required this.word})
      : super('AI content for "$word" is not available');

  final String word;
}

/// Postgres SQLSTATE helpers for errors surfaced by PostgREST.
abstract final class PgErrorCodes {
  static const uniqueViolation = '23505';
  static const checkViolation = '23514';

  static bool isUniqueViolation(Object error) =>
      error is PostgrestException && error.code == uniqueViolation;
}
