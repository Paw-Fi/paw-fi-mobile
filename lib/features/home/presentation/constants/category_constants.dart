import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_icon_options.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_style_overrides.dart';
import 'package:moneko/l10n/app_localizations.dart';

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

// Plain-language category structure
const List<String> _lifeAndHome = [
  'groceries',
  'food & drinks',
  'restaurants',
  'takeout & delivery',
  'coffee & tea',
  'snacks',
  'household supplies',
  'cleaning supplies',
  'home repairs',
  'home services',
  'furniture',
  'appliances',
  'home decor',
  'rent',
  'mortgage',
  // Insurance (general / household)
  'insurance',
  'health insurance',
  'life insurance',
  'home insurance',
  'renters insurance',
  'electricity',
  'water',
  'heating & gas',
  'internet',
  'phone bill',
  'trash & recycling',
  'home security',
  'laundry / dry cleaning',
  'moving costs',
  'storage',
  'clothing & shoes',
];

const List<String> _travelAndTransport = [
  'public transport',
  'taxi & ride apps',
  'fuel / gas',
  'parking',
  'tolls',
  'car repairs',
  'car insurance',
  'car parts',
  'car rental',
  'bike / scooter',
  'travel',
  'flights',
  'hotels',
  'travel insurance',
  'travel activities',
  'luggage & travel gear',
  'passport & visa fees',
  'transportation',
];

const List<String> _healthAndWellness = [
  'medical care',
  'pharmacy',
  'dental care',
  'eye care',
  'mental health',
  'therapy',
  'fitness & gym',
  'sports & exercise',
  'supplements',
  'personal care',
  'beauty & cosmetics',
  'spa & massage',
];

const List<String> _kids = [
  'childcare',
  'school supplies',
  'kids activities',
  'kids clothing',
  'toys & games',
  'baby supplies',
];

const List<String> _pets = [
  'pet food',
  'pet treats',
  'vet visits',
  'pet medicine',
  'pet grooming',
  'pet supplies',
  'pet insurance',
  'pet boarding / sitting',
];

const List<String> _workAndLearning = [
  'work supplies',
  'home office',
  'software tools',
  'cloud storage',
  'courses & classes',
  'books & study materials',
  'exams & certificates',
  'coworking space',
  'professional services',
  'business expenses',
  'ads & marketing',
  'licensing & fees',
];

const List<String> _funAndSocial = [
  'movies & shows',
  'music & streaming',
  'games & apps',
  'hobbies',
  'crafts & art',
  'sports clubs',
  'concerts & events',
  'bars & drinks',
  'dating',
  'parties & hosting',
  'gifts',
  'charity',
  'collectibles',
];

const List<String> _moneyInOut = [
  'income',
  'salary',
  'bonus',
  'tips',
  'freelance income',
  'rental income',
  'interest income',
  'gift',
  'cashback',
  'pension',
  'refunds',
  'transfers',
  'savings',
  'investments',
  'loan payments',
  'debt payments',
  'bank fees',
  'taxes',
  'fines',
];

const Set<String> _incomeCategoryKeys = <String>{
  'income',
  'salary',
  'bonus',
  'tips',
  'freelance income',
  'rental income',
  'interest income',
  'gift',
  'cashback',
  'pension',
  'refunds',
  'transfers',
  'investments',
};

const List<String> _communityAndServices = [
  'government services',
  'post & delivery',
  'religious & spiritual',
  'community events',
  'environmental / green',
];

const List<String> _misc = [
  'miscellaneous',
  'other',
  'uncategorized',
];

/// Grouped category structure for rendering grouped pickers
const Map<String, List<String>> categoryGroups = {
  'life_and_home': _lifeAndHome,
  'travel_and_transport': _travelAndTransport,
  'health_and_wellness': _healthAndWellness,
  'kids': _kids,
  'pets': _pets,
  'work_and_learning': _workAndLearning,
  'fun_and_social': _funAndSocial,
  'money_in_out': _moneyInOut,
  'community_and_services': _communityAndServices,
  'misc': _misc,
};

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
  ..._buildGroupColorMap(_lifeAndHome, _lifeAndHomePalette),
  ..._buildGroupColorMap(_travelAndTransport, _travelAndTransportPalette),
  ..._buildGroupColorMap(_healthAndWellness, _healthAndWellnessPalette),
  ..._buildGroupColorMap(_kids, _kidsPalette),
  ..._buildGroupColorMap(_pets, _petsPalette),
  ..._buildGroupColorMap(_workAndLearning, _workAndLearningPalette),
  ..._buildGroupColorMap(_funAndSocial, _funAndSocialPalette),
  ..._buildGroupColorMap(_moneyInOut, _moneyInOutPalette),
  ..._buildGroupColorMap(_communityAndServices, _communityAndServicesPalette),
  ..._buildGroupColorMap(_misc, _miscPalette),
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

