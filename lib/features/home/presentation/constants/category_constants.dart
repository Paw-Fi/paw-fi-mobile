import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';

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

final Map<String, IconData> categoryIcons = {
  // Life & Home
  'groceries': Icons.local_grocery_store,
  'food & drinks': Icons.fastfood,
  'restaurants': Icons.restaurant,
  'takeout & delivery': Icons.delivery_dining,
  'coffee & tea': Icons.local_cafe,
  'snacks': Icons.lunch_dining,
  'household supplies': Icons.cleaning_services,
  'cleaning supplies': Icons.clean_hands,
  'home repairs': Icons.handyman,
  'home services': Icons.home_repair_service,
  'furniture': Icons.weekend,
  'appliances': Icons.kitchen,
  'home decor': Icons.style,
  'rent': Icons.apartment,
  'mortgage': Icons.house,
  'electricity': Icons.bolt,
  'water': Icons.water_drop,
  'heating & gas': Icons.local_fire_department,
  'internet': Icons.wifi,
  'phone bill': Icons.phone_iphone,
  'trash & recycling': Icons.delete_outline,
  'home security': Icons.security,
  'laundry / dry cleaning': Icons.local_laundry_service,
  'moving costs': Icons.local_shipping,
  'storage': Icons.inventory_2,
  'clothing & shoes': Icons.checkroom,

  // Travel & Daily Transport
  'public transport': Icons.directions_transit,
  'taxi & ride apps': Icons.local_taxi,
  'fuel / gas': Icons.local_gas_station,
  'parking': Icons.local_parking,
  'tolls': Icons.toll,
  'car repairs': Icons.car_repair,
  'car insurance': Icons.verified_user,
  'car parts': Icons.build_circle,
  'car rental': Icons.directions_car,
  'bike / scooter': Icons.pedal_bike,
  'travel': Icons.flight_takeoff,
  'flights': Icons.flight,
  'hotels': Icons.hotel,
  'travel insurance': Icons.policy,
  'travel activities': Icons.local_activity,
  'luggage & travel gear': Icons.card_travel,
  'passport & visa fees': Icons.assignment_ind,

  // Health & Wellness
  'medical care': Icons.local_hospital,
  'pharmacy': Icons.local_pharmacy,
  'dental care': Icons.medical_services,
  'eye care': Icons.visibility,
  'mental health': Icons.self_improvement,
  'therapy': Icons.support_agent,
  'fitness & gym': Icons.fitness_center,
  'sports & exercise': Icons.sports_soccer,
  'supplements': Icons.medication,
  'personal care': Icons.spa,
  'beauty & cosmetics': Icons.brush,
  'spa & massage': Icons.spa,

  // Kids
  'childcare': Icons.child_care,
  'school supplies': Icons.backpack,
  'kids activities': Icons.toys,
  'kids clothing': Icons.checkroom,
  'toys & games': Icons.sports_esports,
  'baby supplies': Icons.child_friendly,

  // Pets
  'pet food': Icons.pets,
  'pet treats': Icons.fastfood,
  'vet visits': Icons.healing,
  'pet medicine': Icons.medical_services,
  'pet grooming': Icons.content_cut,
  'pet supplies': Icons.shopping_bag,
  'pet insurance': Icons.verified_user,
  'pet boarding / sitting': Icons.house_siding,

  // Work & Learning
  'work supplies': Icons.work,
  'home office': Icons.desktop_windows,
  'software tools': Icons.apps,
  'cloud storage': Icons.cloud,
  'courses & classes': Icons.class_,
  'books & study materials': Icons.menu_book,
  'exams & certificates': Icons.verified,
  'coworking space': Icons.meeting_room,
  'professional services': Icons.design_services,
  'business expenses': Icons.receipt_long,
  'ads & marketing': Icons.campaign,
  'licensing & fees': Icons.fact_check,

  // Fun & Social
  'movies & shows': Icons.movie,
  'music & streaming': Icons.music_note,
  'games & apps': Icons.sports_esports,
  'hobbies': Icons.brush,
  'crafts & art': Icons.palette,
  'sports clubs': Icons.sports_basketball,
  'concerts & events': Icons.event,
  'bars & drinks': Icons.local_bar,
  'dating': Icons.favorite,
  'parties & hosting': Icons.celebration,
  'gifts': Icons.card_giftcard,
  'charity': Icons.volunteer_activism,
  'collectibles': Icons.star,

  // Money In / Money Out
  'income': Icons.attach_money,
  'salary': Icons.payments,
  'bonus': Icons.card_giftcard,
  'tips': Icons.local_atm,
  'freelance income': Icons.computer,
  'rental income': Icons.house_siding,
  'interest income': Icons.ssid_chart,
  'gift': Icons.card_giftcard,
  'cashback': Icons.redeem,
  'pension': Icons.account_balance,
  'refunds': Icons.reply,
  'transfers': Icons.swap_horiz,
  'savings': Icons.savings,
  'investments': Icons.trending_up,
  'loan payments': Icons.account_balance,
  'debt payments': Icons.receipt_long,
  'bank fees': Icons.account_balance_wallet,
  'taxes': Icons.receipt_long,
  'fines': Icons.report,

  // Community & Services
  'government services': Icons.account_balance,
  'post & delivery': Icons.local_shipping,
  'religious & spiritual': Icons.self_improvement,
  'community events': Icons.event_available,
  'environmental / green': Icons.eco,

  // Misc
  'miscellaneous': Icons.widgets,
  'other': Icons.category,
  'uncategorized': Icons.help_outline,
};

