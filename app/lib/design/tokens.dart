// Design tokens for RAKIA. Source of truth: docs/design/DESIGN_SYSTEM.md.
// Neumorphic ("soft UI") system after the four owner-supplied Figma
// Community kits: one soft surface per theme that elements rise out of or
// sink into, paired light and dark shadows, generous rounding and a single
// accent. Never hard-code colours, sizes or durations in widgets.
import 'package:flutter/widgets.dart';

/// Raw palette. Widgets should use the semantic [RakiaColors] extension, not
/// these values directly. Every text colour is checked against both the
/// surface and the inset well in test/design_tokens_test.dart (WCAG AA).
abstract final class RakiaPalette {
  // Light ("Ground"): the cool grey of the kits.
  static const Color surfaceLight = Color(0xFFE6EAF0);
  static const Color wellLight = Color(0xFFDAE0E8);
  static const Color highlightLight = Color(0xFFFFFFFF);
  static const Color shadowLight = Color(0xFFA9B6C8);
  static const Color dividerLight = Color(0xFFCFD6E0);
  static const Color controlLight = Color(0xFF687284);
  static const Color textPrimaryLight = Color(0xFF1C2430);
  static const Color textSecondaryLight = Color(0xFF4A5465);
  static const Color accentLight = Color(0xFF4334B0);

  // Dark ("Mission"): the same system on a deep slate.
  static const Color surfaceDark = Color(0xFF1F232B);
  static const Color wellDark = Color(0xFF171A20);
  static const Color highlightDark = Color(0xFF2B303A);
  static const Color shadowDark = Color(0xFF0F1115);
  static const Color dividerDark = Color(0xFF2E333D);
  static const Color controlDark = Color(0xFF7D8697);
  static const Color textPrimaryDark = Color(0xFFE8EBF1);
  static const Color textSecondaryDark = Color(0xFFA9B2C1);
  static const Color accentDark = Color(0xFFA594FF);
  static const Color accentTextDark = Color(0xFFB5A8FF);
  static const Color onAccentDark = Color(0xFF14121C);

  // Brand mark (logo only).
  static const Color violet = Color(0xFF7D39EB);
  static const Color violetDeep = Color(0xFF5B2BC4);
  static const Color lime = Color(0xFFC6FF33);

  // Functional status colours, one hue per meaning, always paired with a
  // glyph and a word.
  static const Color okLight = Color(0xFF2A6439);
  static const Color watchLight = Color(0xFF7E4F00);
  static const Color actLight = Color(0xFFA8231C);
  static const Color dataQualityLight = Color(0xFF1C6370);
  static const Color okDark = Color(0xFFB9EC6B);
  static const Color watchDark = Color(0xFFFFB547);
  static const Color actDark = Color(0xFFFF7A84);
  static const Color dataQualityDark = Color(0xFF6FC4D1);
}

/// Raised and inset depths. A raised element casts its dark shadow down and
/// to the right and catches light up and to the left; an inset one has the
/// same pair on the inside.
abstract final class RakiaDepth {
  /// Cards and panels.
  static const double panel = 8;

  /// Buttons, chips and other controls.
  static const double control = 4;

  /// Blur is twice the offset, so edges stay soft but readable.
  static double blur(double depth) => depth * 2;
}

/// 4-point spacing scale.
abstract final class RakiaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Minimum interactive target size (WCAG 2.5.8 / Material guidance).
  static const double minTarget = 48;
}

/// One radius per size class, used everywhere: small elements (icons,
/// wells), panels, and pills (buttons, inputs, chips).
abstract final class RakiaRadii {
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double pill = 999;
}

/// Responsive breakpoints. Layouts adapt; they never just stretch.
enum RakiaWindowClass { compact, medium, expanded, large }

abstract final class RakiaBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double large = 1440;

  static RakiaWindowClass of(double width) {
    if (width >= large) return RakiaWindowClass.large;
    if (width >= expanded) return RakiaWindowClass.expanded;
    if (width >= medium) return RakiaWindowClass.medium;
    return RakiaWindowClass.compact;
  }
}

/// Motion tokens. Navigation is frequent, so it does not animate; state
/// changes are short. Everything collapses to zero when the platform asks
/// for reduced motion.
abstract final class RakiaMotion {
  static const Duration stateChange = Duration(milliseconds: 120);
  static const Duration surfaceEnter = Duration(milliseconds: 180);
  static const Curve easeOut = Curves.easeOutCubic;

  static Duration of(BuildContext context, Duration base) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : base;
}
