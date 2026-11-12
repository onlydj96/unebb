import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/features/auth/providers/auth_provider.dart';

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  late StreamController<AuthState> auth;
  late User? gotrueUser;
  late ProviderContainer container;

  setUp(() {
    auth = StreamController<AuthState>();
    gotrueUser = _user;
    container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => auth.stream),
      authClientUserProvider.overrideWithValue(() => gotrueUser),
    ]);
    container.listen(currentUserIdProvider, (_, __) {});
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  test('an offline token-refresh error keeps the user signed in', () async {
    auth.add(const AuthState(AuthChangeEvent.signedIn, null));
    await pumpEventQueue();
    expect(container.read(currentUserIdProvider), 'user-1');

    // gotrue keeps the session but emits the failure on the stream.
    auth.addError(AuthRetryableFetchException());
    await pumpEventQueue();

    expect(container.read(currentUserIdProvider), 'user-1');
  });

  test('signing out clears the user id', () async {
    auth.add(const AuthState(AuthChangeEvent.signedIn, null));
    await pumpEventQueue();

    gotrueUser = null;
    auth.add(const AuthState(AuthChangeEvent.signedOut, null));
    await pumpEventQueue();

    expect(container.read(currentUserIdProvider), isNull);
  });
}
