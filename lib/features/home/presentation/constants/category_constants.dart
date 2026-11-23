import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_icon_options.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_style_overrides.dart';
import 'category_names.dart';
export 'category_names.dart';

// Central palette derived from the Moneko brand plus accessible accent colors
const List<Color> _fallbackPalette = [
  Color(0xFF7458FF),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
  Color(0xFFEF4444),
  Color(0xFFA855F7),
  Color(0xFF22D3EE),
  Color(0xFFFB7185),
  Color(0xFF34D399),
  Color(0xFF6366F1),
  Color(0xFF2DD4BF),
  Color(0xFFEAB308),
  Color(0xFFF472B6),
  Color(0xFF38BDF8),
  Color(0xFF8B5CF6),
];

// Group palettes (shared hue with varied shades)
const List<Color> _lifeAndHomePalette = [
  Color(0xFF1D4ED8),
  Color(0xFF2563EB),
  Color(0xFF3B82F6),
  Color(0xFF60A5FA),
  Color(0xFF93C5FD),
];

const List<Color> _travelAndTransportPalette = [
  Color(0xFFC2410C),
  Color(0xFFEA580C),
  Color(0xFFF97316),
  Color(0xFFFFA94D),
  Color(0xFFFFC78A),
];

const List<Color> _healthAndWellnessPalette = [
  Color(0xFF0F766E),
  Color(0xFF10B981),
  Color(0xFF34D399),
  Color(0xFF4ADE80),
  Color(0xFFA7F3D0),
];

const List<Color> _kidsPalette = [
  Color(0xFFBE123C),
  Color(0xFFF43F5E),
  Color(0xFFFB7185),
  Color(0xFFFDA4AF),
  Color(0xFFFECDD3),
];

const List<Color> _petsPalette = [
  Color(0xFFD97706),
  Color(0xFFF59E0B),
  Color(0xFFFBBF24),
  Color(0xFFFCD34D),
  Color(0xFFFDE68A),
];

const List<Color> _workAndLearningPalette = [
  Color(0xFF312E81),
  Color(0xFF4338CA),
  Color(0xFF4F46E5),
  Color(0xFF6366F1),
  Color(0xFFA5B4FC),
];

const List<Color> _funAndSocialPalette = [
  Color(0xFF9D174D),
  Color(0xFFC026D3),
  Color(0xFFE879F9),
  Color(0xFFF472B6),
  Color(0xFFF9A8D4),
];

const List<Color> _moneyInOutPalette = [
  Color(0xFF166534),
  Color(0xFF15803D),
  Color(0xFF16A34A),
  Color(0xFF22C55E),
  Color(0xFF4ADE80),
];

const List<Color> _communityAndServicesPalette = [
  Color(0xFF0F172A),
  Color(0xFF1F2937),
  Color(0xFF334155),
  Color(0xFF475569),
  Color(0xFF94A3B8),
];

const List<Color> _miscPalette = [
  Color(0xFF6B7280),
  Color(0xFF9CA3AF),
  Color(0xFFD1D5DB),
];

Map<String, Color> _buildGroupColorMap(
  List<String> categories,
  List<Color> palette,
) {
  return {
    for (int i = 0; i < categories.length; i++)
      categories[i]: palette[i % palette.length],
  };
}

final Map<String, Color> categoryColors = {
  ..._buildGroupColorMap(categoryGroups['life_and_home']!, _lifeAndHomePalette),
  ..._buildGroupColorMap(
      categoryGroups['travel_and_transport']!, _travelAndTransportPalette),
  ..._buildGroupColorMap(
      categoryGroups['health_and_wellness']!, _healthAndWellnessPalette),
  ..._buildGroupColorMap(categoryGroups['kids']!, _kidsPalette),
  ..._buildGroupColorMap(categoryGroups['pets']!, _petsPalette),
  ..._buildGroupColorMap(
      categoryGroups['work_and_learning']!, _workAndLearningPalette),
  ..._buildGroupColorMap(
      categoryGroups['fun_and_social']!, _funAndSocialPalette),
  ..._buildGroupColorMap(categoryGroups['money_in_out']!, _moneyInOutPalette),
  ..._buildGroupColorMap(
      categoryGroups['community_and_services']!, _communityAndServicesPalette),
  ..._buildGroupColorMap(categoryGroups['misc']!, _miscPalette),
};

