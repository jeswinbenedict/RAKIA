import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'account/account_api.dart';
import 'account/account_controller.dart';
import 'account/firebase_auth_client.dart';
import 'app_settings.dart';
import 'components/astronaut/pointer_tracker.dart';
import 'config/build_config.dart';
import 'core/analytics_core.dart';
import 'design/theme.dart';
import 'environment/space_weather.dart';
import 'mission/mission_controller.dart';
import 'navigation/router.dart';
import 'record/record_controller.dart';
import 'storage/store_controller.dart';
import 'sync/sync_api.dart';
import 'sync/sync_controller.dart';
import 'wellbeing/wellbeing_controller.dart';

class RakiaApp extends StatefulWidget {
  const RakiaApp({
    super.key,
    this.initialLocation = '/mission',
    this.settings,
    this.coreLoader,
    this.mission,
    this.storeOpener,
    this.spaceWeather,
    this.account,
    this.syncApi,
  });

  final String initialLocation;
  final AppSettingsController? settings;

  /// Loads librakia; defaults to the platform loader (native or WebAssembly).
  final AnalyticsCoreLoader? coreLoader;

  /// Mission state; created by the app when not supplied (tests supply it).
  final MissionController? mission;

  /// Opens the on-device store; defaults to the platform store (a SQLite file
  /// natively, SQLite WebAssembly in a browser).
  final LocalStoreOpener? storeOpener;

  /// Live space weather; by default from the API named at build time
  /// ([kApiUrl]), or not connected when the build names none.
  final SpaceWeatherController? spaceWeather;

  /// Sign-in; by default from the build's Firebase key and API URL, or
  /// unavailable when the build names neither.
  final AccountController? account;

  /// Uploads backups; by default to the build's API (tests supply one).
  final SyncApi? syncApi;

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
  late final StoreController _store = StoreController(
    opener: widget.storeOpener,
  )..open();
  late final SpaceWeatherController _spaceWeather =
      widget.spaceWeather ??
            SpaceWeatherController(
              kApiUrl.isEmpty ? null : SpaceWeatherClient(baseUrl: kApiUrl),
            )
        ..start();
  late final AccountController _account =
      widget.account ??
      AccountController(
        auth: kFirebaseApiKey.isEmpty || kApiUrl.isEmpty
            ? null
            : FirebaseAuthClient(
                apiKey: kFirebaseApiKey,
                emulatorHost: kFirebaseAuthEmulatorHost,
              ),
        api: kFirebaseApiKey.isEmpty || kApiUrl.isEmpty
            ? null
            : AccountApi(baseUrl: kApiUrl),
      );
  bool _accountAttached = false;
  late final SyncController _sync = SyncController(
    api: widget.syncApi ?? (kApiUrl.isEmpty ? null : SyncApi(baseUrl: kApiUrl)),
    account: _account,
    changes: _record,
  );
  final WellbeingController _wellbeing = WellbeingController();
  final RecordController _record = RecordController();
  bool _recordAttached = false;
  bool _settingsAttached = false;
  bool _wellbeingAttached = false;
  bool _missionAttached = false;
  final ThemeData _dark = buildRakiaTheme(Brightness.dark);
  final ThemeData _light = buildRakiaTheme(Brightness.light);

  @override
  void initState() {
    super.initState();
    _core.addListener(_attachStore);
    _store.addListener(_attachStore);
  }

  /// Once both the store and the analytics core are ready, preferences and
  /// the saved mission are restored from the store.
  void _attachStore() {
    // The health record needs a database even when persistent storage is
    // unavailable; it then uses the session's in-memory store.
    final recordStore = _store.store ?? _store.sessionStore;
    if (recordStore != null && !_recordAttached) {
      if (_core.state case AnalyticsCoreReady(:final core)) {
        _recordAttached = true;
        unawaited(_record.attach(recordStore, core));
      }
    }
    // The sign-in is kept in the store when it is persistent; otherwise it
    // lasts for this session.
    if (!_accountAttached && _store.state is! StoreOpening) {
      _accountAttached = true;
      unawaited(_account.attach(_store.store));
      unawaited(_sync.attach(_store.store));
    }
    final store = _store.store;
    if (store == null) return;
    // Preferences do not need the analytics core.
    if (!_settingsAttached) {
      _settingsAttached = true;
      unawaited(_settings.attach(store));
    }
    if (!_wellbeingAttached) {
      _wellbeingAttached = true;
      unawaited(_wellbeing.attach(store));
    }
    if (_core.state case AnalyticsCoreReady(:final core)) {
      if (!_missionAttached) {
        _missionAttached = true;
        unawaited(_mission.attach(store, core));
      }
    }
  }

  @override
  void dispose() {
    _core.removeListener(_attachStore);
    _store.removeListener(_attachStore);
    _router.dispose();
    if (widget.settings == null) _settings.dispose();
    _core.dispose();
    _store.dispose();
    if (widget.mission == null) _mission.dispose();
    _wellbeing.dispose();
    _record.dispose();
    if (widget.spaceWeather == null) _spaceWeather.dispose();
    _sync.dispose();
    if (widget.account == null) _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnalyticsCoreScope(
      controller: _core,
      child: StoreScope(
        controller: _store,
        child: MissionScope(
          controller: _mission,
          child: WellbeingScope(
            controller: _wellbeing,
            child: RecordScope(
              controller: _record,
              child: SpaceWeatherScope(
                controller: _spaceWeather,
                child: AccountScope(
                  controller: _account,
                  child: SyncScope(
                    controller: _sync,
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
                          builder: (context, child) =>
                              PointerTracker(child: child ?? const SizedBox()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
