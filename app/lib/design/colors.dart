import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colour roles, available through `RakiaColors.of(context)`.
@immutable
class RakiaColors extends ThemeExtension<RakiaColors> {
  const RakiaColors({
    required this.canvas,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.borderSubtle,
    required this.borderControl,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.onBrand,
    required this.brandText,
    required this.action,
    required this.onAction,
    required this.focusRing,
    required this.statusWithinBaseline,
    required this.statusWatch,
    required this.statusAct,
    required this.statusInsufficient,
    required this.statusDataQuality,
    required this.simulated,
  });

  final Color canvas;
  final Color surface1;
  final Color surface2;
  final Color surface3;

  /// Decorative dividers only (no contrast requirement).
  final Color borderSubtle;

  /// Outlines of interactive controls (>= 3:1 against surfaces).
  final Color borderControl;
  final Color textPrimary;
  final Color textSecondary;

  /// Brand violet fill and the text colour used on top of it.
  final Color brand;
  final Color onBrand;

  /// Brand colour when used as text or icon on the canvas.
  final Color brandText;

  /// Primary call-to-action fill and the text colour used on top of it.
  final Color action;
  final Color onAction;
  final Color focusRing;

  // Health status colours. Always paired with a glyph and a word.
  final Color statusWithinBaseline;
  final Color statusWatch;
  final Color statusAct;
  final Color statusInsufficient;
  final Color statusDataQuality;
  final Color simulated;

  static const RakiaColors dark = RakiaColors(
    canvas: RakiaPalette.canvasDark,
    surface1: RakiaPalette.surface1Dark,
    surface2: RakiaPalette.surface2Dark,
    surface3: RakiaPalette.surface3Dark,
    borderSubtle: RakiaPalette.borderSubtleDark,
    borderControl: RakiaPalette.borderControlDark,
    textPrimary: RakiaPalette.textPrimaryDark,
    textSecondary: RakiaPalette.textSecondaryDark,
    brand: RakiaPalette.violet,
    onBrand: Color(0xFFFFFFFF),
    brandText: RakiaPalette.violetSoft,
    action: RakiaPalette.lime,
    onAction: RakiaPalette.onLime,
    focusRing: RakiaPalette.lime,
    statusWithinBaseline: RakiaPalette.lime,
    statusWatch: RakiaPalette.amber,
    statusAct: RakiaPalette.coral,
    statusInsufficient: RakiaPalette.textSecondaryDark,
    statusDataQuality: RakiaPalette.teal,
    simulated: RakiaPalette.violetSoft,
  );

  static const RakiaColors light = RakiaColors(
    canvas: RakiaPalette.canvasLight,
    surface1: RakiaPalette.surface1Light,
    surface2: RakiaPalette.surface2Light,
    surface3: RakiaPalette.surface3Light,
    borderSubtle: RakiaPalette.borderSubtleLight,
    borderControl: RakiaPalette.borderControlLight,
    textPrimary: RakiaPalette.textPrimaryLight,
    textSecondary: RakiaPalette.textSecondaryLight,
    brand: RakiaPalette.violet,
    onBrand: Color(0xFFFFFFFF),
    brandText: RakiaPalette.violetText,
    action: RakiaPalette.violetText,
    onAction: Color(0xFFFFFFFF),
    focusRing: RakiaPalette.violetText,
    statusWithinBaseline: RakiaPalette.limeText,
    statusWatch: RakiaPalette.amberText,
    statusAct: RakiaPalette.coralText,
    statusInsufficient: RakiaPalette.textSecondaryLight,
    statusDataQuality: RakiaPalette.tealText,
    simulated: RakiaPalette.violetText,
  );

  static RakiaColors of(BuildContext context) =>
      Theme.of(context).extension<RakiaColors>() ?? dark;

  @override
  RakiaColors copyWith() => this;

  @override
  RakiaColors lerp(ThemeExtension<RakiaColors>? other, double t) {
    // Theme changes are discrete; no colour interpolation (reduced motion).
    if (other is! RakiaColors) return this;
    return t < 0.5 ? this : other;
  }
}
