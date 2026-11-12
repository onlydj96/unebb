import 'package:flutter/material.dart';

/// A filled button that shows a loading indicator when [isLoading] is true.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.icon,
  });

  /// Callback when the button is pressed. Disabled when [isLoading] is true.
  final VoidCallback? onPressed;

  /// The button label text.
  final String label;

  /// Whether to show loading indicator instead of label.
  final bool isLoading;

  /// Optional icon to show before the label.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    if (icon != null && !isLoading) {
      return FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon),
        label: child,
      );
    }

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: child,
    );
  }
}

/// An outlined button that shows a loading indicator when [isLoading] is true.
class LoadingOutlinedButton extends StatelessWidget {
  const LoadingOutlinedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    if (icon != null && !isLoading) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon),
        label: child,
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: child,
    );
  }
}
