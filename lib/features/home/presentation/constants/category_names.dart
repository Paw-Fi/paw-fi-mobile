import 'package:moneko/features/import/data/worker_localizations.dart'
    if (dart.library.ui) 'package:moneko/l10n/app_localizations.dart';

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

const Set<String> incomeCategoryKeys = <String>{
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

final _translationsByLocale = <String, Map<String, String>>{};

Map<String, String> categoryTranslationsForLocale(String name) =>
    _translationsByLocale.putIfAbsent(name, () {
      final locales = AppLocalizations.supportedLocales;
      final locale = locales.firstWhere((l) => l.toString() == name,
          orElse: () => locales.firstWhere(
              (l) => l.languageCode == name.split('_').first,
              orElse: () => locales.firstWhere((l) => l.languageCode == 'en')));
      return _categoryTranslationsFor(lookupAppLocalizations(locale));
    });

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

/// Normalizes category names from external sources (AI, backend) to canonical categories
String normalizeCategory(String rawCategory) {
  final normalized = rawCategory.toLowerCase().trim();

  if (normalized.isEmpty) {
    return normalized;
  }

  // Preserve canonical categories before attempting alias lookups
  if (_builtinCategoryKeys.contains(normalized)) {
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
  if (_builtinCategoryKeys.contains(normalized)) {
    return normalized;
  }

  // Return as-is if no mapping found (will be treated as "other")
  return normalized;
}
