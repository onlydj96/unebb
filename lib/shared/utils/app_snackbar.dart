import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';

/// Helper class for showing consistent snackbars throughout the app.
///
/// Base styling (floating, cocoa, rounded) comes from the theme; the tone
/// variants only swap the background.
abstract class AppSnackBar {
  AppSnackBar._();

  /// Shows an error snackbar on crimson.
  static void showError(BuildContext context, String message) =>
      _show(context, message, AppColors.error);

  /// Shows a success snackbar on deep mint.
  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, AppColors.successText);

  /// Shows an info snackbar on cocoa.
  static void showInfo(BuildContext context, String message) =>
      _show(context, message, null);

  /// Shows a warning snackbar on deep ochre.
  static void showWarning(BuildContext context, String message) =>
      _show(context, message, AppColors.warningText);

  static void _show(BuildContext context, String message, Color? background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
