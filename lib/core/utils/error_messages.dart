import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/l10n/l10n.dart';

/// Whether [error] looks like a connectivity problem.
bool isNetworkError(Object error) {
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('connection closed');
}

/// Maps any error to a short, localized message that is safe to show users.
///
/// Raw exception strings (`PostgrestException(message: …, code: 23505…)`)
/// are never shown; they are logged where the error is caught.
String friendlyErrorMessage(AppLocalizations l10n, Object error) {
  switch (error) {
    case DuplicateDeckException(:final name):
      return l10n.duplicateDeckName(name);
    case DuplicateWordException(:final word):
      return l10n.duplicateWordError(word);
    case AiContentUnavailableException():
      return l10n.aiContentMissing;
    case AuthException():
      return _authMessage(l10n, error);
    case TimeoutException():
      return l10n.errorAiUnavailable;
    case FunctionException(:final status):
      if (status == 401) return l10n.errorSessionExpired;
      if (status == 429) return l10n.errorRateLimited;
      return l10n.errorAiUnavailable;
  }

  if (isNetworkError(error)) return l10n.errorNetwork;

  final text = error.toString().toLowerCase();
  if (text.contains('jwt') && text.contains('future')) {
    return l10n.errorClockSync;
  }
  if (text.contains('jwt expired') || text.contains('invalid jwt')) {
    return l10n.errorSessionExpired;
  }
  if (text.contains('rate limit')) return l10n.errorRateLimited;
  return l10n.errorGeneric;
}

String _authMessage(AppLocalizations l10n, AuthException error) {
  if (error is AuthRetryableFetchException) return l10n.errorNetwork;
  switch (error.code) {
    case 'invalid_credentials':
      return l10n.invalidCredentials;
    case 'email_not_confirmed':
      return l10n.emailNotConfirmed;
    case 'user_already_exists':
    case 'email_exists':
      return l10n.userAlreadyExists;
    case 'weak_password':
      return l10n.passwordTooShort;
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return l10n.errorRateLimited;
  }
  final text = error.message.toLowerCase();
  if (text.contains('invalid login')) return l10n.invalidCredentials;
  if (text.contains('not confirmed')) return l10n.emailNotConfirmed;
  if (text.contains('already registered')) return l10n.userAlreadyExists;
  return l10n.errorGeneric;
}
