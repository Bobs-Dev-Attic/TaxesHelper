import 'package:flutter/material.dart';

/// App-wide theming. A single seed colour drives both light and dark schemes.
///
/// Kept intentionally minimal (colour scheme only) so it compiles cleanly
/// across Flutter versions without depending on component-theme classes that
/// have been renamed over time.
class AppTheme {
  static const Color _seed = Color(0xFF1B6B5A);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
    );
  }
}

/// Money/colour helpers shared across screens.
class SectionColors {
  static Color income(BuildContext context) => const Color(0xFF2E7D32);
  static Color expense(BuildContext context) => const Color(0xFFC62828);
  static Color deduction(BuildContext context) => const Color(0xFF1565C0);
}
