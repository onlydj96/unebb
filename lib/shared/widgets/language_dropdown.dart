import 'package:flutter/material.dart';

import 'package:unebb/core/constants/languages.dart';

/// A dropdown form field for selecting a language.
///
/// If [value] is not in the offered list (e.g. a word saved with a language
/// that is no longer offered) it is still shown — otherwise Flutter's
/// dropdown asserts and the screen fails to build.
class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Language',
    this.languages,
    this.validator,
  });

  /// Currently selected language.
  final String value;

  /// Callback when selection changes.
  final ValueChanged<String?> onChanged;

  /// Label for the dropdown field.
  final String label;

  /// List of languages to show. Defaults to [SupportedLanguages.learning].
  final List<String>? languages;

  /// Optional validator function.
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final offered = languages ?? SupportedLanguages.learning;
    final items = offered.contains(value) ? offered : [...offered, value];

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      validator: validator,
      items: [
        for (final lang in items)
          DropdownMenuItem(value: lang, child: Text(lang)),
      ],
      onChanged: onChanged,
    );
  }
}

/// A dropdown specifically for native language selection.
class NativeLanguageDropdown extends StatelessWidget {
  const NativeLanguageDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Native Language',
    this.validator,
  });

  final String value;
  final ValueChanged<String?> onChanged;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return LanguageDropdown(
      value: value,
      onChanged: onChanged,
      label: label,
      languages: SupportedLanguages.native,
      validator: validator,
    );
  }
}

/// A dropdown specifically for learning language selection.
class LearningLanguageDropdown extends StatelessWidget {
  const LearningLanguageDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Learning Language',
    this.validator,
  });

  final String value;
  final ValueChanged<String?> onChanged;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return LanguageDropdown(
      value: value,
      onChanged: onChanged,
      label: label,
      languages: SupportedLanguages.learning,
      validator: validator,
    );
  }
}
