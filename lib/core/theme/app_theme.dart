import 'dart:math' as math;
import 'dart:ui' show ColorSpace;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider based on Flutter's [ThemeMode]
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier({SharedPreferences? preferences})
      : _preferences = preferences,
        super(preferences == null
            ? ThemeMode.system
            : _themeModeFromString(preferences.getString(_storageKey))) {
    if (preferences == null) {
      _loadThemeMode();
    }
  }

  static const _storageKey = 'moneko_theme_mode';
  final SharedPreferences? _preferences;
  int _writeRevision = 0;

  Future<void> _loadThemeMode() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    // Do not let a slow startup read overwrite a selection made while it was
    // loading.
    if (_writeRevision > 0) {
      return;
    }

    if (stored == null) {
      state = ThemeMode.system;
      return;
    }

    state = _themeModeFromString(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _writeRevision++;
    state = mode;
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _themeModeToString(mode));
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
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
  WalletColorPalette walletPalette(Color walletColor) => generateWalletPalette(
        walletColor: walletColor,
        brightness: brightness,
      );

  // The branded Plus introduction uses the same palette in both themes.
  Color get plusIntroTop => const Color(0xFF7953FF);
  Color get plusIntroBottom => const Color(0xFFB561F4);
  Color get plusIntroForeground => const Color(0xFFFFFFFF);
  Color get plusIntroSurface => const Color(0xFF7950DE);
  Color get plusIntroButton => const Color(0xFFFFFFFF);
  Color get plusIntroButtonForeground => const Color(0xFF242424);
  Color get plusIntroAccent => const Color(0xFF7953FF);

  Color get planSelectionBackground => brightness == Brightness.dark
      ? const Color(0xFF101014)
      : const Color(0xFFF1F1F3);
  Color get planSelectionCloudBase => brightness == Brightness.dark
      ? const Color(0xFF232427)
      : const Color(0xFFFCFCFC);
  Color get planSelectionCard => brightness == Brightness.dark
      ? const Color(0xFF101014)
      : const Color(0xFFF9F8FC);
  Color get planSelectionAccent => const Color(0xFF7953FF);
  Color get planSelectionRatingAccent => brightness == Brightness.dark
      ? const Color(0xFFCC72AB)
      : const Color(0xFFFFAE43);
  String get planSelectionHeroAsset => brightness == Brightness.dark
      ? 'lib/assets/images/paywall/plan_selection/plus-dark.png'
      : 'lib/assets/images/paywall/plan_selection/plus-light.png';
  String get planSelectionBackgroundAsset => brightness == Brightness.dark
      ? 'lib/assets/images/paywall/plan_selection/bg-dark.svg'
      : 'lib/assets/images/paywall/plan_selection/bg-light.svg';

  /// Background for cards/surfaces
  Color get card => brightness == Brightness.dark
      ? AppTheme.darkCardBg
      : AppTheme.lightCardBg;

  /// Bright, softened tint for Browse tool icon containers.
  Color browseIconBackground(Color accent) =>
      Color.lerp(card, accent, brightness == Brightness.dark ? 0.24 : 0.16) ??
      card;

  Color get appBackground => brightness == Brightness.dark
      ? AppTheme.darkBackground
      : AppTheme.lightBackground;

  List<Color> get seamlessHeaderBackdropGradient =>
      brightness == Brightness.dark
          ? recurringSummaryGradient
          : [
              const Color(0xFFDDE3EC).withValues(alpha: 0.38),
              const Color(0xFFE5DDF2).withValues(alpha: 0.18),
              surface.withValues(alpha: 0.0),
            ];

  Color get seamlessHeaderBackdropBorder => brightness == Brightness.dark
      ? mutedForeground.withValues(alpha: 0.07)
      : const Color(0xFF9AA3B3).withValues(alpha: 0.055);

  /// Bottom sheet and modal surface
  Color get sheetBackground => brightness == Brightness.dark
      ? AppTheme.darkSheetBg
      : AppTheme.lightSheetBg;

  /// Sheet element background (cards, tiles within sheets)
  Color get sheetElementBackground => brightness == Brightness.dark
      ? AppTheme.darkSheetElementBg
      : AppTheme.lightCardBg;

  /// Subtle border color
  Color get border => outlineVariant;

  /// Stronger border for sheets and drag handles
  Color get sheetBorder => outline;

  /// NEW: Distinct border for Dark Mode cards (Apple Style/Modern Mobile)
  /// Use this on Container(decoration: BoxDecoration(border: Border.all(color: scheme.surfaceBorder)))
  Color get surfaceBorder => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.12)
      : surface.withValues(alpha: 0.0);

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

  List<BoxShadow>? get groupedCardShadows => brightness == Brightness.dark
      ? null
      : [
          BoxShadow(
              color: shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ];

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

  /// Readable semantic text on the budgeting companion's softly tinted card.
  Color get budgetSuccessForeground => brightness == Brightness.dark
      ? AppTheme.darkSuccess
      : const Color(0xFF007A5C);

  Color get budgetWarningForeground => brightness == Brightness.dark
      ? AppTheme.darkWarning
      : const Color(0xFF895500);

  Color get budgetDangerForeground => brightness == Brightness.dark
      ? AppTheme.darkDanger
      : const Color(0xFFB92D37);

  Color get budgetCautionForeground => brightness == Brightness.dark
      ? AppTheme.darkProgressOrange
      : const Color(0xFF9C4700);

  Color get budgetInfoForeground => brightness == Brightness.dark
      ? const Color(0xFFCCBFFF)
      : const Color(0xFF5030B8);

  /// Home budget gauge arc colors, tuned per background: light keeps the
  /// brand semantics, dark lifts amber so it reads on the near-black page.
  Color get budgetGaugeSuccess => success;

  Color get budgetGaugeWarning => brightness == Brightness.dark
      ? const Color(0xFFFFDC6E)
      : AppTheme.warning;

  Color get budgetGaugeDanger => destructive;

  Color get budgetGaugeCaution => progressOrange;

  Color get budgetGaugeInfo => info;

  /// Soft halo painted beneath the gauge's active arc.
  Color budgetGaugeGlow(Color arc) =>
      arc.withValues(alpha: brightness == Brightness.dark ? .55 : .32);

  /// Warning color
  Color get warning =>
      brightness == Brightness.dark ? AppTheme.darkWarning : AppTheme.warning;

  /// Progress color for early, but non-zero, completion.
  Color get progressOrange => brightness == Brightness.dark
      ? AppTheme.darkProgressOrange
      : AppTheme.progressOrange;

  /// Progress color for fully completed budgets.
  Color get progressComplete => brightness == Brightness.dark
      ? AppTheme.darkProgressComplete
      : AppTheme.progressComplete;

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

  /// Stronger outline for the exposed portion of collapsed wallet cards.
  Color get walletCardCollapsedBorder => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.86)
      : Colors.black.withValues(alpha: 0.86);

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

  /// Recurring summary card gradient colors
  List<Color> get recurringSummaryGradient => brightness == Brightness.dark
      ? [
          primary.withValues(alpha: 0.12),
          surface.withValues(alpha: 0.04),
        ]
      : [
          AppTheme.lightRecurringSummaryGradientStart,
          AppTheme.lightRecurringSummaryGradientBlush,
          AppTheme.lightRecurringSummaryGradientCool,
          AppTheme.lightRecurringSummaryGradientEnd,
        ];

  /// Recurring summary card border
  Color get recurringSummaryBorder => brightness == Brightness.dark
      ? surfaceBorder
      : AppTheme.lightRecurringSummaryBorder;

  /// Home: standard card surface
  Color get homeCardSurface => cardSurface;

  /// Home: standard card border
  Color get homeCardBorder => outline.withValues(
        alpha: brightness == Brightness.dark ? 0.12 : 0.05,
      );

  /// Home: standard card shadow
  Color get homeCardShadow => shadow.withValues(
        alpha: brightness == Brightness.dark ? 0.0 : 0.05,
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

  Color get appleInputBackground => brightness == Brightness.dark
      ? AppTheme.iosInputDark
      : AppTheme.iosInputLight;

  /// Modal sheet drag handle color
  Color get sheetHandle => brightness == Brightness.dark
      ? const Color(0xFF5D5D60)
      : const Color(0xFFC4C4C7);

  /// Light divider for list separators
  Color get listDivider => outline.withValues(alpha: 0.3);
}