Color getCategoryColor(String? category) {
  final key = normalizeCategory(category ?? 'uncategorized');
  final mapped = categoryColors[key];
  if (mapped != null) return mapped;

  final paletteIndex = key.hashCode.abs() % _fallbackPalette.length;
  return _fallbackPalette[paletteIndex];
}

IconData getCategoryIcon(String? category) {
  final key = normalizeCategory(category ?? 'uncategorized');
  return categoryIcons[key] ?? Icons.category;
}

/// Translates category names to localized strings
String getCategoryTranslation(BuildContext context, String? category) {
  final l10n = context.l10n;
  final key = normalizeCategory(category ?? 'uncategorized');

  final translations = <String, String>{
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

  return translations[key] ?? _titleCase(category ?? 'uncategorized');
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
  const incomeCategories = <String>[
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
  ];
  return incomeCategories;
}

/// Expense-only canonical categories (all allowed minus income-focused and umbrella 'income')
List<String> getExpenseCategories() {
  final incomeCats = {...getIncomeCategories(), 'income'};
  final keys = categoryColors.keys
      .where((k) => !incomeCats.contains(k))
      .toList();
  keys.sort((a, b) => a.compareTo(b));
  return keys;
}

/// Normalizes category names from external sources (AI, backend) to canonical categories
String normalizeCategory(String rawCategory) {
  final normalized = rawCategory.toLowerCase().trim();
  
  // Category mappings for common aliases
  const categoryMappings = <String, String>{
    'food': 'food & drinks',
    'food and drinks': 'food & drinks',
    'restaurant': 'restaurants',
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
    'transport': 'transportation',
    'uber': 'rideshare',
    'taxi': 'rideshare',
    'bus': 'public transit',
    'train': 'public transit',
    'subway': 'public transit',
    'metro': 'public transit',
    'gasoline': 'gas & fuel',
    'fuel': 'gas & fuel',
    'parking': 'parking',
    'tolls': 'tolls',
    'car': 'car maintenance',
    'auto': 'car maintenance',
    'insurance': 'insurance',
    'health': 'healthcare',
    'dental': 'healthcare',
    'vision': 'healthcare',
    'pharmacy': 'healthcare',
    'doctor': 'healthcare',
    'hospital': 'healthcare',
    'gym': 'fitness',
    'fitness': 'fitness',
    'sports': 'fitness',
    'education': 'education',
    'school': 'education',
    'university': 'education',
    'college': 'education',
    'course': 'education',
    'book': 'books & supplies',
    'books': 'books & supplies',
    'supplies': 'books & supplies',
    'clothing': 'clothing',
    'shoes': 'clothing',
    'accessories': 'clothing',
    'entertainment': 'entertainment',
    'movie': 'entertainment',
    'cinema': 'entertainment',
    'theater': 'entertainment',
    'concert': 'entertainment',
    'music': 'entertainment',
    'game': 'entertainment',
    'gaming': 'entertainment',
    'streaming': 'entertainment',
    'netflix': 'entertainment',
    'disney': 'entertainment',
    'travel': 'travel',
    'vacation': 'travel',
    'hotel': 'travel',
    'airbnb': 'travel',
    'flight': 'travel',
    'airline': 'travel',
    // map donation-related phrases to the existing expense category
    'donation': 'charity',
    'charity': 'charity',
    'pet': 'pets',
    'pet food': 'pets',
    'pet supplies': 'pets',
    'vet': 'pets',
    'personal': 'personal care',
    'haircut': 'personal care',
    'salon': 'personal care',
    'spa': 'personal care',
    'beauty': 'personal care',
    'cosmetics': 'personal care',
    'skincare': 'personal care',
    'bank': 'banking',
    'atm': 'banking',
    'fee': 'banking',
    'interest': 'banking',
    'tax': 'taxes',
    'government': 'taxes',
    'fine': 'taxes',
    'legal': 'legal',
    'lawyer': 'legal',
    'court': 'legal',
    'business': 'business expenses',
    'office': 'business expenses',
    'work': 'business expenses',
    'professional': 'business expenses',
  };
  
  // Direct mapping lookup
  if (categoryMappings.containsKey(normalized)) {
    return categoryMappings[normalized]!;
  }
  
  // Fuzzy matching for partial matches
  for (final entry in categoryMappings.entries) {
    if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
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
