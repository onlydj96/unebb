import 'package:supabase_flutter/supabase_flutter.dart';

/// Mixin providing common Supabase repository functionality.
mixin SupabaseRepositoryMixin {
  /// The Supabase client instance. Must be implemented by the repository.
  SupabaseClient get client;

  /// The table name for this repository. Must be implemented by the repository.
  String get tableName;

  /// Gets the current authenticated user's ID.
  /// Throws [StateError] if no user is authenticated.
  String get userId {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('User must be authenticated to access this repository');
    }
    return user.id;
  }

  /// Creates a base query with user_id filter applied.
  PostgrestFilterBuilder<List<Map<String, dynamic>>> baseQuery() {
    return client.from(tableName).select().eq('user_id', userId);
  }
}
