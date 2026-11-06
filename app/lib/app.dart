import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_settings.dart';
import 'core/analytics_core.dart';
import 'design/theme.dart';
import 'mission/mission_controller.dart';
import 'navigation/router.dart';

class RakiaApp extends StatefulWidget {
  const RakiaApp({
    super.key,
    this.initialLocation = '/mission',
    this.settings,
    this.coreLoader,
    this.mission,
  });

  final String initialLocation;
  final AppSettingsController? settings;

  /// Loads librakia; defaults to the platform loader (native or WebAssembly).
  final AnalyticsCoreLoader? coreLoader;

  /// Mission state; created by the app when not supplied (tests supply it).
  final MissionController? mission;

  @override
  State<RakiaApp> createState() => _RakiaAppState();
}

class _RakiaAppState extends State<RakiaApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  late final AppSettingsController _settings =
      widget.settings ?? AppSettingsController();
  late final AnalyticsCoreController _core = AnalyticsCoreController(
    loader: widget.coreLoader,
  )..load();
  late final MissionController _mission = widget.mission ?? MissionController();
  final ThemeData _dark = buildRakiaTheme(Brightness.dark);
  final ThemeData _light = buildRakiaTheme(Brightness.light);

  @override
  void dispose() {
    _router.dispose();
    if (widget.settings == null) _settings.dispose();
    _core.dispose();
    if (widget.mission == null) _mission.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnalyticsCoreScope(
      controller: _core,
      child: MissionScope(
        controller: _mission,
        child: AppSettings(
          controller: _settings,
          child: ListenableBuilder(
            listenable: _settings,
            builder: (context, _) => MaterialApp.router(
              title: 'RAKIA',
              debugShowCheckedModeBanner: false,
              theme: _light,
              darkTheme: _dark,
              themeMode: _settings.themeMode,
              themeAnimationDuration: Duration.zero,
              routerConfig: _router,
            ),
          ),
        ),
      ),
    );
  }
}