/// Moneko app theme configuration matching web's Tailwind design system
class AppTheme {
  static const SystemUiOverlayStyle lightSystemUiOverlayStyle =
      SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle darkSystemUiOverlayStyle =
      SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  // Moneko brand colors from web (app.css)
  static const Color monekoPrimary = Color(0xFF7458FF); // --moneko-primary
  static const Color monekoSecondary = Color(0xFF836DFF); // --moneko-secondary
  static const Color iconColor = Color(0xFFAA76FF); // --icon

  // BRANDED SEMANTIC COLORS (Light Mode)
  static const Color success = Color(0xFF16CDA2); // --success (Moneko Mint)
  static const Color warning = Color(0xFFFFC219); // --warning (Moneko Amber)
  static const Color danger = Color(0xFFFF6060); // --danger (Moneko Red)
  static const Color info = monekoPrimary;
  static const Color progressOrange = Color(0xFFFF8A3D);
  static const Color progressComplete = Color(0xFF087F5B);

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
  static const Color lightSheetBg = Color(0xFFF5F5F5); // Sheet background

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
  static const Color darkSheetBg = Color(0xFF1D1D1D); // Sheet background
  static const Color darkSheetElementBg =
      Color(0xFF252525); // Sheet element background
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

  // Recurring summary card gradient (light): atmospheric multi-stop
  // near-white -> warm blush -> cool gray-blue -> pure white
  static const Color lightRecurringSummaryGradientStart =
      Color(0xFFFAFAFA); // Near-white (top-left)
  static const Color lightRecurringSummaryGradientBlush =
      Color(0xFFFBF6F4); // Barely visible warm blush (top-right)
  static const Color lightRecurringSummaryGradientCool =
      Color(0xFFF4F6F8); // Subtle cool gray-blue (middle)
  static const Color lightRecurringSummaryGradientEnd =
      Color(0xFFFFFFFF); // Pure white (bottom)
  static const Color lightRecurringSummaryBorder =
      Color(0xFFE8E5E1); // Subtle warm border

