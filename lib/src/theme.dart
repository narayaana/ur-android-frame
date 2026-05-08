import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tokens.dart';

ThemeMode detectSystemThemeMode(BuildContext context) {
  return MediaQuery.of(context).platformBrightness == Brightness.dark
      ? ThemeMode.dark
      : ThemeMode.light;
}

Future<ThemeMode> loadStoredTheme() async {
  final prefs = await SharedPreferences.getInstance();
  return themeModeFromString(prefs.getString('ur_theme'));
}

Future<void> clearThemeOverride() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('ur_theme');
}

Future<void> saveTheme(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('ur_theme', themeModeToString(mode));
}

/// Dark/light toggle button.
///
/// [themeMode] is a ValueNotifier<ThemeMode> owned by the parent.
/// The parent is responsible for loading the initial value from SharedPreferences
/// and persisting changes.
class ThemeToggle extends StatelessWidget {
  final ValueNotifier<ThemeMode> themeMode;

  const ThemeToggle({super.key, required this.themeMode});

  void _toggle() {
    final next = themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = next;
    saveTheme(next);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          icon: Text(isDark ? '\u{1F319}' : '\u{2600}\u{FE0F}',
              style: const TextStyle(fontSize: 18)),
          tooltip: isDark ? 'Switch to light' : 'Switch to dark',
          onPressed: _toggle,
          splashRadius: 16,
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(UrSpacing.xs),
          ),
        );
      },
    );
  }
}
