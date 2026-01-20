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
  Color get card => brightness == Brightness.dark
      ? AppTheme.darkCardBg
      : AppTheme.lightCardBg;

  Color get appBackground => brightness == Brightness.dark
      ? AppTheme.darkBackground
      : AppTheme.lightBackground;

  /// Bottom sheet and modal surface
  Color get sheetBackground => brightness == Brightness.dark
      ? AppTheme.darkSheetBg
      : AppTheme.lightCardBg;

  /// Subtle border color
  Color get border => outlineVariant;

  /// Stronger border for sheets and drag handles
  Color get sheetBorder => outline;

  /// NEW: Distinct border for Dark Mode cards (Apple Style/Modern Mobile)
  /// Use this on Container(decoration: BoxDecoration(border: Border.all(color: scheme.surfaceBorder)))
  Color get surfaceBorder => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.transparent;

  /// REVISED: Border for inputs and selection tiles.
  /// Increased opacity in light mode to ensure inputs are seen if they share bg color with card.
  Color get controlBorder => brightness == Brightness.dark
      ? outline.withValues(alpha: 0.5)
      : outlineVariant.withValues(alpha: 0.5);

  /// Background for input fields
  Color get inputBackground => brightness == Brightness.dark
      ? AppTheme.darkInputBg
      : AppTheme.lightInputBg;

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

  /// Foreground for inactive tab text
  Color get tabInactiveForeground => brightness == Brightness.dark
      ? AppTheme.darkTabInactiveForeground
      : AppTheme.lightForeground;

  /// Segmented control thumb background
  Color get tabThumb => brightness == Brightness.dark ? foreground : card;

  /// Segmented control selected text
  Color get tabSelectedForeground =>
      brightness == Brightness.dark ? AppTheme.lightForeground : foreground;

  /// Segmented control unselected text
  Color get tabUnselectedForeground =>
      brightness == Brightness.dark ? tabInactiveForeground : mutedForeground;

  /// Tab bar default text color (non-iOS)
  Color get tabDefaultForeground =>
      brightness == Brightness.dark ? tabInactiveForeground : foreground;

  Color get destructive =>
      brightness == Brightness.dark ? AppTheme.darkDanger : AppTheme.danger;

  /// Error surface for banners/cards with subtle tinting.
  Color get errorSurface => AppSurface.tintedBackground(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.error),
        isDark: brightness == Brightness.dark,
      );

  /// Error border for subtle outlines.
  Color get errorBorder => AppSurface.tintedBorder(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.error),
        isDark: brightness == Brightness.dark,
      );

  /// Error accent color for icons and emphasis.
  Color get errorAccent => AppSurface.statusBase(AppSurfaceStatus.error);

  /// Success surface for banners/cards with subtle tinting.
  Color get successSurface => AppSurface.tintedBackground(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.success),
        isDark: brightness == Brightness.dark,
      );

  /// Success border for subtle outlines.
  Color get successBorder => AppSurface.tintedBorder(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.success),
        isDark: brightness == Brightness.dark,
      );

  /// Info surface for banners/cards with subtle tinting.
  Color get infoSurface => AppSurface.tintedBackground(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.info),
        isDark: brightness == Brightness.dark,
      );

  /// Info border for subtle outlines.
  Color get infoBorder => AppSurface.tintedBorder(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.info),
        isDark: brightness == Brightness.dark,
      );

  /// Warning surface for banners/cards with subtle tinting.
  Color get warningSurface => AppSurface.tintedBackground(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.warning),
        isDark: brightness == Brightness.dark,
      );

  /// Warning border for subtle outlines.
  Color get warningBorder => AppSurface.tintedBorder(
        scheme: this,
        base: AppSurface.statusBase(AppSurfaceStatus.warning),
        isDark: brightness == Brightness.dark,
      );

  /// Success color
  Color get success =>
      brightness == Brightness.dark ? AppTheme.darkSuccess : AppTheme.success;

  /// Warning color
  Color get warning =>
      brightness == Brightness.dark ? AppTheme.darkWarning : AppTheme.warning;

  /// Info color
  Color get info =>
      brightness == Brightness.dark ? AppTheme.darkInfo : AppTheme.info;

  Color get drawerBackground =>
      brightness == Brightness.dark ? AppTheme.darkBackground : Colors.white;

  Color get selectedStateBackground => brightness == Brightness.dark
      ? AppTheme.darkSelectedStateBackground
      : AppTheme.lightSelectedStateBackground;

  /// Surface color for cards (matching Apple-style cards)
  Color get cardSurface =>
      brightness == Brightness.dark ? AppTheme.darkCardBg : Colors.white;

  /// Spotlight card shadow
  Color get spotlightShadow => shadow.withValues(
        alpha: brightness == Brightness.dark ? 0.3 : 0.15,
      );

  /// Background color for charts
  Color get chartBackground => brightness == Brightness.dark
      ? AppTheme.darkChartBackground
      : AppTheme.lightChartBackground;

  /// Base color for skeleton loaders
  Color get skeletonBase => brightness == Brightness.dark
      ? AppTheme.darkSkeletonBase
      : AppTheme.lightSkeletonBase;

  /// Highlight color for skeleton loaders
  Color get skeletonHighlight => brightness == Brightness.dark
      ? AppTheme.darkSkeletonHighlight
      : AppTheme.lightSkeletonHighlight;

  /// Pockets: Add tile surface
  Color get pocketAddSurface => brightness == Brightness.dark
      ? AppTheme.darkCardBg
      : AppTheme.lightPocketAddSurface;

  /// Pockets: Add tile border
  Color get pocketAddBorder => brightness == Brightness.dark
      ? AppTheme.darkBorderSubtle
      : AppTheme.lightBorder.withValues(alpha: 0.15);

  /// Pockets: Add tile label
  Color get pocketAddText => brightness == Brightness.dark
      ? AppTheme.darkForeground
      : AppTheme.lightForeground;

  /// Pockets: Card surface
  Color get pocketCardSurface => brightness == Brightness.dark
      ? AppTheme.darkCardBg
      : AppTheme.lightCardBg;

  /// Pockets: Card border
  Color get pocketCardBorder => brightness == Brightness.dark
      ? AppTheme.darkBorderSubtle
      : AppTheme.lightBorder.withValues(alpha: 0.4);

  /// Pockets: Glass overlay surface (icons/labels)
  Color get pocketGlassSurface => brightness == Brightness.dark
      ? AppTheme.darkCardBg.withValues(alpha: 0.9)
      : Colors.white.withValues(alpha: 0.9);

  /// Pockets: Softer glass overlay surface
  Color get pocketGlassSurfaceSoft => brightness == Brightness.dark
      ? AppTheme.darkCardBg.withValues(alpha: 0.88)
      : Colors.white.withValues(alpha: 0.85);

  /// Pockets: Glass shadow
  Color get pocketGlassShadow => shadow.withValues(
        alpha: brightness == Brightness.dark ? 0.25 : 0.05,
      );

  /// Pockets: Icon chip shadow
  Color get pocketIconShadow => shadow.withValues(
        alpha: brightness == Brightness.dark ? 0.3 : 0.05,
      );

  /// Pockets: Progress track
  Color get pocketProgressTrack => brightness == Brightness.dark
      ? foreground.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.1);

  /// Pockets: List tile fill surface based on pocket color
  Color pocketTileFill(Color baseColor) => brightness == Brightness.dark
      ? baseColor.withValues(alpha: 0.2)
      : baseColor.withValues(alpha: 0.12);

  /// Pockets: List tile icon chip surface
  Color get pocketTileIconSurface => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.white.withValues(alpha: 0.9);

  /// Pockets: List tile content surface
  Color get pocketTileContentSurface => brightness == Brightness.dark
      ? AppTheme.darkCardBg.withValues(alpha: 0.9)
      : Colors.white.withValues(alpha: 0.9);

  /// Pockets: List tile border
  Color get pocketTileBorder => brightness == Brightness.dark
      ? AppTheme.darkBorderSubtle
      : AppTheme.lightBorder.withValues(alpha: 0.4);

  /// Pockets: Title/subtitle colors
  Color get pocketTitle => foreground;
  Color get pocketSubtitle => mutedForeground;

  /// Pockets: Header shadow
  Color get pocketHeaderShadow => shadow.withValues(
        alpha: brightness == Brightness.dark ? 0.12 : 0.05,
      );

  /// Pockets: Header border
  Color get pocketHeaderBorder => outline.withValues(
        alpha: brightness == Brightness.dark ? 0.12 : 0.05,
      );

  /// Pockets: Uncategorized banner surface
  Color get pocketUncategorizedSurface => brightness == Brightness.dark
      ? AppTheme.darkUncategorizedBanner
      : AppTheme.lightUncategorizedBanner;

  /// Pockets: Uncategorized banner accent
  Color get pocketUncategorizedAccent => brightness == Brightness.dark
      ? AppTheme.darkUncategorizedAccent
      : AppTheme.lightUncategorizedAccent;

  /// Pockets: Uncategorized banner border
  Color get pocketUncategorizedBorder => pocketUncategorizedAccent.withValues(
        alpha: brightness == Brightness.dark ? 0.2 : 0.1,
      );

  /// Pockets: Uncategorized banner amount
  Color get pocketUncategorizedAmount => brightness == Brightness.dark
      ? AppTheme.darkUncategorizedAmount
      : AppTheme.lightUncategorizedAmount;

  /// Pockets: Uncategorized icon background
  Color get pocketUncategorizedIconBg => pocketUncategorizedAccent.withValues(
        alpha: brightness == Brightness.dark ? 0.18 : 0.12,
      );

  /// Households: role colors
  Color get householdOwner => AppTheme.householdOwner;
  Color get householdAdmin => AppTheme.householdAdmin;
  Color get householdMember => AppTheme.householdMember;

  /// Home: standard card surface
  Color get homeCardSurface => cardSurface;

  /// Home: standard card border
  Color get homeCardBorder => outline.withValues(
        alpha: brightness == Brightness.dark ? 0.12 : 0.05,
      );

  /// Home: standard card shadow
  Color get homeCardShadow => shadow.withValues(
        alpha: brightness == Brightness.dark ? 0.12 : 0.05,
      );

  /// Home: search field background
  Color get homeSearchFieldBackground => brightness == Brightness.dark
      ? AppTheme.darkInputBg
      : AppTheme.lightInputBg;

  /// Home: split sheet background
  Color get homeSplitSheetBackground => brightness == Brightness.dark
      ? AppTheme.darkCardBg
      : AppTheme.lightSplitSheetBg;

  /// Apple-style grouped background for transaction sheets
  Color get appleGroupedBackground => brightness == Brightness.dark
      ? AppTheme.iosSystemGroupedBackgroundDark
      : AppTheme.iosSystemGroupedBackground;
}

