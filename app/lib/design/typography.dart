import 'package:flutter/material.dart';

/// Type scale from docs/design/DESIGN_SYSTEM.md section 3. Sizes are in
/// logical pixels and scale with the platform text-size setting.
abstract final class RakiaType {
  static const String sans = 'Geist';
  static const String mono = 'GeistMono';

  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle s(
      double size,
      double height,
      FontWeight weight, {
      Color? color,
      double letterSpacing = 0,
    }) => TextStyle(
      fontFamily: sans,
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color ?? primary,
    );

    return TextTheme(
      displayLarge: s(56, 60, FontWeight.w600, letterSpacing: -1.2),
      displayMedium: s(48, 52, FontWeight.w600, letterSpacing: -1),
      displaySmall: s(40, 44, FontWeight.w600, letterSpacing: -0.8),
      headlineLarge: s(32, 38, FontWeight.w600, letterSpacing: -0.4),
      headlineMedium: s(28, 34, FontWeight.w600, letterSpacing: -0.3),
      headlineSmall: s(22, 28, FontWeight.w600, letterSpacing: -0.2),
      titleLarge: s(20, 26, FontWeight.w600),
      titleMedium: s(18, 24, FontWeight.w600),
      titleSmall: s(16, 22, FontWeight.w600),
      bodyLarge: s(16, 24, FontWeight.w400),
      bodyMedium: s(14, 20, FontWeight.w400),
      bodySmall: s(13, 18, FontWeight.w400, color: secondary),
      labelLarge: s(14, 20, FontWeight.w500),
      labelMedium: s(13, 18, FontWeight.w500),
      // Micro caps: 12/16 with +0.08em tracking.
      labelSmall: s(
        12,
        16,
        FontWeight.w500,
        color: secondary,
        letterSpacing: 0.96,
      ),
    );
  }

  /// Monospaced numerals for metric values, timestamps and IDs. Tabular
  /// figures stop live values from shifting horizontally as they update.
  static TextStyle metric(TextStyle base) => base.copyWith(
    fontFamily: mono,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
