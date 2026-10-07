import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight profile model — only fields needed at runtime.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.nativeLanguage,
    required this.learningLanguage,
  });

  final String id;
  final String displayName;
  final String nativeLanguage;
  final String learningLanguage;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      nativeLanguage: json['native_language'] as String? ?? 'Korean',
      learningLanguage: json['learning_language'] as String? ?? 'English',
    );
  }
}

/// Fetches the signed-in user's profile row from `profiles`.
/// Returns null if not yet set up or not signed in.
final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final rows = await client
      .from('profiles')
      .select()
      .eq('id', userId)
      .limit(1);

  if (rows.isEmpty) return null;
  return UserProfile.fromJson(rows.first);
});