Map<String, String> _categoryTranslationsFor(AppLocalizations l10n) {
  return <String, String>{
    // Life & Home
    'groceries': l10n.categoryGroceries,
    'food & drinks': l10n.categoryFoodAndDrinks,
    'restaurants': l10n.categoryRestaurants,
    'takeout & delivery': l10n.categoryTakeoutDelivery,
    'coffee & tea': l10n.categoryCoffeeTea,
    'snacks': l10n.categorySnacks,
    'household supplies': l10n.categoryHouseholdSupplies,
    'cleaning supplies': l10n.categoryCleaningSupplies,
    'home repairs': l10n.categoryHomeRepairs,
    'home services': l10n.categoryHomeServices,
    'furniture': l10n.categoryFurniture,
    'appliances': l10n.categoryAppliances,
    'home decor': l10n.categoryHomeDecor,
    'rent': l10n.categoryRent,
    'mortgage': l10n.categoryMortgage,
    // Insurance
    'insurance': l10n.categoryInsurance,
    'health insurance': l10n.categoryHealthInsurance,
    'life insurance': l10n.categoryLifeInsurance,
    'home insurance': l10n.categoryHomeInsurance,
    'renters insurance': l10n.categoryRentersInsurance,
    'electricity': l10n.categoryElectricity,
    'water': l10n.categoryWater,
    'heating & gas': l10n.categoryHeatingGas,
    'internet': l10n.categoryInternet,
    'phone bill': l10n.categoryPhoneBill,
    'trash & recycling': l10n.categoryTrashRecycling,
    'home security': l10n.categoryHomeSecurity,
    'laundry / dry cleaning': l10n.categoryLaundryDryCleaning,
    'moving costs': l10n.categoryMovingCosts,
    'storage': l10n.categoryStorage,
    'clothing & shoes': l10n.categoryClothingShoes,

    // Travel & Daily Transport
    'public transport': l10n.categoryPublicTransport,
    'taxi & ride apps': l10n.categoryTaxiRideApps,
    'fuel / gas': l10n.categoryFuelGas,
    'parking': l10n.categoryParking,
    'tolls': l10n.categoryTolls,
    'car repairs': l10n.categoryCarRepairs,
    'car insurance': l10n.categoryCarInsurance,
    'car parts': l10n.categoryCarParts,
    'car rental': l10n.categoryCarRental,
    'bike / scooter': l10n.categoryBikeScooter,
    'travel': l10n.categoryTravel,
    'flights': l10n.categoryFlights,
    'hotels': l10n.categoryHotels,
    'travel insurance': l10n.categoryTravelInsurance,
    'travel activities': l10n.categoryTravelActivities,
    'luggage & travel gear': l10n.categoryLuggageGear,
    'passport & visa fees': l10n.categoryPassportVisaFees,
    'transportation': l10n.categoryTransportation,

    // Health & Wellness
    'medical care': l10n.categoryMedicalCare,
    'pharmacy': l10n.categoryPharmacy,
    'dental care': l10n.categoryDentalCare,
    'eye care': l10n.categoryEyeCare,
    'mental health': l10n.categoryMentalHealth,
    'therapy': l10n.categoryTherapy,
    'fitness & gym': l10n.categoryFitnessGym,
    'sports & exercise': l10n.categorySportsExercise,
    'supplements': l10n.categorySupplements,
    'personal care': l10n.categoryPersonalCare,
    'beauty & cosmetics': l10n.categoryBeautyCosmetics,
    'spa & massage': l10n.categorySpaMassage,

    // Kids
    'childcare': l10n.categoryChildcare,
    'school supplies': l10n.categorySchoolSupplies,
    'kids activities': l10n.categoryKidsActivities,
    'kids clothing': l10n.categoryKidsClothing,
    'toys & games': l10n.categoryToysGames,
    'baby supplies': l10n.categoryBabySupplies,

    // Pets
    'pet food': l10n.categoryPetFood,
    'pet treats': l10n.categoryPetTreats,
    'vet visits': l10n.categoryVetVisits,
    'pet medicine': l10n.categoryPetMedicine,
    'pet grooming': l10n.categoryPetGrooming,
    'pet supplies': l10n.categoryPetSupplies,
    'pet insurance': l10n.categoryPetInsurance,
    'pet boarding / sitting': l10n.categoryPetBoardingSitting,

    // Work & Learning
    'work supplies': l10n.categoryWorkSupplies,
    'home office': l10n.categoryHomeOffice,
    'software tools': l10n.categorySoftwareTools,
    'cloud storage': l10n.categoryCloudStorage,
    'courses & classes': l10n.categoryCoursesClasses,
    'books & study materials': l10n.categoryBooksStudyMaterials,
    'exams & certificates': l10n.categoryExamsCertificates,
    'coworking space': l10n.categoryCoworkingSpace,
    'professional services': l10n.categoryProfessionalServices,
    'business expenses': l10n.categoryBusinessExpenses,
    'ads & marketing': l10n.categoryAdsMarketing,
    'licensing & fees': l10n.categoryLicensingFees,

    // Fun & Social
    'movies & shows': l10n.categoryMoviesShows,
    'music & streaming': l10n.categoryMusicStreaming,
    'games & apps': l10n.categoryGamesApps,
    'hobbies': l10n.categoryHobbies,
    'crafts & art': l10n.categoryCraftsArt,
    'sports clubs': l10n.categorySportsClubs,
    'concerts & events': l10n.categoryConcertsEvents,
    'bars & drinks': l10n.categoryBarsDrinks,
    'dating': l10n.categoryDating,
    'parties & hosting': l10n.categoryPartiesHosting,
    'gifts': l10n.categoryGifts,
    'charity': l10n.categoryCharity,
    'collectibles': l10n.categoryCollectibles,

    // Money In / Money Out
    'income': l10n.categoryIncome,
    'salary': l10n.categorySalary,
    'bonus': l10n.categoryBonus,
    'tips': l10n.categoryTips,
    'freelance income': l10n.categoryFreelanceIncome,
    'rental income': l10n.categoryRentalIncome,
    'interest income': l10n.categoryInterestIncome,
    'gift': l10n.categoryGifts,
    'cashback': l10n.categoryCashback,
    'pension': l10n.categoryPension,
    'refunds': l10n.categoryRefunds,
    'transfers': l10n.categoryTransfers,
    'savings': l10n.categorySavings,
    'investments': l10n.categoryInvestments,
    'loan payments': l10n.categoryLoanPayments,
    'debt payments': l10n.categoryDebtPayments,
    'bank fees': l10n.categoryBankFees,
    'taxes': l10n.categoryTaxes,
    'fines': l10n.categoryFines,

    // Community & Services
    'government services': l10n.categoryGovernmentServices,
    'post & delivery': l10n.categoryPostDelivery,
    'religious & spiritual': l10n.categoryReligiousSpiritual,
    'community events': l10n.categoryCommunityEvents,
    'environmental / green': l10n.categoryEnvironmentalGreen,

    // Misc
    'miscellaneous': l10n.categoryMiscellaneous,
    'other': l10n.categoryOther,
    'uncategorized': l10n.categoryUncategorized,
  };
}

