import 'package:flutter/material.dart';

/// UnEbb colour tokens.
///
/// Built on the huemint "brand intersection" palette
/// (`fffdfc · 4e3029 · b23b40 · 73c09c`). Each brand colour has one job:
///
/// * [paper]   — the page everything sits on.
/// * [cocoa]   — ink: text, primary actions, dark surfaces.
/// * [crimson] — the *ebb*: forgetting, mistakes, urgency.
/// * [mint]    — the *flow*: recall, success, strong memory.
///
/// Every other colour is derived from these four (tints of cocoa over paper
/// for surfaces, deeper shades where an accent has to carry text). Feature
/// code uses the semantic names below, never the raw hex values.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color paper = Color(0xFFFFFDFC);
  static const Color cocoa = Color(0xFF4E3029);
  static const Color crimson = Color(0xFFB23B40);
  static const Color mint = Color(0xFF73C09C);

  // ── Derived tints & shades ───────────────────────────────────────────────
  /// Crimson at ~10% over paper — background for "ebb" states.
  static const Color crimsonSoft = Color(0xFFF7EAE9);

  /// Mint at ~14% over paper — background for "flow" states.
  static const Color mintSoft = Color(0xFFEAF5EF);

  /// Mint dark enough to carry text on paper (≈5:1).
  static const Color mintDeep = Color(0xFF2F7D5A);

  /// Warm ochre between crimson and cocoa — the only hue added to the
  /// palette, used for "needs attention" (warnings, weak memory).
  static const Color ochre = Color(0xFFD08A3C);
  static const Color ochreSoft = Color(0xFFF9EFE4);

  /// Ochre dark enough to carry text on paper (≈5:1).
  static const Color ochreDeep = Color(0xFF94561F);

  /// Yellow-green halfway between ochre and mint (memory "good").
  static const Color lichen = Color(0xFFA3B46B);

  // ── Logo artwork (assets/logo/logo.svg) ──────────────────────────────────
  /// The recall arc fades from the ebb end, through [logoArcMid], to [mint].
  static const Color logoArcEbb = Color(0xFFE8A4A5);
  static const Color logoArcMid = Color(0xFFB7D8BE);

  /// The ✓ badge — a step deeper than [mint].
  static const Color logoCheck = Color(0xFF57B589);

  // ── Roles ────────────────────────────────────────────────────────────────
  static const Color primary = cocoa;
  static const Color onPrimary = paper;
  static const Color secondary = mint;
  static const Color onSecondary = cocoa;
  static const Color accent = crimson;
  static const Color onAccent = paper;

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color background = paper;

  /// Sand: cards and grouped content sitting on [background].
  static const Color surface = Color(0xFFF7F1EE);

  /// Deeper sand: inputs inside cards, chips, progress tracks.
  static const Color surfaceElevated = Color(0xFFEFE6E2);

  /// Hairline separators and quiet borders.
  static const Color outline = Color(0xFFE7DCD7);

  /// Borders that must be visible (outlined buttons, unselected radios).
  static const Color outlineStrong = Color(0xFFCDBCB5);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = cocoa; // 11.7:1 on paper
  static const Color textSecondary = Color(0xFF806964); // 5.0:1 on paper
  static const Color textMuted = Color(0xFF9A8580); // 3.4:1 — incidental only
  static const Color textOnDark = paper;
  static const Color textOnDarkMuted = Color(0xFFD9CCC7); // 7.5:1 on cocoa

  // ── Semantic ─────────────────────────────────────────────────────────────
  /// Fills and indicators. Put [textPrimary] on top, or use [successText].
  static const Color success = mint;
  static const Color successText = mintDeep;
  static const Color successSoft = mintSoft;

  static const Color warning = ochre;
  static const Color warningText = ochreDeep;
  static const Color warningSoft = ochreSoft;

  /// Crimson carries text on paper (5.8:1) and paper on crimson.
  static const Color error = crimson;
  static const Color errorSoft = crimsonSoft;

  // ── Memory stages (critical → strong runs ebb → flow) ────────────────────
  static const Color memoryStrong = mint; // Stage 1
  static const Color memoryMedium = lichen; // Stage 2
  static const Color memoryWeak = ochre; // Stage 3
  static const Color memoryCritical = crimson; // Stage 4
}
