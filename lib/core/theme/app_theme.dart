import 'package:flutter/material.dart' hide ThemeData, Colors;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

/// Theme mode provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, shadcnui.ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<shadcnui.ThemeMode> {
  ThemeModeNotifier() : super(shadcnui.ThemeMode.system) {
    _loadThemeMode();
  }

  static const _storageKey = 'moneko_theme_mode';

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    if (stored == null) {
      final platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final fallback = platformBrightness == Brightness.dark
          ? shadcnui.ThemeMode.dark
          : shadcnui.ThemeMode.light;
      state = fallback;
      return;
    }

    state = _themeModeFromString(stored);
  }

  Future<void> setThemeMode(shadcnui.ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _themeModeToString(mode));
  }

  shadcnui.ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'dark':
        return shadcnui.ThemeMode.dark;
      case 'light':
        return shadcnui.ThemeMode.light;
      case 'system':
        return shadcnui.ThemeMode.system;
      default:
        return shadcnui.ThemeMode.light;
    }
  }

  String _themeModeToString(shadcnui.ThemeMode mode) {
    switch (mode) {
      case shadcnui.ThemeMode.dark:
        return 'dark';
      case shadcnui.ThemeMode.light:
        return 'light';
      case shadcnui.ThemeMode.system:
        return 'system';
    }
  }
}

/// Moneko app theme configuration matching web's Tailwind design system
class AppTheme {
  // Moneko brand colors from web (app.css)
  static const Color monekoPrimary = Color(0xFF7458FF); // --moneko-primary
  static const Color monekoSecondary = Color(0xFF836DFF); // --moneko-secondary
  static const Color iconColor = Color(0xFFAA76FF); // --icon
  static const Color success = Color(0xFF16CDA2); // --success
  static const Color warning = Color(0xFFFFC219); // --warning
  static const Color danger = Color(0xFFFF6060); // --danger

  // Light theme colors
  static const Color lightBackground = Color(0xFFF9FAFB); // --moneko-background
  static const Color lightForeground = Color(0xFF1F2937); // --moneko-foreground
  static const Color lightCardBg = Color(0xFFFFFFFF); // --card-bg
  static const Color lightInputBg = Color(0xFFFFFFFF); // --input-bg
  static const Color lightBorder = Color(0xFFE5E7EB); // --subtle-border
  static const Color lightMuted = Color(0xFF6B7280); // --muted-foreground-color
  static const Color lightButtonText = Color(0xFFFFFFFF); // Button text color (white)

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0A0E1A); // --moneko-background (dark)
  static const Color darkForeground = Color(0xFFF1F5F9); // --moneko-foreground (dark) - bright for text
  static const Color darkCardBg = Color(0xFF111827); // --card-bg (dark)
  static const Color darkInputBg = Color(0xFF1F2937); // --input-bg (dark)
  static const Color darkBorder = Color(0xFF374151); // --subtle-border (dark)
  static const Color darkMuted = Color(0xFF374151); // Muted background (darker for inputs)
  static const Color darkMutedForeground = Color(0xFF9CA3AF); // Muted text (lighter gray)
  static const Color darkButtonText = Color(0xFFFFFFFF); // Button text color (white)

  /// Light theme matching web design
  static shadcnui.ThemeData lightTheme() {
    final colorScheme = shadcnui.ColorSchemes.lightZinc().copyWith(
      primary: monekoSeed,
      primaryForeground: const Color(0xFFFFFFFF), // Use Color directly instead of Colors.white
      background: lightBackground,
      foreground: lightForeground,
      card: lightCardBg,
      border: lightBorder,
      muted: const Color(0xFFF3F4F6),
      mutedForeground: lightMuted,
      destructive: danger,
    );

    return shadcnui.ThemeData(
      colorScheme: colorScheme,
      radius: 10,
      scaling: 1.0,
    );
  }

  /// Dark theme matching web design
  static shadcnui.ThemeData darkTheme() {
    final colorScheme = shadcnui.ColorSchemes.darkZinc().copyWith(
      primary: const Color(0xFF8B70FF), // Lighter purple for dark mode
      primaryForeground: const Color(0xFFFFFFFF), // White text on primary buttons
      background: darkBackground,
      foreground: darkForeground, // Bright white/light text for readability
      card: darkCardBg,
      border: darkBorder,
      muted: darkMuted, // Dark background for input fields
      mutedForeground: darkMutedForeground, // Light gray for muted text
      destructive: const Color(0xFFFF7A7A), // Lighter red for dark mode
    );

    return shadcnui.ThemeData(
      colorScheme: colorScheme,
      radius: 10,
      scaling: 1.0,
    );
  }

  // Helper to generate ColorScheme seed matching Moneko brand
  static Color get monekoSeed => monekoPrimary;
}

/// Extension on ColorScheme to add button text color and input styles
extension ColorSchemeExtension on shadcnui.ColorScheme {
  /// Returns button text color based on theme
  /// White for both light and dark themes on primary buttons
  Color get buttonText {
    return const Color(0xFFFFFFFF); // Always white for primary buttons
  }

  /// Returns the appropriate text color for input fields
  /// Ensures text is always visible in both light and dark modes
  Color get inputTextColor {
    return foreground; // Use foreground which is configured per theme
  }

  /// Returns the appropriate color for input icons (prefix/suffix)
  /// Ensures icons are always visible
  Color get inputIconColor {
    return foreground; // Use foreground for consistency
  }

  /// Returns the appropriate color for hint/placeholder text
  Color get hintTextColor {
    return mutedForeground; // Use muted foreground for secondary text
  }

  /// Returns a properly configured TextStyle for input fields
  TextStyle get inputTextStyle {
    return TextStyle(
      fontSize: 16,
      color: inputTextColor,
      fontWeight: FontWeight.w400,
    );
  }

  /// Returns a properly configured TextStyle for hint text
  TextStyle get hintTextStyle {
    return TextStyle(
      fontSize: 16,
      color: hintTextColor,
      fontWeight: FontWeight.w400,
    );
  }
}

