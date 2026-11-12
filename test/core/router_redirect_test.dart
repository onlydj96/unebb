import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/core/router/app_router.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';

const _profile = UserProfile(
  id: 'u',
  displayName: 'Tester',
  nativeLanguage: 'Korean',
  learningLanguage: 'English',
);

String? _redirect(
  String location, {
  bool loggedIn = true,
  AsyncValue<UserProfile?> profile = const AsyncValue.data(_profile),
}) =>
    resolveRedirect(location: location, isLoggedIn: loggedIn, profile: profile);

void main() {
  test('signed-out users can only reach the auth routes', () {
    expect(_redirect('/', loggedIn: false), '/login');
    expect(_redirect('/decks/1', loggedIn: false), '/login');
    expect(_redirect('/login', loggedIn: false), isNull);
    expect(_redirect('/signup', loggedIn: false), isNull);
    // Saving a profile without a session can only fail.
    expect(_redirect('/profile-setup', loggedIn: false), '/login');
  });

  test('signed-in users skip the login and sign-up screens', () {
    expect(_redirect('/login'), '/');
    expect(_redirect('/signup'), '/');
    expect(_redirect('/decks/1'), isNull);
  });

  test('accounts without a profile are sent to profile setup', () {
    expect(
        _redirect('/', profile: const AsyncValue.data(null)), '/profile-setup');
    expect(
      _redirect('/profile-setup', profile: const AsyncValue.data(null)),
      isNull,
    );
  });

  test('no profile redirect while loading or when the fetch failed', () {
    expect(_redirect('/', profile: const AsyncValue.loading()), isNull);
    expect(
      _redirect('/',
          profile: AsyncValue.error(Exception('offline'), StackTrace.empty)),
      isNull,
    );
  });

  test('a failed fetch that still carries the signed-out null is not "missing"',
      () {
    // Riverpod copies the previous value into errors and reloads.
    final staleError = const AsyncValue<UserProfile?>.data(null)
        .copyWithPrevious(const AsyncValue.data(null));
    final failedAfterSignIn = AsyncValue<UserProfile?>.error(
      Exception('offline'),
      StackTrace.empty,
    ).copyWithPrevious(staleError);
    final reloading =
        const AsyncValue<UserProfile?>.loading().copyWithPrevious(staleError);

    expect(failedAfterSignIn.hasValue, isTrue);
    expect(_redirect('/', profile: failedAfterSignIn), isNull);
    expect(_redirect('/', profile: reloading), isNull);
  });

  test('the profile screen stays reachable for editing', () {
    expect(_redirect('/profile-setup'), isNull);
  });
}
