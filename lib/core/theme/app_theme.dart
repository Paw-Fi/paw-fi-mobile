import 'package:flutter/material.dart' hide ThemeData, Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

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

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0A0E1A); // --moneko-background (dark)
  static const Color darkForeground = Color(0xFFF1F5F9); // --moneko-foreground (dark)
  static const Color darkCardBg = Color(0xFF111827); // --card-bg (dark)
  static const Color darkInputBg = Color(0xFF1F2937); // --input-bg (dark)
  static const Color darkBorder = Color(0xFF374151); // --subtle-border (dark)
  static const Color darkMuted = Color(0xFFD7D7D7); // --muted-foreground-color (dark)

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
      primaryForeground: darkBackground,
      background: darkBackground,
      foreground: darkForeground,
      card: darkCardBg,
      border: darkBorder,
      muted: const Color(0xFF374151),
      mutedForeground: darkMuted,
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