final Set<String> _builtinCategoryKeys = <String>{
  ..._lifeAndHome,
  ..._travelAndTransport,
  ..._healthAndWellness,
  ..._kids,
  ..._pets,
  ..._workAndLearning,
  ..._funAndSocial,
  ..._moneyInOut,
  ..._communityAndServices,
  ..._misc,
};

final Map<String, String> _builtinCategoryLookupAcrossLocales =
    _buildBuiltinCategoryLookupAcrossLocales();

final Map<String, String> _builtinCategoryLookupByFoldedKey =
    _buildBuiltinCategoryLookupByFoldedKey();

Map<String, String> _buildBuiltinCategoryLookupAcrossLocales() {
  final lookup = <String, String>{};
  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    final translations = _categoryTranslationsFor(l10n);
    for (final entry in translations.entries) {
      final localizedKey = entry.value.trim().toLowerCase();
      if (localizedKey.isEmpty) continue;
      lookup.putIfAbsent(localizedKey, () => entry.key);
    }
  }
  return Map<String, String>.unmodifiable(lookup);
}

const Map<String, String> _baseCategoryAliasMappings = <String, String>{
  'food': 'food & drinks',
  'food and drinks': 'food & drinks',
  'restaurant': 'restaurants',
  'dining': 'restaurants',
  'breakfast': 'food & drinks',
  'brunch': 'food & drinks',
  'lunch': 'food & drinks',
  'dinner': 'food & drinks',
  'meal': 'food & drinks',
  'meals': 'food & drinks',
  'takeout': 'takeout & delivery',
  'delivery': 'takeout & delivery',
  'coffee': 'coffee & tea',
  'tea': 'coffee & tea',
  'snack': 'snacks',
  'grocery': 'groceries',
  'home': 'home repairs',
  'furniture': 'furniture',
  'appliance': 'appliances',
  'decor': 'home decor',
  'rent': 'rent',
  'mortgage': 'mortgage',
  'electric': 'electricity',
  'gas': 'heating & gas',
  'internet': 'internet',
  'phone': 'phone bill',
  'trash': 'trash & recycling',
  'security': 'home security',
  'laundry': 'laundry / dry cleaning',
  'moving': 'moving costs',
  'storage': 'storage',
  'transport': 'public transport',
  'public transportation': 'public transport',
  'public transit': 'public transport',
  'uber': 'taxi & ride apps',
  'taxi': 'taxi & ride apps',
  'bus': 'public transport',
  'train': 'public transport',
  'subway': 'public transport',
  'metro': 'public transport',
  'gasoline': 'fuel / gas',
  'fuel': 'fuel / gas',
  'parking': 'parking',
  'tolls': 'tolls',
  'car': 'car repairs',
  'auto': 'car repairs',
  'insurance': 'insurance',
  'auto insurance': 'car insurance',
  'vehicle insurance': 'car insurance',
  'car insurance': 'car insurance',
  'health insurance': 'health insurance',
  'medical insurance': 'health insurance',
  'life insurance': 'life insurance',
  'home insurance': 'home insurance',
  'house insurance': 'home insurance',
  'renters insurance': 'renters insurance',
  'renter insurance': 'renters insurance',
  'healthcare': 'medical care',
  'health care': 'medical care',
  'health': 'medical care',
  'dental': 'dental care',
  'vision': 'eye care',
  'pharmacy': 'pharmacy',
  'doctor': 'medical care',
  'hospital': 'medical care',
  'gym': 'fitness & gym',
  'fitness': 'fitness & gym',
  'sports': 'sports & exercise',
  'education': 'courses & classes',
  'school': 'courses & classes',
  'university': 'courses & classes',
  'college': 'courses & classes',
  'course': 'courses & classes',
  'book': 'books & study materials',
  'books': 'books & study materials',
  'supplies': 'household supplies',
  'clothing': 'clothing & shoes',
  'shoes': 'clothing & shoes',
  'accessories': 'clothing & shoes',
  'entertainment': 'movies & shows',
  'movie': 'movies & shows',
  'cinema': 'movies & shows',
  'theater': 'movies & shows',
  'concert': 'concerts & events',
  'music': 'music & streaming',
  'game': 'games & apps',
  'gaming': 'games & apps',
  'streaming': 'music & streaming',
  'netflix': 'music & streaming',
  'disney': 'music & streaming',
  'travel': 'travel',
  'vacation': 'travel',
  'hotel': 'hotels',
  'airbnb': 'hotels',
  'flight': 'flights',
  'airline': 'flights',
  'donation': 'charity',
  'charity': 'charity',
  'pet': 'pet supplies',
  'pet food': 'pet food',
  'pet supplies': 'pet supplies',
  'vet': 'vet visits',
  'personal': 'personal care',
  'haircut': 'personal care',
  'salon': 'personal care',
  'spa': 'personal care',
  'beauty': 'personal care',
  'cosmetics': 'personal care',
  'skincare': 'personal care',
  'bank': 'bank fees',
  'atm': 'bank fees',
  'fee': 'bank fees',
  'interest': 'interest income',
  'tax': 'taxes',
  'government': 'taxes',
  'fine': 'fines',
  'legal': 'professional services',
  'lawyer': 'professional services',
  'court': 'professional services',
  'business': 'business expenses',
  'office': 'business expenses',
  'work': 'business expenses',
  'professional': 'business expenses',
};