/// Moneko app theme configuration matching web's Tailwind design system
class AppTheme {
  // Moneko brand colors from web (app.css)
  static const Color monekoPrimary = Color(0xFF7458FF); // --moneko-primary
  static const Color monekoSecondary = Color(0xFF836DFF); // --moneko-secondary
  static const Color iconColor = Color(0xFFAA76FF); // --icon

  // BRANDED SEMANTIC COLORS (Light Mode)
  static const Color success = Color(0xFF16CDA2); // --success (Moneko Mint)
  static const Color warning = Color(0xFFFFC219); // --warning (Moneko Amber)
  static const Color danger = Color(0xFFFF6060); // --danger (Moneko Red)
  static const Color info = monekoPrimary;

  static const Color darkPrimary =
      Color(0xFF8B70FF); // Slightly lighter purple for dark mode

  // Household role accents
  static const Color householdOwner = Color(0xFF7C5CFF);
  static const Color householdAdmin = Color(0xFF4C8DFF);
  static const Color householdMember = Color(0xFF34C759);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF9FAFB); // --moneko-background
  static const Color lightForeground = Color(0xFF1F2937); // --moneko-foreground
  static const Color lightCardBg = Color(0xFFFFFFFF); // --card-bg

  // REVISED: Light input background is now distinct from card background (Affordance)
  static const Color lightInputBg = Color(0xFFF9FAFB); // Gray-50

  static const Color lightBorder = Color(0xFFE5E7EB); // --subtle-border

  // Apple-style system grouped background
  static const Color iosSystemGroupedBackground = Color(0xFFF2F2F6);
  static const Color iosSystemGroupedBackgroundDark = Color(0xFF1C1C1E);

  // Apple-style input backgrounds
  static const Color iosInputLight = Color(0xFFFFFFFF);
  static const Color iosInputDark = Color(0xFF2C2C2E);

  // REVISED: Darker muted text for WCAG compliance (Gray-600)
  static const Color lightMuted = Color(0xFF4B5563);

  static const Color lightButtonText = Color(0xFFFFFFFF);
  static const Color lightSelectedStateBackground =
      Color(0xFFF8F6FE); // --selected-state-background

  // Dark theme colors - refined for depth and legibility
  static const Color darkBackground = Color(0xFF0B0B0E); // Deep black base
  static const Color darkForeground = Color(0xFFF2F3F7); // High-contrast text
  static const Color darkCardBg = Color(0xFF17181D); // Card surface
  static const Color darkSheetBg = Color(0xFF14151A); // Bottom sheets
  static const Color darkInputBg = Color(0xFF1E1F25); // Input surface
  static const Color darkBorder = Color(0xFF40424A); // Primary outline
  static const Color darkBorderSubtle = Color(0xFF2B2D34); // Subtle outline
  static const Color darkMuted = Color(0xFF1B1C22); // Muted surface
  static const Color darkMutedForeground = Color(0xFFA2A4AE); // Muted text
  static const Color darkButtonText = Color(0xFFFFFFFF);
  static const Color darkTabInactiveForeground =
      Color(0xFFFFFFFF); // High-contrast tab text

  // Pocket chart palette (shared between light/dark)
  static const List<Color> pocketChartPalette = [
    Color(0xFF4ADE80), // Green
    Color(0xFFF87171), // Red
    Color(0xFF60A5FA), // Blue
    Color(0xFFFBBF24), // Yellow
    Color(0xFFA78BFA), // Purple
    Color(0xFFFB923C), // Orange
  ];
  static const Color pocketDefaultBlue = Color(0xFF007AFF);
  static const List<Color> pocketPresetColors = [
    Color(0xFFF87171),
    Color(0xFFF472B6),
    Color(0xFFA855F7),
    Color(0xFF7C3AED),
    Color(0xFF6366F1),
    Color(0xFF3B82F6),
    Color(0xFF38BDF8),
    Color(0xFF22D3EE),
    Color(0xFF14B8A6),
    Color(0xFF22C55E),
    Color(0xFF4ADE80),
    Color(0xFFA3E635),
    Color(0xFFFACC15),
    Color(0xFFF59E0B),
    Color(0xFFFB923C),
    Color(0xFFF97316),
    Color(0xFF8B5E34),
    Color(0xFF9CA3AF),
    Color(0xFF64748B),
  ];
  static const List<Color> pocketColorSweep = [
    Color(0xFFF87171),
    Color(0xFFFACC15),
    Color(0xFF22C55E),
    Color(0xFF22D3EE),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
    Color(0xFFF87171),
  ];
  static const Color darkSelectedStateBackground =
      Color(0xFF26272E); // Neutral selection
  static const Color lightPocketAddSurface =
      Color(0xFFF4F5F6); // Subtle add tile
  static const Color lightUncategorizedBanner = Color(0xFFFFF8F0);
  static const Color darkUncategorizedBanner = Color(0xFF2C1C10);
  static const Color lightUncategorizedAccent = Color(0xFFFF9800);
  static const Color darkUncategorizedAccent = Color(0xFFFF9800);
  static const Color lightUncategorizedAmount = Color(0xFFB45309);
  static const Color darkUncategorizedAmount = Color(0xFFFFCC80);
  static const Color lightSplitSheetBg = Color(0xFFF4F4F4);

  // REVISED: Dark mode semantic colors (True Moneko Brand)
  // Replaced stock iOS colors with branded dark mode equivalents
  static const Color darkSuccess =
      Color(0xFF00E0B0); // Vibrant Mint for Dark Mode
  static const Color darkWarning =
      Color(0xFFFFD147); // Lighter Amber for Dark Mode
  static const Color darkDanger = Color(0xFFFF6B6B); // Soft Red for Dark Mode
  static const Color darkInfo = Color(0xFF8B70FF); // Matches Dark Primary

  static const Color lightChartBackground = Color(0xFFFFFFFF);
  static const Color darkChartBackground = Color(0xFF17181D);

  // Insights chart palette
  static const Color insightsRunning = Color(0xFF8B5CF6);
  static const Color insightsBudget = Color(0xFF3B82F6);
  static const Color insightsSpent = Color(0xFFEF4444);
  static const Color insightsProjection = Color(0xFF10B981);

  // WhatsApp brand colors
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappDarkGreen = Color(0xFF128C7E);

  // Skeleton (shimmer) colors tuned for light/dark themes
  static const Color lightSkeletonBase = Color(0xFFE5E7EB);
  static const Color lightSkeletonHighlight = Color(0xFFF3F4F6);
  static const Color darkSkeletonBase = Color(0xFF24262D);
  static const Color darkSkeletonHighlight = Color(0xFF2F3138);

  /// Pockets: tune base pocket color for dark surfaces
  static Color tunedPocketBaseColor(
    Color baseColor,
    ColorScheme scheme, {
    required bool hasCustomColor,
  }) {
    if (!hasCustomColor) {
      return baseColor;
    }
    if (scheme.brightness != Brightness.dark) {
      return baseColor;
    }
    final hsl = HSLColor.fromColor(baseColor);
    // Increased lightness preservation for better visibility in dark mode
    return hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor();
  }

  /// Pockets: progress gradient tuned for the current theme
  static List<Color> pocketProgressGradient({
    required ColorScheme scheme,
    required Color baseColor,
    required double progress,
    required bool isOverBudget,
  }) {
    final hsl = HSLColor.fromColor(baseColor);
    final isDark = scheme.brightness == Brightness.dark;

    if (isOverBudget) {
      final errorColor = isDark
          ? const HSLColor.fromAHSL(1.0, 0, 0.7, 0.5)
          : const HSLColor.fromAHSL(1.0, 0, 0.7, 0.45);
      return [
        errorColor.toColor(),
        errorColor
            .withLightness((errorColor.lightness - 0.1).clamp(0.0, 1.0))
            .toColor(),
      ];
    }

    if (progress > 0.9) {
      final warningColor = isDark
          ? const HSLColor.fromAHSL(1.0, 30, 0.8, 0.55)
          : const HSLColor.fromAHSL(1.0, 30, 0.8, 0.5);
      return [
        warningColor.toColor(),
        warningColor
            .withLightness((warningColor.lightness - 0.1).clamp(0.0, 1.0))
            .toColor(),
      ];
    }

    if (isDark) {
      final brightened =
          hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0));
      return [
        brightened.toColor(),
        brightened
            .withLightness((brightened.lightness - 0.15).clamp(0.0, 1.0))
            .toColor(),
      ];
    }

    return [
      baseColor,
      hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor(),
    ];
  }

  /// Pockets: detail header gradient
  static List<Color> pocketDetailsGradient(
    Color baseColor,
    ColorScheme scheme,
  ) {
    final hsl = HSLColor.fromColor(baseColor);
    final isDark = scheme.brightness == Brightness.dark;

    if (isDark) {
      final top = hsl
          .withLightness((hsl.lightness * 1.0).clamp(0.3, 0.6))
          .withSaturation((hsl.saturation * 0.9).clamp(0.5, 1.0));
      final bottom = hsl
          .withLightness(0.12)
          .withSaturation((hsl.saturation * 0.7).clamp(0.4, 1.0))
          .withHue((hsl.hue + 20) % 360);
      return [top.toColor(), bottom.toColor()];
    }

    final top = hsl
        .withLightness(0.75)
        .withSaturation((hsl.saturation * 1.0).clamp(0.6, 1.0))
        .withHue((hsl.hue - 15) % 360);
    final bottom = hsl
        .withLightness(0.45)
        .withSaturation((hsl.saturation * 1.1).clamp(0.7, 1.0))
        .withHue((hsl.hue + 10) % 360);
    return [top.toColor(), bottom.toColor()];
  }

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
      surface: lightCardBg,
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
      primary: darkPrimary,
      onPrimary: darkButtonText,
      secondary: monekoSecondary,
      surface: darkCardBg,
      onSurface: darkForeground,
      error: darkDanger,
      onError: darkButtonText,
      outline: darkBorder,
      outlineVariant: darkBorderSubtle,
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
