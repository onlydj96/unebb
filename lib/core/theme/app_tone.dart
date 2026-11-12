import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic tone for notices, badges and status visuals.
///
/// Each tone resolves to a soft background, a strong fill and a foreground
/// that stays readable on the soft background.
enum AppTone {
  neutral,
  success,
  warning,
  error;

  /// Tinted background for panels and chips.
  Color get soft => switch (this) {
        AppTone.neutral => AppColors.surface,
        AppTone.success => AppColors.successSoft,
        AppTone.warning => AppColors.warningSoft,
        AppTone.error => AppColors.errorSoft,
      };

  /// Solid accent for fills, rings and bars.
  Color get strong => switch (this) {
        AppTone.neutral => AppColors.cocoa,
        AppTone.success => AppColors.success,
        AppTone.warning => AppColors.warning,
        AppTone.error => AppColors.error,
      };

  /// Icon and emphasis colour on [soft] or the page background.
  Color get foreground => switch (this) {
        AppTone.neutral => AppColors.textSecondary,
        AppTone.success => AppColors.successText,
        AppTone.warning => AppColors.warningText,
        AppTone.error => AppColors.error,
      };
}
