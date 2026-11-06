import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_settings.dart';
import 'design/theme.dart';
import 'navigation/router.dart';

class RakiaApp extends StatefulWidget {
  const RakiaApp({super.key, this.initialLocation = '/mission', this.settings});

  final String initialLocation;
  final AppSettingsController? settings;

  @override
  State<RakiaApp> createState() => _RakiaAppState();
}

class _RakiaAppState extends State<RakiaApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  late final AppSettingsController _settings =
      widget.settings ?? AppSettingsController();
  final ThemeData _dark = buildRakiaTheme(Brightness.dark);
  final ThemeData _light = buildRakiaTheme(Brightness.light);

  @override
  void dispose() {
    _router.dispose();
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettings(
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
    );
  }
}
