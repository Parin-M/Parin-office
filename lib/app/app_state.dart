import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_catalog.dart';

enum AppearanceMode { system, light, dark, amoled }

class AppState extends ChangeNotifier {
  Locale _locale = const Locale('en');
  AppearanceMode _mode = AppearanceMode.system;
  int _themeIndex = 12;
  bool _compactToolbar = false;
  bool _animations = true;
  bool _haptics = true;
  bool _autosave = true;
  bool _telemetry = false;

  Locale get locale => _locale;
  AppearanceMode get mode => _mode;
  int get themeIndex => _themeIndex;
  bool get compactToolbar => _compactToolbar;
  bool get animations => _animations;
  bool get haptics => _haptics;
  bool get autosave => _autosave;
  bool get telemetry => _telemetry;
  ThemePreset get preset => ThemeCatalog.presets[_themeIndex];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLocale = prefs.getString('locale');
    if (rawLocale != null) {
      final parts = rawLocale.split('-');
      _locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    }
    _mode = AppearanceMode.values.firstWhere(
      (item) => item.name == prefs.getString('appearanceMode'),
      orElse: () => AppearanceMode.system,
    );
    _themeIndex = (prefs.getInt('themeIndex') ?? 12).clamp(0, ThemeCatalog.presets.length - 1);
    _compactToolbar = prefs.getBool('compactToolbar') ?? false;
    _animations = prefs.getBool('animations') ?? true;
    _haptics = prefs.getBool('haptics') ?? true;
    _autosave = prefs.getBool('autosave') ?? true;
    _telemetry = prefs.getBool('telemetry') ?? false;
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    _locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', value.toLanguageTag());
  }

  Future<void> setMode(AppearanceMode value) async {
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearanceMode', value.name);
  }

  Future<void> setTheme(int value) async {
    _themeIndex = value.clamp(0, ThemeCatalog.presets.length - 1);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeIndex', _themeIndex);
  }

  Future<void> setFlag(String key, bool value) async {
    switch (key) {
      case 'compactToolbar': _compactToolbar = value;
      case 'animations': _animations = value;
      case 'haptics': _haptics = value;
      case 'autosave': _autosave = value;
      case 'telemetry': _telemetry = value;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Brightness brightness(BuildContext context) {
    switch (_mode) {
      case AppearanceMode.system:
        return MediaQuery.platformBrightnessOf(context);
      case AppearanceMode.light:
        return Brightness.light;
      case AppearanceMode.dark:
      case AppearanceMode.amoled:
        return Brightness.dark;
    }
  }

  bool get amoled => _mode == AppearanceMode.amoled;
}