/// Available category image filenames, grouped by asset folder.
const Map<String, Set<String>> _categoryImageFilesByFolder = {
  'life-home': {
    'groceries',
    'food-drinks',
    'restaurants',
    'takeout-delivery',
    'coffee-tea',
    'snacks',
    'cleaning-supplies',
    'home-repairs',
    'home-services',
    'furniture',
    'appliances',
    'household-supplies',
    'laundry-dry-cleaning',
    'moving-costs',
    'storage',
    'clothing-shoes',
  },
  'home-utilities': {
    'home-decor',
    'rent',
    'mortgage',
    'insurance',
    'health-insurance',
    'life-insurance',
    'home-insurance',
    'renters-insurance',
    'electricity',
    'water',
    'heating-gas',
    'internet',
    'phone-bill',
    'home-security',
    'trash-recycling',
  },
  'transport': {
    'public-transport',
    'taxi-ride-apps',
    'fuel-gas',
    'parking',
    'tolls',
    'car-repairs',
    'car-insurance',
    'car-parts',
    'car-rental',
    'bike-scooter',
    'travel',
    'transportation',
  },
  'travel': {
    'flights',
    'hotels',
    'travel-insurance',
    'travel-activities',
    'luggage-travel-gear',
    'passport-visa-fees',
  },
  'health-wellness': {
    'medical-care',
    'pharmacy',
    'dental-care',
    'eye-care',
    'mental-health',
    'therapy',
    'fitness-gym',
    'sports-exercise',
    'supplements',
    'personal-care',
    'beauty-cosmetics',
    'spa-massage',
  },
  'kids-pets': {
    'childcare',
    'school-supplies',
    'kids-activities',
    'kids-clothing',
    'toys-games',
    'baby-supplies',
    'pet-food',
    'pet-treats',
    'vet-visits',
    'pet-medicine',
    'pet-grooming',
    'pet-supplies',
    'pet-insurance',
    'pet-boarding-sitting',
  },
  'work-learning': {
    'work-supplies',
    'home-office',
    'software-tools',
    'cloud-storage',
    'courses-classes',
    'books-study-materials',
    'exams-certificates',
    'coworking-space',
    'professional-services',
    'business-expenses',
    'ads-marketing',
    'licensing-fees',
  },
  'fun-social': {
    'movies-shows',
    'music-streaming',
    'games-apps',
    'hobbies',
    'crafts-art',
    'sports-clubs',
    'concerts-events',
    'bars-drinks',
    'dating',
    'parties-hosting',
    'gifts',
    'charity',
    'collectibles',
  },
  'money': {
    'savings',
    'income',
    'salary',
    'bonus',
    'tips',
    'freelance-income',
    'rental-income',
    'interest-income',
    'gift',
    'cashback',
    'pension',
    'refunds',
    'transfers',
    'investments',
    'loan-payments',
    'debt-payments',
    'bank-fees',
    'taxes',
    'fines',
  },
  'community-misc': {
    'government-services',
    'post-delivery',
    'religious-spiritual',
    'community-events',
    'environmental-green',
    'miscellaneous',
    'other',
    'uncategorized',
  },
};

final RegExp _categoryImageFilenameSeparators = RegExp(r'[^a-z0-9]+');

List<Color> getCustomCategoryColorOptions() {
  return List<Color>.unmodifiable(_fallbackPalette);
}

int computeFallbackCategoryColorArgb(String? category) {
  final raw = (category ?? 'uncategorized').trim().toLowerCase();
  final key = raw.isEmpty ? 'uncategorized' : raw;
  final paletteIndex = key.hashCode.abs() % _fallbackPalette.length;
  return _fallbackPalette[paletteIndex].toARGB32();
}

Color getCategoryColor(String? category, [BuildContext? context]) =>
    _getCategoryColor(
      category,
      context: context,
      useCustomStyleOverrides: true,
    );

Color getSharedTransactionCategoryColor(
  String? category, [
  BuildContext? context,
]) =>
    _getCategoryColor(
      category,
      context: context,
      useCustomStyleOverrides: false,
    );

Color _getCategoryColor(
  String? category, {
  BuildContext? context,
  required bool useCustomStyleOverrides,
}) {
  final directKey = canonicalizeCategoryKey(category);

  Color? baseColor;

  final directOverride = useCustomStyleOverrides
      ? getCustomCategoryStyleOverrides()[directKey]
      : null;
  final directColorArgb = directOverride?.colorArgb;
  if (directColorArgb is int) {
    baseColor = Color(directColorArgb);
  } else {
    final directMapped = categoryColors[directKey];
    if (directMapped != null) {
      baseColor = directMapped;
    } else {
      final key = directKey.contains(' ')
          ? directKey
          : normalizeCategory(category ?? 'uncategorized');

      final override = useCustomStyleOverrides
          ? getCustomCategoryStyleOverrides()[key]
          : null;
      final overrideColorArgb = override?.colorArgb;
      if (overrideColorArgb is int) {
        baseColor = Color(overrideColorArgb);
      } else {
        final mapped = categoryColors[key];
        if (mapped != null) {
          baseColor = mapped;
        } else {
          final paletteIndex = key.hashCode.abs() % _fallbackPalette.length;
          baseColor = _fallbackPalette[paletteIndex];
        }
      }
    }
  }

  if (context != null) {
    // We import AppTheme if needed. Wait, is AppTheme imported?
    // We will ensure it is imported.
    return AppTheme.adaptCategoryColorForTheme(
        baseColor, Theme.of(context).colorScheme);
  }

  return baseColor;
}