  // REVISED: Dark mode semantic colors (True Moneko Brand)
  // Replaced stock iOS colors with branded dark mode equivalents
  static const Color darkSuccess =
      Color(0xFF00E0B0); // Vibrant Mint for Dark Mode
  static const Color darkWarning =
      Color(0xFFFFD147); // Lighter Amber for Dark Mode
  static const Color darkDanger = Color(0xFFFF6B6B); // Soft Red for Dark Mode
  static const Color darkInfo = Color(0xFF8B70FF); // Matches Dark Primary
  static const Color darkProgressOrange = Color(0xFFFF9E5C);
  static const Color darkProgressComplete = Color(0xFF00A67A);

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

  /// Adjust category colors for dark mode legibility.
  /// Used for icons and charts to maintain WCAG contrast.
  static Color adaptCategoryColorForTheme(Color baseColor, ColorScheme scheme) {
    if (scheme.brightness != Brightness.dark) {
      return baseColor;
    }

    final hsl = HSLColor.fromColor(baseColor);
    // Ensure minimum lightness of 0.65 for dark mode to maintain contrast against dark grey cards.
    if (hsl.lightness < 0.65) {
      return hsl.withLightness(0.65).toColor();
    }
    return baseColor;
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
      surfaceContainer: lightSheetBg,
      surfaceContainerHigh: lightSheetBg,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      splashColor:
          Colors.transparent, // Modern premium apps suppress Material ripples
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: lightSystemUiOverlayStyle,
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSheetBg,
        modalBackgroundColor: lightSheetBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(28)), // Matches latest iOS sheet radii
        ),
      ),
      snackBarTheme: AppSnackBarStyles.build(scheme, isDark: false),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return monekoPrimary;
          return lightCardBg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return monekoPrimary.withValues(alpha: 0.35);
          }
          return lightBorder;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return lightBorder;
        }),
      ),
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
      surfaceContainer: darkSheetBg,
      surfaceContainerHigh: darkSheetBg,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      splashColor:
          Colors.transparent, // Modern premium apps suppress Material ripples
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: darkSystemUiOverlayStyle,
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: AppSnackBarStyles.build(scheme, isDark: true),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: darkBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return darkCardBg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary.withValues(alpha: 0.35);
          }
          return darkBorder;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return darkBorder;
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkSheetBg,
        modalBackgroundColor: darkSheetBg,
        dragHandleColor: scheme.onSurface.withValues(alpha: 0.4),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(28)), // Standardized to 28 for premium feel
        ),
      ),
    );
  }

  // Helper to generate ColorScheme seed matching Moneko brand
  static Color get monekoSeed => monekoPrimary;

  /// Cupertino light theme derived from the same color constants as [lightTheme].
  static CupertinoThemeData cupertinoLightTheme() => const CupertinoThemeData(
        brightness: Brightness.light,
        applyThemeToAll: true,
        primaryColor: monekoPrimary,
        primaryContrastingColor: lightButtonText,
        scaffoldBackgroundColor: lightBackground,
        barBackgroundColor: lightBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: monekoPrimary,
          navActionTextStyle: TextStyle(color: monekoPrimary),
          navTitleTextStyle: TextStyle(color: lightForeground),
          textStyle: TextStyle(color: lightForeground),
        ),
      );

  /// Cupertino dark theme derived from the same color constants as [darkTheme].
  static CupertinoThemeData cupertinoDarkTheme() => const CupertinoThemeData(
        brightness: Brightness.dark,
        applyThemeToAll: true,
        primaryColor: darkPrimary,
        primaryContrastingColor: darkButtonText,
        scaffoldBackgroundColor: darkBackground,
        barBackgroundColor: darkBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: darkPrimary,
          navActionTextStyle: TextStyle(color: darkPrimary),
          navTitleTextStyle: TextStyle(color: darkForeground),
          textStyle: TextStyle(color: darkForeground),
        ),
      );
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

