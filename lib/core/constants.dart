// App-wide constants for UnEbb.
// Only public/client-safe values belong here.
// Never place secret keys or service role keys in Flutter source.
class AppConstants {
  AppConstants._();

  // Supabase configuration loaded from environment variables via --dart-define
  // Build with: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wpltoklurqwwvtdznovx.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_8pBxDn0lbzmqJAbvghLIjQ_cYpq1eNi',
  );

  static const String appName = 'UnEbb';
}
