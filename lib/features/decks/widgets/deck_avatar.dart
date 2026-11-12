import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';

/// Two-letter language badge used for decks, colour-coded per language so
/// decks in the same language share a colour.
class DeckAvatar extends StatelessWidget {
  const DeckAvatar({super.key, required this.language, this.radius});

  final String language;
  final double? radius;

  static const _tones = [
    AppTone.error,
    AppTone.success,
    AppTone.warning,
    AppTone.neutral,
  ];

  /// "English" → "EN"; safe for short or empty names (previously
  /// `substring(0, 2)` threw a RangeError for them).
  static String abbreviation(String language) {
    final trimmed = language.trim();
    if (trimmed.isEmpty) return '?';
    final characters = trimmed.characters;
    return characters.take(2).toString().toUpperCase();
  }

  /// Stable palette tone for [language].
  static AppTone toneFor(String language) {
    final key = language.trim().toLowerCase();
    final sum = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return _tones[sum % _tones.length];
  }

  @override
  Widget build(BuildContext context) {
    final r = radius ?? 20;
    final tone = toneFor(language);
    return CircleAvatar(
      radius: r,
      backgroundColor: tone == AppTone.neutral ? null : tone.soft,
      child: Text(
        abbreviation(language),
        style: AppTypography.labelLarge.copyWith(
          fontSize: r * 0.62,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: tone == AppTone.neutral ? null : tone.foreground,
        ),
      ),
    );
  }
}
