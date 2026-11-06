import 'dart:async';

import 'package:flutter/material.dart';

import 'storage/local_store.dart';

/// User preferences. Kept in memory until a store is attached, then loaded
/// from and saved to it.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController([this._themeMode = ThemeMode.system]);

  static const String themeModeKey = 'theme_mode';

  ThemeMode _themeMode;
  LocalStore? _store;
  bool _changedSinceAttach = false;

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    _changedSinceAttach = true;
    notifyListeners();
    final store = _store;
    if (store != null) unawaited(_save(store));
  }

  /// Applies the preferences saved in [store] and saves later changes to it.
  /// A choice made while loading wins over the saved one.
  Future<void> attach(LocalStore store) async {
    _store = store;
    _changedSinceAttach = false;
    String? saved;
    try {
      saved = await store.setting(themeModeKey);
    } on Object catch (e) {
      debugPrint('RAKIA: could not read saved preferences: $e');
    }
    if (_changedSinceAttach) {
      await _save(store);
      return;
    }
    final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
    if (mode != null && mode != _themeMode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  Future<void> _save(LocalStore store) async {
    try {
      await store.setSetting(themeModeKey, _themeMode.name);
    } on Object catch (e) {
      // A preference that fails to save is not worth interrupting the user
      // for; it stays in effect for this session.
      debugPrint('RAKIA: could not save preferences: $e');
    }
  }
}

class AppSettings extends InheritedNotifier<AppSettingsController> {
  const AppSettings({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSettings>();
    assert(scope != null, 'AppSettings is missing from the widget tree');
    return scope!.notifier!;
  }
}
