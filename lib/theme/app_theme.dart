import 'package:flutter/material.dart';
import '../main.dart';

class AppColors {
  AppColors._();

  static Color get accent => const Color(0xFF378ADD);
  static Color get accentMuted =>
      darkModeNotifier.value ? const Color(0xFF1A3350) : const Color(0xFFE6F1FB);
  static Color get surfacePage =>
      darkModeNotifier.value ? const Color(0xFF121212) : const Color(0xFFF7F6F3);
  static Color get surfaceCard =>
      darkModeNotifier.value ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color get border =>
      darkModeNotifier.value ? const Color(0xFF2C2C2C) : const Color(0xFFE3E1DA);
  static Color get textPrimary =>
      darkModeNotifier.value ? const Color(0xFFE8E8E8) : const Color(0xFF201F1D);
  static Color get textSecondary =>
      darkModeNotifier.value ? const Color(0xFFAAAAAA) : const Color(0xFF5F5E5A);
  static Color get textMuted =>
      darkModeNotifier.value ? const Color(0xFF777777) : const Color(0xFF888780);

  static const coverPurple   = Color(0xFF7F77DD);
  static const coverTeal     = Color(0xFF1D9E75);
  static const coverCoral    = Color(0xFFD85A30);
  static const coverPink     = Color(0xFFD4537E);
  static const coverGray     = Color(0xFF888780);
  static const coverAmber    = Color(0xFFBA7517);
  static const coverOrange   = Color(0xFFE8853A);
  static const coverBlue     = Color(0xFF4A90D9);
  static const coverGreen    = Color(0xFF3DAA6D);
  static const coverLime     = Color(0xFF7CB342);
  static const coverRose     = Color(0xFFC46A8C);
  static const coverIndigo   = Color(0xFF5C6BC0);
  static const coverCyan     = Color(0xFF26A69A);
  static const coverDarkRed  = Color(0xFF8B2232);
  static const coverGold     = Color(0xFFC49B2A);
}

ThemeData buildAppTheme({bool dark = false}) {
  if (dark) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFE8E8E8)),
      ),
    );
  }
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF7F6F3),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
    ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFF201F1D)),
    ),
  );
}
