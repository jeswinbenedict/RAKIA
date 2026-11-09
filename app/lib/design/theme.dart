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
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        side: focusSide(BorderSide(color: c.borderControl)),
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
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RakiaRadii.md),
        side: BorderSide(color: c.borderSubtle),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface1,
      indicatorColor: c.brand,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? c.onBrand
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
        side: WidgetStatePropertyAll(BorderSide(color: c.borderControl)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.onBrand : c.textPrimary,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.brand : c.surface2,
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
