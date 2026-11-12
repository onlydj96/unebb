import 'package:flutter/widgets.dart';
import 'package:unebb/l10n/app_localizations.dart';

export 'package:unebb/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  /// Localized strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
