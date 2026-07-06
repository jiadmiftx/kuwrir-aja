import 'package:flutter/material.dart';
import 'kuwrir_colors.dart';

/// KUWRIR unified theme for all Flutter apps
class KuwrirTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.light(
        primary: KuwrirColors.primary,
        onPrimary: Colors.white,
        secondary: KuwrirColors.secondary,
        onSecondary: Colors.white,
        tertiary: KuwrirColors.accent,
        surface: KuwrirColors.surface,
        onSurface: KuwrirColors.textPrimary,
        error: KuwrirColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: KuwrirColors.background,
      // Flush with the scaffold (not a separate surface), left-aligned bold
      // title, no shadow even on scroll — matches the flat "product app"
      // header style already used for Home/Dashboard across both apps,
      // instead of the boxy centered Material default.
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: KuwrirColors.background,
        foregroundColor: KuwrirColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: KuwrirColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        iconTheme: IconThemeData(color: KuwrirColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KuwrirColors.border, width: 1),
        ),
        color: KuwrirColors.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KuwrirColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KuwrirColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: KuwrirColors.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KuwrirColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KuwrirColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KuwrirColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KuwrirColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: KuwrirColors.textHint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: KuwrirColors.surface,
        selectedItemColor: KuwrirColors.primary,
        unselectedItemColor: KuwrirColors.textSecondary,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: KuwrirColors.divider,
        thickness: 1,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.dark(
        primary: KuwrirColors.primaryLight,
        onPrimary: Colors.white,
        secondary: KuwrirColors.secondaryLight,
        tertiary: KuwrirColors.accentLight,
        surface: KuwrirColors.darkSurface,
        onSurface: Colors.white,
        error: KuwrirColors.error,
      ),
      scaffoldBackgroundColor: KuwrirColors.darkBackground,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KuwrirColors.darkBorder, width: 1),
        ),
        color: KuwrirColors.darkSurface,
      ),
    );
  }
}