/// Display-only wallet colors. The persisted custom color is never rewritten.
///
/// OKLCH tones retain hue while varying lightness/chroma independently. Gamut
/// mapping reduces chroma, rather than clipping RGB channels and changing hue.
///
/// The card surface is an organic mesh: a tonal wash, several irregular soft
/// color sources and ambient lighting layers, all in normalized card space.
@immutable
class WalletColorPalette {
  const WalletColorPalette._({
    required this.backgroundStart,
    required this.meshLayers,
    required this.edgeHighlight,
    required this.edgeLowlight,
    required this.shadow,
    required this.iconBackground,
    required this.iconBackgroundEnd,
    required this.iconRim,
    required this.iconShadow,
    required this.iconForeground,
    required this.progressTrack,
    required this.progressFillStart,
    required this.progressFillEnd,
    required this.primaryText,
    required this.secondaryText,
    required this.border,
    required this.badgeBackground,
    required this.badgeForeground,
  });

  final Color backgroundStart;
  final List<WalletMeshLayer> meshLayers;
  final Color edgeHighlight;
  final Color edgeLowlight;
  final Color shadow;
  final Color iconBackground;
  final Color iconBackgroundEnd;
  final Color iconRim;
  final Color iconShadow;
  final Color iconForeground;
  final Color progressTrack;
  final Color progressFillStart;
  final Color progressFillEnd;
  final Color primaryText;
  final Color secondaryText;
  final Color border;
  final Color badgeBackground;
  final Color badgeForeground;

  LinearGradient get progressGradient => LinearGradient(
        colors: [progressFillStart, progressFillEnd],
      );

  LinearGradient get iconSurfaceGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [iconBackground, iconBackgroundEnd],
      );

  List<BoxShadow> get iconShadows => [
        BoxShadow(color: iconShadow, blurRadius: 6, offset: const Offset(0, 2)),
      ];
}

const _walletMeshFalloffStops = [
  0.0,
  0.125,
  0.25,
  0.375,
  0.5,
  0.625,
  0.75,
  0.875,
  1.0,
];

