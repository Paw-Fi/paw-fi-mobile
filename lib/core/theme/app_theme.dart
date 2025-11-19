import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider based on Flutter's [ThemeMode]
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  static const _storageKey = 'moneko_theme_mode';

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    if (stored == null) {
      final platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      state = platformBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
      return;
    }

    state = _themeModeFromString(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _themeModeToString(mode));
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// Additional semantic colors mapped onto Material [ColorScheme]
extension AppColorScheme on ColorScheme {
  /// Background for cards/surfaces
  Color get card => brightness == Brightness.dark ? AppTheme.darkBackground : AppTheme.lightBackground;

  /// Subtle border color
  Color get border => outlineVariant;

  /// Muted background surface
  Color get muted => brightness == Brightness.dark
      ? AppTheme.darkMuted
      : const Color(0xFFF3F4F6);

  /// Muted text color
  Color get mutedForeground => brightness == Brightness.dark
      ? AppTheme.darkMutedForeground
      : AppTheme.lightMuted;

  /// Primary foreground color (text/icon on primary)
  Color get primaryForeground => onPrimary;

  /// Secondary foreground color (text/icon on secondary)
  Color get secondaryForeground => onSecondary;

  /// Foreground text color for primary content
  Color get foreground => brightness == Brightness.dark
      ? AppTheme.darkForeground
      : AppTheme.lightForeground;

  /// Destructive color (mirrors shadcn destructive semantics)
  Color get destructive => error;
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
  static const Color info = monekoPrimary; // brand primary for neutral/info

  // Light theme colors
  static const Color lightBackground = Color(0xFFFFFFFF); // --moneko-background (light, pure white)
  static const Color lightForeground = Color(0xFF1F2937); // --moneko-foreground
  static const Color lightCardBg = Color(0xFFFFFFFF); // --card-bg
  static const Color lightInputBg = Color(0xFFFFFFFF); // --input-bg
  static const Color lightBorder = Color(0xFFE5E7EB); // --subtle-border
  static const Color lightMuted = Color(0xFF6B7280); // --muted-foreground-color
  static const Color lightButtonText = Color(0xFFFFFFFF); // Button text color (white)

  // Dark theme colors
  static const Color darkBackground = Color(0xFF000000); // --moneko-background (dark, pure black)
  static const Color darkForeground = Color(0xFFF1F5F9); // --moneko-foreground (dark) - bright for text
  static const Color darkCardBg = Color(0xFF111827); // --card-bg (dark)
  static const Color darkInputBg = Color(0xFF1F2937); // --input-bg (dark)
  static const Color darkBorder = Color(0xFF374151); // --subtle-border (dark)
  static const Color darkMuted = Color(0xFF374151); // Muted background (darker for inputs)
  static const Color darkMutedForeground = Color(0xFF9CA3AF); // Muted text (lighter gray)
  static const Color darkButtonText = Color(0xFFFFFFFF); // Button text color (white)

  /// Light theme matching web design, expressed as Material [ThemeData]
  static ThemeData lightTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: monekoSeed,
      brightness: Brightness.light,
    );

    final scheme = base.copyWith(
      primary: monekoPrimary,
      onPrimary: lightButtonText,
      secondary: monekoSecondary,
      background: lightBackground,
      surface: lightCardBg,
      onBackground: lightForeground,
      onSurface: lightForeground,
      error: danger,
      onError: lightButtonText,
      outline: lightBorder,
      outlineVariant: lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      snackBarTheme: AppSnackBarStyles.build(scheme, isDark: false),
    );
  }

  /// Dark theme matching web design, expressed as Material [ThemeData]
  static ThemeData darkTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: monekoSeed,
      brightness: Brightness.dark,
    );

    final scheme = base.copyWith(
      primary: const Color(0xFF8B70FF),
      onPrimary: darkButtonText,
      secondary: monekoSecondary,
      background: darkBackground,
      surface: darkCardBg,
      onBackground: darkForeground,
      onSurface: darkForeground,
      error: const Color(0xFFFF7A7A),
      onError: darkButtonText,
      outline: darkBorder,
      outlineVariant: darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      snackBarTheme: AppSnackBarStyles.build(scheme, isDark: true),
    );
  }

  // Helper to generate ColorScheme seed matching Moneko brand
  static Color get monekoSeed => monekoPrimary;
}

/// Extension on Material [ColorScheme] to add button text color and input styles
extension ColorSchemeExtension on ColorScheme {
  /// Returns button text color based on theme
  /// White for both light and dark themes on primary buttons
  Color get buttonText {
    return const Color(0xFFFFFFFF); // Always white for primary buttons
  }

  /// Returns the appropriate text color for input fields
  /// Ensures text is always visible in both light and dark modes
  Color get inputTextColor {
    return onSurface; // Use onSurface which is configured per theme
  }

  /// Returns the appropriate color for input icons (prefix/suffix)
  /// Ensures icons are always visible
  Color get inputIconColor {
    return onSurface; // Use onSurface for consistency
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
    );
  }
}

/// Status-driven primitives for surfaces (toasts/snackbars/etc.)
class AppSurface {
  const AppSurface._();

  /// Compute a tinted surface for a status on top of the neutral `card` color.
  /// This produces elegant, subtle backgrounds that work for light/dark.
  static Color tintedBackground({
    required ColorScheme scheme,
    required Color base,
    required bool isDark,
  }) {
    // Light: very light tint, Dark: slightly stronger tint for contrast.
    final t = isDark ? 0.16 : 0.08;
    return Color.lerp(scheme.card, base, t) ?? scheme.surface;
  }

  /// Subtle hairline border that harmonizes with the status hue.
  static Color tintedBorder({
    required ColorScheme scheme,
    required Color base,
    required bool isDark,
  }) {
    // Blend the base with the neutral border for a refined outline.
    final t = isDark ? 0.55 : 0.45;
    return Color.lerp(scheme.border, base, t) ?? scheme.outline;
  }

  /// Action/accent color for links and buttons.
  static Color accent(Color base) => base;

  /// Derive a status base color by type.
  static Color statusBase(AppSurfaceStatus status) {
    switch (status) {
      case AppSurfaceStatus.info:
        return AppTheme.info;
      case AppSurfaceStatus.success:
        return AppTheme.success;
      case AppSurfaceStatus.warning:
        return AppTheme.warning;
      case AppSurfaceStatus.error:
        return AppTheme.danger;
    }
  }
}

enum AppSurfaceStatus { info, success, warning, error }

/// Build a Material SnackBarTheme that mirrors our shadcn palette and Apple-like
/// sleek floating cards. Use this from the Material theme wrapper.
class AppSnackBarStyles {
  const AppSnackBarStyles._();

  static SnackBarThemeData build(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    final bg = AppSurface.tintedBackground(
      scheme: scheme,
      base: AppTheme.info, // neutral/info tint as the default surface
      isDark: isDark,
    );
    final border = AppSurface.tintedBorder(
      scheme: scheme,
      base: AppTheme.info,
      isDark: isDark,
    );

    return SnackBarThemeData(
      backgroundColor: bg,
      contentTextStyle: TextStyle(
        color: scheme.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
      actionTextColor: AppSurface.accent(AppTheme.info),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border, width: 1),
      ),
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      showCloseIcon: false,
      disabledActionTextColor: scheme.mutedForeground,
    );
  }
}