final Map<String, String> _categoryAliasMappings =
    _buildCategoryAliasMappings();

Map<String, String> _buildCategoryAliasMappings() {
  final mappings = <String, String>{..._baseCategoryAliasMappings};
  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    final translations = _categoryTranslationsFor(l10n);
    for (final entry in translations.entries) {
      final localizedKey = entry.value.trim().toLowerCase();
      if (localizedKey.isEmpty) continue;
      mappings.putIfAbsent(localizedKey, () => entry.key);

      final foldedKey = _foldCategoryAliasKey(localizedKey);
      if (foldedKey.isNotEmpty) {
        mappings.putIfAbsent(foldedKey, () => entry.key);
      }
    }
  }
  return Map<String, String>.unmodifiable(mappings);
}

Map<String, String> _buildBuiltinCategoryLookupByFoldedKey() {
  final lookup = <String, String>{};
  for (final key in _builtinCategoryKeys) {
    final folded = _foldCategoryAliasKey(key);
    if (folded.isNotEmpty) {
      lookup.putIfAbsent(folded, () => key);
    }
  }
  return Map<String, String>.unmodifiable(lookup);
}

String _foldCategoryAliasKey(String value) {
  final words = value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty && word != 'and')
      .toList();
  return words.join(' ');
}

String canonicalizeCategoryKey(String? category) {
  final rawValue = (category ?? 'uncategorized').trim();
  if (rawValue.isEmpty) {
    return 'uncategorized';
  }

  final rawKey = rawValue.toLowerCase();
  if (_builtinCategoryKeys.contains(rawKey)) {
    return rawKey;
  }

  final localized = _builtinCategoryLookupAcrossLocales[rawKey];
  if (localized != null) {
    return localized;
  }

  final folded = _foldCategoryAliasKey(rawValue);
  final foldedBuiltin = _builtinCategoryLookupByFoldedKey[folded];
  if (foldedBuiltin != null) {
    return foldedBuiltin;
  }

  final words = rawKey
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.length == 1) {
    final normalized = normalizeCategory(rawValue);
    if (_builtinCategoryKeys.contains(normalized)) {
      return normalized;
    }
  }

  return rawKey;
}