/// One soft layer in normalized card space: x spans the card width, y spans
/// the expanded card height, so a collapsed card shows the top of the same
/// surface. Radial layers fade along a smootherstep curve, which has zero
/// slope at both ends and therefore no visible circular boundary.
@immutable
class WalletMeshLayer {
  WalletMeshLayer.radial({
    required Offset this.center,
    required Size this.radius,
    required Color color,
    required double opacity,
  })  : begin = 0,
        end = 1,
        stops = _walletMeshFalloffStops,
        colors = List.unmodifiable([
          for (final t in _walletMeshFalloffStops)
            color.withValues(
              alpha: opacity * (1 - t * t * t * (t * (t * 6 - 15) + 10)),
            ),
        ]);

  WalletMeshLayer.vertical({
    required this.begin,
    required this.end,
    required List<Color> colors,
    required List<double> stops,
  })  : center = null,
        radius = null,
        colors = List.unmodifiable(colors),
        stops = List.unmodifiable(stops);

  final Offset? center;
  final Size? radius;
  final double begin;
  final double end;
  final List<Color> colors;
  final List<double> stops;

  Color colorAt(double x, double y) {
    final double t;
    if (center case final center?) {
      final dx = (x - center.dx) / radius!.width;
      final dy = (y - center.dy) / radius!.height;
      t = math.sqrt(dx * dx + dy * dy).clamp(0.0, 1.0);
    } else {
      t = ((y - begin) / (end - begin)).clamp(0.0, 1.0);
    }
    for (var index = 1; index < stops.length; index++) {
      if (t <= stops[index]) {
        final span = stops[index] - stops[index - 1];
        return Color.lerp(colors[index - 1], colors[index],
            span <= 0 ? 1 : (t - stops[index - 1]) / span)!;
      }
    }
    return colors.last;
  }
}

// Bounded FIFO cache: rebuilds/expansion reuse the palette, but a color picker
// cannot accumulate unbounded entries. Theme and the exact input are the key.
final _walletDisplayPaletteCache = <(Color, Brightness), WalletColorPalette>{};

WalletColorPalette generateWalletPalette({
  required Color walletColor,
  required Brightness brightness,
}) {
  final key = (walletColor, brightness);
  final cached = _walletDisplayPaletteCache[key];
  if (cached != null) return cached;
  final palette = _buildWalletPalette(walletColor, brightness);
  if (_walletDisplayPaletteCache.length >= 128) {
    _walletDisplayPaletteCache.remove(_walletDisplayPaletteCache.keys.first);
  }
  _walletDisplayPaletteCache[key] = palette;
  return palette;
}

