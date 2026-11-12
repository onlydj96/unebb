import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unebb/core/providers/connectivity_provider.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/l10n/app_localizations.dart';

/// Wraps [home] like the real app: localizations, theme-independent
/// MaterialApp and a ProviderScope with test overrides.
///
/// Connectivity is reported online so no platform channel is touched.
/// [prefs] seeds SharedPreferences (e.g. cached data or saved progress).
Future<Widget> testApp(
  Widget home, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  Map<String, Object> prefs = const {},
}) async {
  return ProviderScope(
    overrides: [
      ...await _baseOverrides(prefs),
      ...overrides,
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Like [testApp] but with a GoRouter, for flows that navigate.
Future<Widget> testRouterApp({
  required List<RouteBase> routes,
  String initialLocation = '/',
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
}) async {
  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  return ProviderScope(
    overrides: [
      ...await _baseOverrides(prefs),
      ...overrides,
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<List<Override>> _baseOverrides(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(instance),
    isOnlineProvider.overrideWithValue(true),
  ];
}
