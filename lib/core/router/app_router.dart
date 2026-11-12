import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/auth/screens/login_screen.dart';
import 'package:unebb/features/auth/screens/profile_setup_screen.dart';
import 'package:unebb/features/auth/screens/signup_screen.dart';
import 'package:unebb/features/decks/screens/create_deck_screen.dart';
import 'package:unebb/features/decks/screens/deck_detail_screen.dart';
import 'package:unebb/features/decks/screens/decks_list_screen.dart';
import 'package:unebb/features/home/screens/dashboard_screen.dart';
import 'package:unebb/features/home/screens/home_shell_screen.dart';
import 'package:unebb/features/review/screens/review_screen.dart';
import 'package:unebb/features/settings/screens/settings_screen.dart';
import 'package:unebb/features/vocabulary/screens/add_word_screen.dart';
import 'package:unebb/features/vocabulary/screens/edit_word_screen.dart';
import 'package:unebb/features/vocabulary/screens/vocabulary_list_screen.dart';
import 'package:unebb/features/vocabulary/screens/word_added_screen.dart';
import 'package:unebb/features/vocabulary/screens/word_detail_screen.dart';

/// Listens to Riverpod auth/profile state and notifies GoRouter to
/// re-evaluate the redirect guard whenever either changes.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthState>>(
      authStateChangesProvider,
      (_, __) => notifyListeners(),
    );
    ref.listen<AsyncValue<UserProfile?>>(
      profileProvider,
      (_, __) => notifyListeners(),
    );
  }
}

/// Decides where a navigation to [location] should go instead (or null).
///
/// * Signed-out users only reach the public auth routes.
/// * Signed-in users without a profile row (signed up with email
///   confirmation, or signed in on a fresh account) are sent to profile setup
///   once the profile has loaded — previously they silently got defaults.
@visibleForTesting
String? resolveRedirect({
  required String location,
  required bool isLoggedIn,
  required AsyncValue<UserProfile?> profile,
}) {
  // Profile setup needs a session (saving without one can only fail).
  const publicRoutes = {'/login', '/signup'};
  final isPublic = publicRoutes.contains(location);

  if (!isLoggedIn) return isPublic ? null : '/login';
  if (isPublic) return '/';

  // Only a completed, successful fetch that found no row means "missing".
  // Errors and reloads still carry the stale `null` from the signed-out state
  // (Riverpod even reports a refresh as AsyncData with isLoading); treating
  // them as missing sent existing users to the first-run form (and Save
  // overwrote their profile with defaults).
  final missingProfile = profile is AsyncData<UserProfile?> &&
      !profile.isLoading &&
      profile.value == null;
  if (missingProfile && location != '/profile-setup') return '/profile-setup';
  return null;
}

/// The application router, exposed as a Riverpod [Provider].
///
/// GoRouter evaluates [redirect] on every navigation event and whenever
/// [_RouterNotifier] calls [notifyListeners] (auth or profile changes).
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = ref.read(authStateChangesProvider);

    // Fall back to the synchronous session before the stream emits.
    final currentSession = Supabase.instance.client.auth.currentSession;
    final isLoggedIn =
        authAsync.valueOrNull?.session != null || currentSession != null;

    return resolveRedirect(
      location: state.matchedLocation,
      isLoggedIn: isLoggedIn,
      profile: isLoggedIn
          ? ref.read(profileProvider)
          : const AsyncValue<UserProfile?>.data(null),
    );
  }

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: redirect,
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Main app with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Dashboard tab (index 0)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Decks tab (index 1)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/decks',
                builder: (context, state) => const DecksListScreen(),
              ),
            ],
          ),
          // Settings tab (index 2)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Detail routes (outside of shell). Path parameters are guaranteed by
      // the route pattern, so they are read with `!`.
      GoRoute(
        path: '/decks/create',
        builder: (context, state) => const CreateDeckScreen(),
      ),
      GoRoute(
        path: '/decks/:id',
        builder: (context, state) =>
            DeckDetailScreen(deckId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/decks/:deckId/add-word',
        builder: (context, state) =>
            AddWordScreen(deckId: state.pathParameters['deckId']),
      ),
      GoRoute(
        path: '/words',
        builder: (context, state) => const VocabularyListScreen(),
      ),
      GoRoute(
        path: '/words/:id',
        builder: (context, state) =>
            WordDetailScreen(wordId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/words/:id/edit',
        builder: (context, state) =>
            EditWordScreen(wordId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/add-word',
        builder: (context, state) => const AddWordScreen(),
      ),
      GoRoute(
        path: '/word-added/:id',
        builder: (context, state) =>
            WordAddedScreen(vocabularyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'due';
          final limitStr = state.uri.queryParameters['limit'];
          final limit = limitStr != null ? int.tryParse(limitStr) : null;
          final deckId = state.uri.queryParameters['deckId'];
          return ReviewScreen(mode: mode, limit: limit, deckId: deckId);
        },
      ),
    ],
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});
