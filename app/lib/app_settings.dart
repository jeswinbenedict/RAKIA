import 'package:flutter/material.dart';

/// In-memory user preferences. Persistence arrives with the local store.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController([this._themeMode = ThemeMode.system]);

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
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
