import 'package:flutter/material.dart';

class ThemePreset {
  const ThemePreset({required this.name, required this.primary, required this.secondary, required this.background});
  final String name;
  final Color primary;
  final Color secondary;
  final Color background;
}

class ThemeCatalog {
  static final List<ThemePreset> presets = List<ThemePreset>.generate(128, (index) {
    final hue = (index * 137.508) % 360;
    return ThemePreset(
      name: 'Theme \${index + 1}',
      primary: HSVColor.fromAHSV(1, hue, .78, .94).toColor(),
      secondary: HSVColor.fromAHSV(1, (hue + 155) % 360, .64, .86).toColor(),
      background: HSVColor.fromAHSV(1, hue, .04, .985).toColor(),
    );
  }, growable: false);

  static ThemeData build({required ThemePreset preset, required Brightness brightness, required bool amoled}) {
    final base = ColorScheme.fromSeed(seedColor: preset.primary, brightness: brightness);
    final scheme = base.copyWith(
      primary: preset.primary,
      secondary: preset.secondary,
      surface: amoled ? Colors.black : base.surface,
      surfaceContainer: amoled ? const Color(0xFF070707) : base.surfaceContainer,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: amoled ? Colors.black : preset.background,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
