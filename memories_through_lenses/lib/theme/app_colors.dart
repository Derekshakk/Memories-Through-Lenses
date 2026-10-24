import 'package:flutter/material.dart';

/// Theme-aware replacements for colors that were hard-coded for light mode.
///
/// Every light value is exactly the color the screen used before, so the
/// default (light) design is unchanged; dark values keep text readable.
class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Page background (was Colors.grey[50]).
  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF121212) : Colors.grey[50]!;

  /// Cards, inputs and panels (was Colors.white).
  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E1E1E) : Colors.white;

  /// Subtle fills such as search bars and headers (was Colors.grey[100]).
  static Color subtle(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2C) : Colors.grey[100]!;

  /// Primary text drawn on [background]/[surface] (was Colors.black87).
  static Color text(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black87;

  /// Secondary text/icons. Pass the original light color.
  static Color muted(BuildContext context, Color light) =>
      isDark(context) ? Colors.grey[400]! : light;
}
