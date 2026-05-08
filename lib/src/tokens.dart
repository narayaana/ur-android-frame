import 'package:flutter/material.dart';

/// Color tokens for the ur-* design system, mirroring theme.css custom properties.
class UrColorScheme {
  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color muted;
  final Color tint;
  final Color tintHover;
  final Color accent;
  final Color accentBg;
  final Color accentBorder;
  final Color success;
  final Color warning;
  final Color danger;

  const UrColorScheme({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.tint,
    required this.tintHover,
    required this.accent,
    required this.accentBg,
    required this.accentBorder,
    required this.success,
    required this.warning,
    required this.danger,
  });

  const UrColorScheme.dark()
      : bg = const Color(0xFF0A0A12),
        surface = const Color(0xFF13131F),
        surfaceRaised = const Color(0xFF1C1C2E),
        border = const Color(0x1AE4E4F0),
        borderStrong = const Color(0x38E4E4F0),
        text = const Color(0xFFE4E4F0),
        muted = const Color(0x80E4E4F0),
        tint = const Color(0x0EFFFFFF),
        tintHover = const Color(0x1CFFFFFF),
        accent = const Color(0xFF4EA0F0),
        accentBg = const Color(0x403C8CDC),
        accentBorder = const Color(0x7364AAFF),
        success = const Color(0xFF3CC85A),
        warning = const Color(0xFFFF9800),
        danger = const Color(0xFFFF5050);

  const UrColorScheme.light()
      : bg = const Color(0xFFEEF0F7),
        surface = const Color(0xFFFFFFFF),
        surfaceRaised = const Color(0xFFF4F5FB),
        border = const Color(0x1A111120),
        borderStrong = const Color(0x33111120),
        text = const Color(0xFF141420),
        muted = const Color(0x80141420),
        tint = const Color(0x0A000000),
        tintHover = const Color(0x17000000),
        accent = const Color(0xFF1D6DC8),
        accentBg = const Color(0x1F1D6DC8),
        accentBorder = const Color(0x661D6DC8),
        success = const Color(0xFF1A8C36),
        warning = const Color(0xFFB56000),
        danger = const Color(0xFFCC1C1C);
}

class UrSpacing {
  const UrSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class UrRadii {
  const UrRadii._();
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
}

class UrFontSizes {
  const UrFontSizes._();
  static const double sm = 13.0;
  static const double base = 15.0;
  static const double lg = 17.0;
  static const double xl = 21.0;
}

ThemeData createUrThemeData(UrColorScheme c) {
  return ThemeData(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: c.bg.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
      primary: c.accent,
      onPrimary: c.text,
      secondary: c.accent,
      onSecondary: c.text,
      surface: c.surface,
      onSurface: c.text,
      surfaceTint: c.surface,
      error: c.danger,
      onError: Colors.white,
      outline: c.border,
      outlineVariant: c.borderStrong,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: c.text, fontSize: UrFontSizes.base),
      bodyMedium: TextStyle(color: c.muted, fontSize: UrFontSizes.sm),
      labelSmall: TextStyle(color: c.muted, fontSize: UrFontSizes.sm),
      titleMedium: TextStyle(color: c.text, fontSize: UrFontSizes.lg, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.tint,
      contentPadding: const EdgeInsets.symmetric(horizontal: UrSpacing.sm, vertical: UrSpacing.sm),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UrRadii.sm + 1),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UrRadii.sm + 1),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UrRadii.sm + 1),
        borderSide: BorderSide(color: c.accentBorder),
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UrRadii.md),
        side: BorderSide(color: c.border),
      ),
    ),
  );
}

ThemeMode themeModeFromString(String? s) {
  switch (s) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.system:
      return 'system';
  }
}