WalletColorPalette _buildWalletPalette(Color original, Brightness brightness) {
  final source = _WalletOklch.fromColor(original);
  final dark = brightness == Brightness.dark;
  // Soft-knee chroma compression: muted selections are never boosted, neon
  // selections are tamed. The lower dark ceiling keeps large surfaces quiet.
  // Achromatic inputs remain achromatic; do not invent an arbitrary hue.
  final chromaLimit = dark ? 0.135 : 0.165;
  final chroma = source.chroma < 0.008
      ? 0.0
      : source.chroma /
          math.pow(1 + math.pow(source.chroma / chromaLimit, 4), 0.25);
  // Lightness is normalized so every wallet feels equally luminous. A small
  // part of the source lightness survives: yellow stays yellow rather than
  // olive and deep violet stays deep. Dark tones are capped so the surface
  // keeps light foregrounds legible.
  final tone = chroma == 0
      ? (dark ? 0.34 + source.lightness * 0.16 : 0.60 + source.lightness * 0.27)
      : math.min(
          dark ? 0.53 : 0.83,
          (dark ? 0.50 : 0.69) +
              (source.lightness - 0.65).clamp(-0.15, 0.3) *
                  (dark ? 0.12 : 0.45),
        );
  // Neighboring-hue offsets are damped around yellow, where small OKLCH hue
  // changes read as lime or amber instead of a harmonious variation.
  final hueDegrees = (source.hue * 180 / math.pi) % 360;
  final hueSpread = 1 - 0.65 * math.exp(-math.pow((hueDegrees - 108) / 22, 2));
  _WalletOklch tint(double lightness, double chromaScale, [double hue = 0]) =>
      _WalletOklch(
        lightness.clamp(0.0, 1.0),
        chroma * chromaScale,
        source.hue + hue * hueSpread * math.pi / 180,
      );
  Color color(double lightness, double chromaScale, [double hue = 0]) =>
      tint(lightness, chromaScale, hue).toColor();
  const white = Color(0xFFFFFFFF);

  // Light: a vibrant upper surface dissolving into an airy, near-white base.
  // Dark: a richer surface sinking into deep, still-tinted lower tones.
  final bottom =
      dark ? tone - 0.19 : math.min(0.985, math.max(0.955, tone + 0.12));
  final washMiddle = dark ? tone - 0.12 : tone + (bottom - tone) * 0.62;
  final upper = color(tone, 1);
  final middle = color(washMiddle, dark ? 0.72 : 0.5);
  final lower = color(bottom, dark ? 0.5 : 0.14);
  final shade = dark ? color(0.10, 0.3) : color(0.45, 0.5);
  final meshLayers = List<WalletMeshLayer>.unmodifiable([
    WalletMeshLayer.vertical(
      begin: 0,
      end: 1,
      colors: [
        upper,
        color(dark ? tone - 0.03 : tone + 0.05, dark ? 0.95 : 0.88),
        middle,
        lower,
      ],
      stops: const [0, 0.3, 0.66, 1],
    ),
    // Irregular sources with distinct radii, strengths and neighboring hues.
    WalletMeshLayer.radial(
      center: const Offset(0.06, 0),
      radius: const Size(0.78, 0.62),
      color: color(dark ? tone + 0.02 : tone - 0.025, dark ? 1.12 : 1.1, -14),
      opacity: dark ? 0.8 : 0.85,
    ),
    WalletMeshLayer.radial(
      center: const Offset(0.97, 0.08),
      radius: const Size(0.6, 0.55),
      color: color(dark ? tone - 0.09 : tone - 0.05, dark ? 1.05 : 1, 11),
      opacity: dark ? 0.75 : 0.7,
    ),
    WalletMeshLayer.radial(
      center: const Offset(0.55, 0.41),
      radius: const Size(0.55, 0.36),
      color: color(dark ? tone - 0.01 : tone + 0.1, dark ? 0.85 : 0.7, -6),
      opacity: dark ? 0.45 : 0.5,
    ),
    WalletMeshLayer.radial(
      center: const Offset(0.1, 0.79),
      radius: const Size(0.6, 0.41),
      color: color(dark ? tone - 0.15 : tone + (bottom - tone) * 0.7,
          dark ? 0.78 : 0.42, 8),
      opacity: dark ? 0.6 : 0.55,
    ),
    WalletMeshLayer.radial(
      center: const Offset(0.9, 0.7),
      radius: const Size(0.5, 0.38),
      color: color(dark ? tone - 0.11 : tone + (bottom - tone) * 0.55,
          dark ? 0.62 : 0.5, -10),
      opacity: 0.45,
    ),
    WalletMeshLayer.radial(
      center: const Offset(0.5, 1.1),
      radius: const Size(0.95, 0.49),
      color: color(dark ? bottom - 0.03 : bottom + 0.01, dark ? 0.45 : 0.08),
      opacity: dark ? 0.8 : 0.85,
    ),
    // Ambient lighting: a satin sheen from above, a soft key light at the
    // upper left, a faint fill on the right edge and gentle lower falloff.
    WalletMeshLayer.vertical(
      begin: 0,
      end: dark ? 0.3 : 0.34,
      colors: [
        white.withValues(alpha: dark ? 0.09 : 0.22),
        white.withValues(alpha: dark ? 0.03 : 0.07),
        white.withValues(alpha: 0),
      ],
      stops: const [0, 0.45, 1],
    ),
    WalletMeshLayer.radial(
      center: const Offset(0.2, -0.06),
      radius: const Size(0.55, 0.32),
      color: dark ? color(0.95, 0.15) : white,
      opacity: dark ? 0.12 : 0.2,
    ),
    WalletMeshLayer.radial(
      center: const Offset(1.02, 0.25),
      radius: const Size(0.25, 0.4),
      color: dark ? color(0.9, 0.2) : white,
      opacity: dark ? 0.06 : 0.1,
    ),
    WalletMeshLayer.vertical(
      begin: dark ? 0.78 : 0.8,
      end: 1,
      colors: [
        shade.withValues(alpha: 0),
        shade.withValues(alpha: dark ? 0.18 : 0.05),
      ],
      stops: const [0, 1],
    ),
  ]);
  // Foregrounds are measured against the composited surface as painted,
  // sampled across the whole content region of the expanded card.
  final surfaces = [
    for (var row = 0; row <= 8; row++)
      for (var column = 0; column <= 8; column++)
        _walletSurfaceAt(
            upper, meshLayers, 0.06 + column * 0.11, 0.08 + row * 0.11),
  ];
  final iconBackground = dark ? color(0.31, 0.32) : color(0.995, 0.01);
  final iconBackgroundEnd = dark ? color(0.22, 0.26) : color(0.955, 0.08);
  final iconSurfaces = [iconBackground, iconBackgroundEnd];
  return WalletColorPalette._(
    backgroundStart: upper,
    meshLayers: meshLayers,
    edgeHighlight: dark
        ? color(0.88, 0.3).withValues(alpha: 0.28)
        : white.withValues(alpha: 0.7),
    edgeLowlight: dark
        ? color(0.06, 0.2).withValues(alpha: 0.3)
        : color(0.62, 0.5).withValues(alpha: 0.22),
    shadow: dark
        ? color(0.04, 0.25).withValues(alpha: 0.85)
        : color(0.3, 0.7).withValues(alpha: 0.5),
    iconBackground: iconBackground,
    iconBackgroundEnd: iconBackgroundEnd,
    iconRim: dark
        ? color(0.62, 0.45).withValues(alpha: 0.4)
        : white.withValues(alpha: 0.85),
    iconShadow: dark
        ? color(0.05, 0.2).withValues(alpha: 0.5)
        : color(0.35, 0.6).withValues(alpha: 0.22),
    iconForeground: _walletForeground(
      iconSurfaces,
      dark ? tint(0.82, 1.05, -6) : tint(0.58, 1.15, -6),
      preferLight: dark,
      minimumContrast: 3,
    ),
    progressTrack: dark ? color(0.24, 0.35) : color(0.86, 0.38),
    progressFillStart: dark ? color(0.68, 1.05, -8) : color(0.6, 1.1, -8),
    progressFillEnd: dark ? color(0.75, 0.9, 8) : color(0.67, 0.95, 8),
    primaryText: _walletForeground(
      surfaces,
      dark ? tint(0.985, 0.04) : tint(0.25, 0.35),
      preferLight: dark,
    ),
    secondaryText: _walletForeground(
      surfaces,
      dark ? tint(0.9, 0.1) : tint(0.37, 0.3),
      preferLight: dark,
    ),
    border: dark ? color(0.42, 0.35) : color(0.99, 0.03),
    badgeBackground: iconBackground,
    badgeForeground: _walletForeground(
      iconSurfaces,
      dark ? tint(0.92, 0.12) : tint(0.32, 0.3),
      preferLight: dark,
    ),
  );
}

