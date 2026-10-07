import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emits every auth state change (sign-in, sign-out, token refresh, etc.).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Convenience provider for the currently signed-in user, or null when signed out.
final currentUserProvider = Provider<User?>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  return authAsync.when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, __) => null,
  );
});

// ---------------------------------------------------------------------------
// Auth actions — used by screens, never call Supabase directly from widgets
// ---------------------------------------------------------------------------

Future<void> signInWithEmail({
  required String email,
  required String password,
}) async {
  await Supabase.instance.client.auth.signInWithPassword(
    email: email,
    password: password,
  );
}

/// Returns true if a session was created immediately (no email confirmation needed).
/// Returns false if email confirmation is required.
Future<bool> signUpWithEmail({
  required String email,
  required String password,
}) async {
  final response = await Supabase.instance.client.auth.signUp(
    email: email,
    password: password,
  );
  return response.session != null;
}

Future<void> signOut() async {
  await Supabase.instance.client.auth.signOut();
}

Future<void> upsertProfile({
  required String displayName,
  required String nativeLanguage,
  required String learningLanguage,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('Not signed in. Please log in again.');
  final userId = user.id;
  await Supabase.instance.client.from('profiles').upsert({
    'id': userId,
    'display_name': displayName,
    'native_language': nativeLanguage,
    'learning_language': learningLanguage,
  });
}
