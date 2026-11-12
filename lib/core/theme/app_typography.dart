import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale.
///
/// Two voices:
/// * **Serif (Fraunces)** — the things you learn: vocabulary words, big
///   numbers, the wordmark. Styles prefixed `display`, `word`, `numeral`.
/// * **System sans** — the interface: headings, labels, body copy. Keeps
///   Hangul and Latin consistent in every locale.
abstract final class AppTypography {
  /// Bundled in `assets/fonts` (SIL OFL 1.1). Latin only — scripts and
  /// symbols it lacks fall back to the platform font.
  static const String serif = 'Fraunces';

  /// The wordmark face from the logo (Nunito Black, bundled, SIL OFL 1.1).
  /// Only for the "UnEbb" logotype — never for interface text.
  static const String logotypeFamily = 'Nunito';

  /// "UnEbb" logotype. Tracking follows the logo (-8 at 190 px).
  static const TextStyle logotype = TextStyle(
    fontFamily: logotypeFamily,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  // ── Serif ────────────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: serif,
    fontSize: 44,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.2,
    color: AppColors.textPrimary,
    height: 1.08,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: serif,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
    height: 1.12,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: serif,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// A vocabulary word inside a list row or card.
  static const TextStyle word = TextStyle(
    fontFamily: serif,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  /// IPA pronunciation. Sans on purpose: Fraunces has no IPA glyphs.
  static const TextStyle pronunciation = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Stat values and scores.
  static const TextStyle numeral = TextStyle(
    fontFamily: serif,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  // ── Sans ─────────────────────────────────────────────────────────────────
  static const TextStyle headingLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Small tracked label above a section ("DEFINITION", "YOUR PROGRESS").
  static const TextStyle eyebrow = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.textSecondary,
    height: 1.3,
  );
}
