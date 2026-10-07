import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double small = 6.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xLarge = 24.0;
  static const double full = 999.0;

  static BorderRadius get smallBorder => BorderRadius.circular(small);
  static BorderRadius get mediumBorder => BorderRadius.circular(medium);
  static BorderRadius get largeBorder => BorderRadius.circular(large);
  static BorderRadius get xLargeBorder => BorderRadius.circular(xLarge);
  static BorderRadius get fullBorder => BorderRadius.circular(full);
}
