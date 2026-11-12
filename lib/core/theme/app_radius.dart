import 'package:flutter/material.dart';

/// Corner radii. Circles are the brand motif, so interactive controls are
/// pills ([full]) and containers use generous rounding.
abstract final class AppRadius {
  static const double small = 8.0;
  static const double medium = 14.0;
  static const double large = 20.0;
  static const double xLarge = 28.0;
  static const double full = 999.0;

  static BorderRadius get smallBorder => BorderRadius.circular(small);
  static BorderRadius get mediumBorder => BorderRadius.circular(medium);
  static BorderRadius get largeBorder => BorderRadius.circular(large);
  static BorderRadius get xLargeBorder => BorderRadius.circular(xLarge);
  static BorderRadius get fullBorder => BorderRadius.circular(full);
}