/// sRGB source-over compositing of [layers], matching the painter.
Color _walletSurfaceAt(
  Color base,
  List<WalletMeshLayer> layers,
  double x,
  double y,
) {
  var red = base.r;
  var green = base.g;
  var blue = base.b;
  for (final layer in layers) {
    final color = layer.colorAt(x, y);
    final alpha = color.a;
    red = color.r * alpha + red * (1 - alpha);
    green = color.g * alpha + green * (1 - alpha);
    blue = color.b * alpha + blue * (1 - alpha);
  }
  return Color.from(alpha: 1, red: red, green: green, blue: blue);
}

/// Walks lightness away from the surface first, then the other way, keeping
/// the preferred hue/chroma. Never relies on alpha, which could silently fail
/// contrast on the colorful parts of the surface.
Color _walletForeground(
  List<Color> backgrounds,
  _WalletOklch preferred, {
  required bool preferLight,
  double minimumContrast = 4.5,
}) {
  var best = preferred.toColor();
  var bestContrast = _walletMinimumContrast(best, backgrounds);
  for (final direction in [preferLight ? 1 : -1, preferLight ? -1 : 1]) {
    for (var step = 0; step <= 100; step++) {
      final lightness = preferred.lightness + direction * step * 0.01;
      if (lightness < 0 || lightness > 1) break;
      final candidate =
          _WalletOklch(lightness, preferred.chroma, preferred.hue).toColor();
      final contrast = _walletMinimumContrast(candidate, backgrounds);
      if (contrast >= minimumContrast) return candidate;
      if (contrast > bestContrast) {
        best = candidate;
        bestContrast = contrast;
      }
    }
  }
  return best;
}