String? resolveBuiltinCategoryKeyAcrossLocales(String? category) {
  final rawValue = (category ?? '').trim();
  if (rawValue.isEmpty) return null;

  final canonical = canonicalizeCategoryKey(rawValue);
  return _builtinCategoryKeys.contains(canonical) ? canonical : null;
}

List<String> categoryFeedFilterValuesForKey(String? category) {
  final canonical = canonicalizeCategoryKey(category);
  final values = <String>{canonical};

  for (final entry in _categoryAliasMappings.entries) {
    if (canonicalizeCategoryKey(entry.value) == canonical) {
      values.add(entry.key.trim().toLowerCase());
    }
  }

  final sorted = values.where((value) => value.isNotEmpty).toList();
  sorted.sort();
  return sorted;
}

/// Translates category names to localized strings
String getCategoryTranslation(BuildContext context, String? category) {
  final rawValue = (category ?? 'uncategorized').trim();
  final rawKey = rawValue.toLowerCase();
  final translations = _categoryTranslationsFor(context.l10n);

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
  return _moneyInOut
      .where(_incomeCategoryKeys.contains)
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

/// Normalizes category names from external sources (AI, backend) to canonical categories
String normalizeCategory(String rawCategory) {
  final normalized = rawCategory.toLowerCase().trim();

  if (normalized.isEmpty) {
    return normalized;
  }

  // Preserve canonical categories before attempting alias lookups
  if (categoryColors.containsKey(normalized)) {
    return normalized;
  }

  // Direct mapping lookup
  if (_categoryAliasMappings.containsKey(normalized)) {
    return _categoryAliasMappings[normalized]!;
  }

  // Fuzzy matching for partial matches (prefer word-level matches)
  final words = normalized
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  for (final entry in _categoryAliasMappings.entries) {
    final key = entry.key;
    if (key.contains(' ')) {
      if (normalized.contains(key)) {
        return entry.value;
      }
      continue;
    }
    if (words.contains(key)) {
      return entry.value;
    }
  }

  // Check if it's already a valid canonical category
  if (categoryColors.containsKey(normalized)) {
    return normalized;
  }

  // Return as-is if no mapping found (will be treated as "other")
  return normalized;
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map((word) =>
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