/// Returns the bundled image for a built-in category, if available.
String? getCategoryImageAsset(
  String? category,
) {
  final key = canonicalizeCategoryKey(category);
  final filename = key.replaceAll(_categoryImageFilenameSeparators, '-');
  return _categoryImageAssetForFilename(filename);
}

String? getCustomCategoryIconImageAsset(String? iconKey) {
  final key = iconKey?.trim().toLowerCase() ?? '';
  if (key.isEmpty || !customCategoryIconKeys.contains(key)) return null;

  final existingCategoryAsset = _categoryImageAssetForFilename(key);
  return existingCategoryAsset ?? 'lib/assets/images/category/$key.png';
}

String? _categoryImageAssetForFilename(String filename) {
  for (final entry in _categoryImageFilesByFolder.entries) {
    if (entry.value.contains(filename)) {
      return 'lib/assets/images/category/${entry.key}/$filename.png';
    }
  }
  return null;
}

Widget buildCategoryIcon(
  String? category, {
  double size = 20,
  bool useCustomStyleOverrides = false,
}) {
  final categoryKey = canonicalizeCategoryKey(category);
  final customIconKey = useCustomStyleOverrides
      ? getCustomCategoryStyleOverrides()[categoryKey]?.iconKey
      : null;
  final asset = customIconKey == null || customIconKey.isEmpty
      ? getCategoryImageAsset(category)
      : getCustomCategoryIconImageAsset(customIconKey) ??
          getCategoryImageAsset(category);

  return _buildCategoryImage(
    asset ?? getCustomCategoryIconImageAsset('tag'),
    size: size,
    semanticLabel: category,
  );
}

Widget buildCustomCategoryImage(
  String? iconKey, {
  double size = 20,
}) {
  return _buildCategoryImage(
    getCustomCategoryIconImageAsset(iconKey),
    size: size,
  );
}

Widget _buildCategoryImage(
  String? asset, {
  required double size,
  String? semanticLabel,
}) {
  if (asset != null) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => SizedBox.square(dimension: size),
    );
  }
  return SizedBox.square(dimension: size);
}

/// Translates category names to localized strings
String getCategoryTranslation(BuildContext context, String? category) {
  final rawValue = (category ?? 'uncategorized').trim();
  final rawKey = rawValue.toLowerCase();
  final translations = categoryTranslationsForLocale(context.l10n.localeName);

  if (rawKey.isEmpty) {
    return translations['uncategorized'] ?? _titleCase('uncategorized');
  }

  final categoryKey = canonicalizeCategoryKey(rawValue);
  final exact = translations[categoryKey];
  if (exact != null) return exact;

  return _titleCase(rawValue);
}

String? resolveBuiltinCategoryKey(BuildContext context, String? category) {
  final rawValue = (category ?? '').trim();
  if (rawValue.isEmpty) return null;

  return resolveBuiltinCategoryKeyAcrossLocales(rawValue);
}

/// Group title translations (English already provided; other locales can fill later)
String getCategoryGroupTranslation(BuildContext context, String groupKey) {
  final l10n = context.l10n;
  switch (groupKey) {
    case 'life_and_home':
      return l10n.categoryGroupLifeHome;
    case 'travel_and_transport':
      return l10n.categoryGroupTravelTransport;
    case 'health_and_wellness':
      return l10n.categoryGroupHealthWellness;
    case 'kids':
      return l10n.categoryGroupKids;
    case 'pets':
      return l10n.categoryGroupPets;
    case 'work_and_learning':
      return l10n.categoryGroupWorkLearning;
    case 'fun_and_social':
      return l10n.categoryGroupFunSocial;
    case 'money_in_out':
      return l10n.categoryGroupMoneyInOut;
    case 'community_and_services':
      return l10n.categoryGroupCommunityServices;
    case 'misc':
      return l10n.categoryGroupMisc;
    default:
      return _titleCase(groupKey.replaceAll('_', ' '));
  }
}

/// Income-only canonical categories for selection (must match BE)
List<String> getIncomeCategories() {
  return categoryGroups['money_in_out']!
      .where(incomeCategoryKeys.contains)
      .toList(growable: false);
}

/// Expense categories, including external outgoing transfers.
List<String> getExpenseCategories() {
  final incomeCats = {...getIncomeCategories(), 'income'};
  final keys = categoryColors.keys
      .where((k) => k == 'transfers' || !incomeCats.contains(k))
      .toList();
  keys.sort((a, b) => a.compareTo(b));
  return keys;
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map((word) =>
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
