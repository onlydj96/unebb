import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unebb/core/constants.dart';
import 'package:unebb/core/router/app_router.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/theme/app_theme.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for local caching
  final prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const UnEbbApp(),
    ),
  );
}

class UnEbbApp extends ConsumerWidget {
  const UnEbbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Rebinding the cache to the new account (or to nobody after sign-out)
    // wipes the previous account's data right away instead of on next read.
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next) ref.read(cacheServiceProvider);
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ko'),
      ],
    );
  }
}
