import 'package:flutter/foundation.dart';

/// Simple logger utility for consistent error logging across the app.
///
/// Usage:
/// ```dart
/// AppLogger.error('Failed to load data', error: e, stackTrace: st);
/// AppLogger.warning('Deprecated API usage');
/// AppLogger.info('User logged in');
/// ```
class AppLogger {
  AppLogger._();

  /// Log error messages with optional error object and stack trace
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   StackTrace: $stackTrace');
      }
    }
    // TODO: Send to crash reporting service in production
  }

  /// Log warning messages
  static void warning(String message, {Object? details}) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
      if (details != null) {
        debugPrint('   Details: $details');
      }
    }
  }

  /// Log informational messages (development only)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Log debug messages (development only)
  static void debug(String message, {Object? data}) {
    if (kDebugMode) {
      debugPrint('🔍 DEBUG: $message');
      if (data != null) {
        debugPrint('   Data: $data');
      }
    }
  }
}
