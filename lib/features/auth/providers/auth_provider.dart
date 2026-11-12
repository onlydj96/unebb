import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emits every auth state change (sign-in, sign-out, token refresh, etc.).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Reads gotrue's signed-in user (overridable in tests).
final authClientUserProvider = Provider<User? Function()>(
  (ref) => () => Supabase.instance.client.auth.currentUser,
);

/// Convenience provider for the currently signed-in user, or null when signed out.
///
/// gotrue's `currentUser` is the source of truth; the auth stream is only
/// watched to recompute on every event. When an offline token refresh fails,
/// gotrue emits an *error* on the stream but keeps the session — mapping that
/// error to "signed out" used to wipe the cache and send the user to the
/// first-run profile screen.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authClientUserProvider)();
});

/// ID of the signed-in user, or null when signed out.
///
/// User-scoped providers watch this so they rebuild (and drop the previous
/// user's data) whenever the account changes. Token refreshes keep the same
/// id, so they do not trigger rebuilds.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
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
