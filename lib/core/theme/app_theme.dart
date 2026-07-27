import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme is intentionally built from explicit palette values rather than
/// ColorScheme-derived roles, so it renders identically across Flutter
/// versions (several ColorScheme roles have been renamed/deprecated over time).
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scaffold: AppColors.bgTertiary,
        surface: AppColors.bgPrimary,
        field: AppColors.bgSecondary,
        border: AppColors.borderTertiary,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
      );

  /// Closes Gap 9 from the requirements doc: the mockups exposed a theme
  /// setting but never defined a dark palette.
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scaffold: const Color(0xFF15171B),
        surface: const Color(0xFF1E2127),
        field: const Color(0xFF262A31),
        border: const Color(0xFF343941),
        textPrimary: const Color(0xFFECEDEE),
        textSecondary: const Color(0xFF9BA1A9),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color field,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.home,
      scaffoldBackgroundColor: scaffold,
      canvasColor: surface,
      dividerColor: border,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.home,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: TextTheme(
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(fontSize: 13.5, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary),
        labelSmall: TextStyle(fontSize: 11, color: textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.info, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.dangerBright),
        ),
      ),
      dividerTheme: DividerThemeData(space: 1, thickness: 0.5, color: border),
      listTileTheme: ListTileThemeData(iconColor: textSecondary),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Convenience surface colour lookups that respect the active brightness.
extension ThemeSurfaces on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardColor => isDark ? const Color(0xFF1E2127) : Colors.white;
  Color get fieldColor =>
      isDark ? const Color(0xFF262A31) : AppColors.bgSecondary;
  Color get hairline =>
      isDark ? const Color(0xFF343941) : AppColors.borderTertiary;
  Color get txtPrimary =>
      isDark ? const Color(0xFFECEDEE) : AppColors.textPrimary;
  Color get txtSecondary =>
      isDark ? const Color(0xFF9BA1A9) : AppColors.textSecondary;
  Color get txtTertiary =>
      isDark ? const Color(0xFF767C85) : AppColors.textTertiary;
}
