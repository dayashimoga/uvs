import 'package:flutter/material.dart';

class StudioTheme {
  // Obsidian Dark Palette
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF21262D);
  static const Color surfaceHighlight = Color(0xFF30363D);
  static const Color border = Color(0xFF30363D);

  // Accents
  static const Color accentCyan = Color(0xFF00D2FF);
  static const Color accentBlue = Color(0xFF3A7BD5);
  static const Color accentEmerald = Color(0xFF00E676);
  static const Color accentAmber = Color(0xFFFFB74D);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentPurple = Color(0xFF9C27B0);

  // Text
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accentCyan,
        secondary: accentBlue,
        tertiary: accentEmerald,
        error: accentRed,
        onSurface: textPrimary,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accentCyan,
        thumbColor: accentCyan,
        inactiveTrackColor: surfaceHighlight,
        trackHeight: 3.0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
    );
  }
}
