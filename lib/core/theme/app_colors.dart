import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF4F6AF5);
  static const Color secondary = Color(0xFF8B9FFF);

  // Surface
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF5F6FA);
  static const Color background = Color(0xFFF8F9FE);

  // Text
  static const Color textPrimary = Color(0xFF0D0F1A);
  static const Color textSecondary = Color(0xFF4A4E6B);
  static const Color textMuted = Color(0xFF9196B0);

  // Semantic
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);

  // Memory stages
  static const Color memoryStrong = Color(0xFF34C759); // Stage 1
  static const Color memoryMedium = Color(0xFF4F6AF5); // Stage 2
  static const Color memoryWeak = Color(0xFFFF9500); // Stage 3
  static const Color memoryCritical = Color(0xFFFF3B30); // Stage 4
}
