import 'dart:io';

/// Utility class for handling network-related errors
class NetworkErrorHandler {
  NetworkErrorHandler._();

  /// Check if the error is network-related
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;

    final errorString = error.toString().toLowerCase();

    // Check for common network error patterns
    return errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no internet') ||
        errorString.contains('unreachable') ||
        error is SocketException ||
        error is HttpException;
  }

  /// Get user-friendly error message
  static String getUserMessage(dynamic error) {
    if (isNetworkError(error)) {
      return '인터넷 연결이 필요합니다. 연결 상태를 확인해주세요.';
    }

    // Check for specific Supabase errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('jwt') ||
        errorString.contains('token') ||
        errorString.contains('unauthorized')) {
      return '로그인 세션이 만료되었습니다. 다시 로그인해주세요.';
    }

    if (errorString.contains('rate limit')) {
      return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
    }

    // Generic error message
    return '오류가 발생했습니다. 다시 시도해주세요.';
  }

  /// Get detailed technical error message for logging
  static String getTechnicalMessage(dynamic error) {
    if (error == null) return 'Unknown error';

    if (error is Exception) {
      return error.toString();
    }

    return error.toString();
  }
}
