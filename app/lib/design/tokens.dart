// Design tokens for RAKIA. Source of truth: docs/design/DESIGN_SYSTEM.md.
// Colour values were measured from the four owner-supplied references.
// Never hard-code colours, sizes or durations in widgets; use these tokens.
import 'package:flutter/widgets.dart';

/// Raw palette. Widgets should use the semantic [RakiaColors] extension, not
/// these values directly.
abstract final class RakiaPalette {
  // Dark ("Mission") surfaces: violet-tinted blacks from reference 4.
  static const Color canvasDark = Color(0xFF08060E);
  static const Color surface1Dark = Color(0xFF100C18);
  static const Color surface2Dark = Color(0xFF16121F);
  static const Color surface3Dark = Color(0xFF1F1A2B);
  static const Color borderSubtleDark = Color(0xFF2A2438);
  static const Color borderControlDark = Color(0xFF7A7192);
  static const Color textPrimaryDark = Color(0xFFF5F3FA);
  static const Color textSecondaryDark = Color(0xFFA69FB8);

  // Brand (reference 2) and accents.
  static const Color violet = Color(0xFF7D39EB);
  static const Color violetSoft = Color(0xFFB79CFF);
  static const Color lime = Color(0xFFC6FF33);
  static const Color limeDeep = Color(0xFFD0FF00);
  static const Color onLime = Color(0xFF08060E);
  static const Color teal = Color(0xFF5FB8C6);

  // Functional status colours (not in the references; required for safety).
  static const Color amber = Color(0xFFFFB547);
  static const Color coral = Color(0xFFFF6B78);

  // Light ("Ground") theme.
  static const Color canvasLight = Color(0xFFF4F2F8);
  static const Color surface1Light = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFFAF9FC);
  static const Color surface3Light = Color(0xFFECE9F2);
  static const Color borderSubtleLight = Color(0xFFE0DCE8);
  static const Color borderControlLight = Color(0xFF7A7290);
  static const Color lilac = Color(0xFFADA4BF);
  static const Color textPrimaryLight = Color(0xFF14101C);
  static const Color textSecondaryLight = Color(0xFF6B6480);
  static const Color violetText = Color(0xFF5B2BC4);
  static const Color limeText = Color(0xFF4E5F00);
  static const Color amberText = Color(0xFF8A5A00);
  static const Color coralText = Color(0xFFC2283A);
  static const Color tealText = Color(0xFF1F6B78);
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

abstract final class RakiaRadii {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 24;
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