double _walletMinimumContrast(Color foreground, List<Color> backgrounds) {
  final foregroundLuminance = foreground.computeLuminance();
  var minimum = double.infinity;
  for (final background in backgrounds) {
    final luminance = background.computeLuminance();
    final ratio = (math.max(foregroundLuminance, luminance) + 0.05) /
        (math.min(foregroundLuminance, luminance) + 0.05);
    minimum = math.min(minimum, ratio);
  }
  return minimum;
}

/// Bjorn Ottosson's public-domain Oklab matrices:
/// https://bottosson.github.io/posts/oklab/ (linear sRGB, D65).
class _WalletOklch {
  const _WalletOklch(this.lightness, this.chroma, this.hue);

  final double lightness;
  final double chroma;
  final double hue;

  factory _WalletOklch.fromColor(Color color) {
    // Normalize wide-gamut inputs before applying the sRGB transfer function.
    final srgb = color.withValues(colorSpace: ColorSpace.sRGB);
    double linear(double value) => value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    final r = linear(srgb.r);
    final g = linear(srgb.g);
    final b = linear(srgb.b);
    final l = math
        .pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
        .toDouble();
    final m = math
        .pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
        .toDouble();
    final s = math
        .pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
        .toDouble();
    final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final labB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    return _WalletOklch(
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      math.sqrt(a * a + labB * labB),
      math.atan2(labB, a),
    );
  }

  _WalletOklch mix(_WalletOklch other, double t) => _WalletOklch(
        lightness + (other.lightness - lightness) * t,
        chroma + (other.chroma - chroma) * t,
        hue,
      );

  (double, double, double) _linearRgb(double mappedChroma) {
    final a = mappedChroma * math.cos(hue);
    final b = mappedChroma * math.sin(hue);
    final l = lightness + 0.3963377774 * a + 0.2158037573 * b;
    final m = lightness - 0.1055613458 * a - 0.0638541728 * b;
    final s = lightness - 0.0894841775 * a - 1.2914855480 * b;
    return (
      4.0767416621 * l * l * l -
          3.3077115913 * m * m * m +
          0.2309699292 * s * s * s,
      -1.2684380046 * l * l * l +
          2.6097574011 * m * m * m -
          0.3413193965 * s * s * s,
      -0.0041960863 * l * l * l -
          0.7034186147 * m * m * m +
          1.7076147010 * s * s * s,
    );
  }

  Color toColor() {
    bool inGamut((double, double, double) rgb) => [rgb.$1, rgb.$2, rgb.$3]
        .every((channel) => channel >= 0 && channel <= 1);
    var rgb = _linearRgb(chroma);
    if (!inGamut(rgb)) {
      var low = 0.0;
      var high = chroma;
      for (var iteration = 0; iteration < 24; iteration++) {
        final candidate = (low + high) / 2;
        if (inGamut(_linearRgb(candidate))) {
          low = candidate;
        } else {
          high = candidate;
        }
      }
      rgb = _linearRgb(low);
    }
    double encoded(double channel) {
      final value = channel.clamp(0.0, 1.0);
      return value <= 0.0031308
          ? value * 12.92
          : 1.055 * math.pow(value, 1 / 2.4) - 0.055;
    }

    return Color.from(
        alpha: 1,
        red: encoded(rgb.$1),
        green: encoded(rgb.$2),
        blue: encoded(rgb.$3));
  }
}
