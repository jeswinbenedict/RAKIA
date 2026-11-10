import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds the Material theme for one brightness from RAKIA tokens.
ThemeData buildRakiaTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? RakiaColors.dark
      : RakiaColors.light;
  final text = RakiaType.textTheme(c.textPrimary, c.textSecondary);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.action,
    onPrimary: c.onAction,
    secondary: c.brand,
    onSecondary: c.onBrand,
    tertiary: c.statusDataQuality,
    onTertiary: c.canvas,
    error: c.statusAct,
    onError: c.canvas,
    surface: c.surface1,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.canvas,
    surfaceContainerLow: c.surface1,
    surfaceContainer: c.surface2,
    surfaceContainerHigh: c.surface3,
    surfaceContainerHighest: c.surface3,
    outline: c.borderControl,
    outlineVariant: c.borderSubtle,
  );

  // Visible focus ring (WCAG 2.4.7 / 2.4.11) on every button style.
  WidgetStateProperty<BorderSide?> focusSide(BorderSide? idle) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: c.focusRing, width: 2);
        }
        return idle;
      });

  const buttonShape = StadiumBorder();

  // Buttons rest raised and sink when pressed; disabled ones lie flat.
  final softElevation = WidgetStateProperty.resolveWith<double>((states) {
    if (states.contains(WidgetState.disabled)) return 0;
    if (states.contains(WidgetState.pressed)) return 0;
    if (states.contains(WidgetState.hovered)) return 6;
    return 3;
  });
  WidgetStateProperty<Color?> pressOverlay(Color on) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? on.withValues(alpha: 0.08)
            : states.contains(WidgetState.hovered)
            ? on.withValues(alpha: 0.04)
            : null,
      );
  const buttonMinSize = Size(64, RakiaSpacing.minTarget);
  const buttonPadding = EdgeInsets.symmetric(horizontal: RakiaSpacing.xl);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    fontFamily: RakiaType.sans,
    textTheme: text,
    extensions: [c],
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: NoSplash.splashFactory,
    focusColor: c.focusRing.withValues(alpha: 0.16),
    // An explicit, neutral track: the default (secondary container) falls
    // back to the brand colour, so an empty bar looked full.
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.action,
      linearTrackColor: c.surface3,
      linearMinHeight: 6,
      borderRadius: BorderRadius.circular(RakiaRadii.pill),
    ),
    dividerTheme: DividerThemeData(
      color: c.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: c.textSecondary, size: 22),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        // Disabled must look disabled: a muted surface, not the action
        // colour, so an unavailable action is never mistaken for one.
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? c.surface3 : c.action,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? c.textSecondary
              : c.onAction,
        ),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        side: focusSide(null),
        elevation: softElevation,
        shadowColor: WidgetStatePropertyAll(c.shadow),
        overlayColor: pressOverlay(c.onAction),
      ),
    ),
    // Secondary actions: raised pills made of the surface. A faint outline
    // keeps the button's edge visible where shadows are weak.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.pressed) ? c.surface3 : c.surface2,
        ),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        side: focusSide(BorderSide(color: c.borderSubtle)),
        elevation: softElevation,
        shadowColor: WidgetStatePropertyAll(c.shadow),
        overlayColor: pressOverlay(c.textPrimary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.brandText),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        shape: const WidgetStatePropertyAll(buttonShape),
        side: focusSide(null),
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface2,
      elevation: 6,
      shadowColor: c.shadow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.md),
      ),
    ),
    // Inputs are wells pressed into the surface; focus draws the accent.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface3,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RakiaSpacing.lg,
        vertical: RakiaSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
        borderSide: BorderSide(color: c.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
        borderSide: BorderSide(color: c.focusRing, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
        borderSide: BorderSide(color: c.statusAct),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
        borderSide: BorderSide(color: c.statusAct, width: 2),
      ),
      labelStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
      floatingLabelStyle: text.bodySmall?.copyWith(color: c.textSecondary),
      helperStyle: text.bodySmall,
      hintStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.onAction
            : c.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.action : c.surface3,
      ),
      trackOutlineColor: WidgetStatePropertyAll(c.borderControl),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface2),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(c.shadow),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface2,
      elevation: 12,
      shadowColor: c.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.textPrimary,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.canvas),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface1,
      elevation: 8,
      shadowColor: c.shadow,
      indicatorColor: c.surface3,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? c.brandText
              : c.textSecondary,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface1,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RakiaRadii.lg),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surface3,
        borderRadius: BorderRadius.circular(RakiaRadii.sm),
        border: Border.all(color: c.borderSubtle),
      ),
      textStyle: text.bodySmall?.copyWith(color: c.textPrimary),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        side: WidgetStatePropertyAll(BorderSide(color: c.borderSubtle)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.brandText
              : c.textPrimary,
        ),
        // The chosen segment is pressed in.
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.surface3 : c.surface2,
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Navigation is a frequent action: no page animation.
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.fuchsia: _NoTransitionsBuilder(),
      },
    ),
  );
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
