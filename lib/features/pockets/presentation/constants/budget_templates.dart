import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// CORE MODEL
// -----------------------------------------------------------------------------

class PocketTemplate {
  String name;
  double weight; // relative share
  String iconName;
  List<String> suggestedCategories;
  Color? color;

  PocketTemplate({
    required this.name,
    required this.weight,
    required this.iconName,
    this.suggestedCategories = const [],
    this.color,
  });

  PocketTemplate copyWith({
    String? name,
    double? weight,
    String? iconName,
    List<String>? suggestedCategories,
    Color? color,
  }) {
    return PocketTemplate(
      name: name ?? this.name,
      weight: weight ?? this.weight,
      iconName: iconName ?? this.iconName,
      suggestedCategories: suggestedCategories ?? this.suggestedCategories,
      color: color ?? this.color,
    );
  }
}

class BudgetTemplate {
  final String id;
  final String translationKeyName;
  final String translationKeyDescription;
  final String iconName;
  final List<PocketTemplate> pockets;

  const BudgetTemplate({
    required this.id,
    required this.translationKeyName,
    required this.translationKeyDescription,
    required this.iconName,
    required this.pockets,
  });
}

// -----------------------------------------------------------------------------
// TEMPLATE LIBRARY
// -----------------------------------------------------------------------------

class BudgetTemplates {
  static List<BudgetTemplate> get all => [
        // --- Shared: Couples ---
        _coupleStandardDink,
        _coupleAggressiveSavings,
        _coupleDebtFocus,
        _coupleFoodies,
        _coupleNewHomeowners,
        _coupleTravelMode,

        // --- Shared: Household/Family ---
        _familyStandard2Kids,
        _familySingleIncome,
        _familyPetLovers,
        _familyHealthFocus,
        _familyActiveKids,
        _familySocialHosts,

        // --- Shared: Housemates/Friends ---
        _matesSplitEssentials,
        _matesPartyHouse,
        _matesDigitalNomads,
        _matesStudentDorm,
        _matesCommunalLiving,
        _matesMinimalist,

        // --- Personal: Specialty ---
        _personalFreelancer,
        _personalStudentLean,
        _personalLuxury,
        _personalCarCommuter,
        _personalBiohacker,
        _personalTechGamer,
      ];

  // ===========================================================================
  // GROUP 1: SHARED - COUPLES
  // ===========================================================================

  static final _coupleStandardDink = BudgetTemplate(
    id: 'couple_dink',
    translationKeyName: 'template_couple_dink_title',
    translationKeyDescription:
        'template_couple_dink_desc', // "Dual income, no kids. Balanced 50/30/20 approach."
    iconName: 'home_work', // Couples/Home
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'house',
        suggestedCategories: [
          'rent',
          'electricity',
          'water',
          'internet',
          'groceries',
          'household supplies'
        ],
        color: const Color(0xFFEF4444), // Red
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.25,
        iconName: 'local_bar',
        suggestedCategories: [
          'restaurants',
          'movies & shows',
          'concerts & events',
          'travel',
          'bars & drinks'
        ],
        color: const Color(0xFF8B5CF6), // Purple
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.20,
        iconName: 'trending_up',
        suggestedCategories: ['savings', 'investments', 'emergency fund'],
        color: const Color(0xFF10B981), // Green
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _coupleAggressiveSavings = BudgetTemplate(
    id: 'couple_fire',
    translationKeyName: 'template_couple_fire_title',
    translationKeyDescription:
        'template_couple_fire_desc', // "High savings rate for early retirement or a big purchase."
    iconName: 'savings', // Aggressive Savings
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.40,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['rent', 'groceries', 'transport', 'utilities'],
        color: const Color(0xFF607D8B), // BlueGrey
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.45,
        iconName: 'savings',
        suggestedCategories: ['investments', 'savings', 'pension'],
        color: const Color(0xFF10B981), // Green
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.10,
        iconName: 'coffee',
        suggestedCategories: ['coffee & tea', 'snacks', 'music & streaming'],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _coupleDebtFocus = BudgetTemplate(
    id: 'couple_debt_free',
    translationKeyName: 'template_couple_debt_title',
    translationKeyDescription:
        'template_couple_debt_desc', // "Prioritizing paying off loans over luxury."
    iconName: 'credit_card', // Debt focus
    pockets: [
      PocketTemplate(
        name: 'Debt Payoff',
        weight: 0.40,
        iconName: 'delete_outline',
        suggestedCategories: ['debt payments', 'loan payments', 'credit card'],
        color: const Color(0xFFB91C1C), // Dark Red
      ),
      PocketTemplate(
        name: 'Essentials',
        weight: 0.45,
        iconName: 'shield',
        suggestedCategories: ['rent', 'groceries', 'electricity', 'fuel / gas'],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.10,
        iconName: 'self_improvement',
        suggestedCategories: ['hobbies', 'music & streaming'],
        color: const Color(0xFFA855F7), // Purple
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _coupleFoodies = BudgetTemplate(
    id: 'couple_foodies',
    translationKeyName: 'template_couple_foodies_title',
    translationKeyDescription:
        'template_couple_foodies_desc', // "For couples who love dining out and cooking high-end meals."
    iconName: 'restaurant', // Foodies
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.45,
        iconName: 'house',
        suggestedCategories: ['rent', 'utilities', 'internet'],
        color: const Color(0xFF9CA3AF), // Grey
      ),
      PocketTemplate(
        name: 'Groceries',
        weight: 0.25,
        iconName: 'kitchen',
        suggestedCategories: ['groceries', 'kitchen supplies'],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Eating Out',
        weight: 0.20,
        iconName: 'restaurant',
        suggestedCategories: [
          'restaurants',
          'bars & drinks',
          'coffee & tea',
          'takeout & delivery'
        ],
        color: const Color(0xFFEC4899), // Pink
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.10,
        iconName: 'savings',
        suggestedCategories: ['savings', 'miscellaneous'],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _coupleNewHomeowners = BudgetTemplate(
    id: 'couple_homeowners',
    translationKeyName: 'template_couple_home_title',
    translationKeyDescription:
        'template_couple_home_desc', // "Heavy mortgage and home repair focus."
    iconName: 'home', // Homeowners
    pockets: [
      PocketTemplate(
        name: 'Home & Bills',
        weight: 0.55,
        iconName: 'house_siding',
        suggestedCategories: [
          'mortgage',
          'property tax',
          'home insurance',
          'electricity',
          'water',
          'heating & gas'
        ],
        color: const Color(0xFF1E3A8A), // Dark Blue
      ),
      PocketTemplate(
        name: 'Home Maintenance',
        weight: 0.15,
        iconName: 'build_circle',
        suggestedCategories: [
          'home repairs',
          'furniture',
          'home decor',
          'tools',
          'garden'
        ],
        color: const Color(0xFFE91E63), // Pink
      ),
      PocketTemplate(
        name: 'Everyday Essentials',
        weight: 0.20,
        iconName: 'local_grocery_store',
        suggestedCategories: ['groceries', 'transport', 'personal care'],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.10,
        iconName: 'savings',
        suggestedCategories: ['savings'],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _coupleTravelMode = BudgetTemplate(
    id: 'couple_travel',
    translationKeyName: 'template_couple_travel_title',
    translationKeyDescription:
        'template_couple_travel_desc', // "Saving up for a big trip or currently traveling."
    iconName: 'flight', // Travel
    pockets: [
      PocketTemplate(
        name: 'Travel Fund',
        weight: 0.40,
        iconName: 'flight_takeoff',
        suggestedCategories: [
          'flights',
          'hotels',
          'travel activities',
          'travel insurance',
          'passport & visa fees'
        ],
        color: const Color(0xFF0EA5E9), // Sky Blue
      ),
      PocketTemplate(
        name: 'Home & Bills',
        weight: 0.40,
        iconName: 'home',
        suggestedCategories: ['rent', 'storage', 'insurance', 'phone bill'],
        color: const Color(0xFF64748B), // Slate
      ),
      PocketTemplate(
        name: 'Travel Spending',
        weight: 0.15,
        iconName: 'backpack',
        suggestedCategories: [
          'restaurants',
          'public transport',
          'luggage & travel gear'
        ],
        color: const Color(0xFFF43F5E), // Rose
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  // ===========================================================================
  // GROUP 2: SHARED - HOUSEHOLD/FAMILY
  // ===========================================================================

  static final _familyStandard2Kids = BudgetTemplate(
    id: 'family_balanced',
    translationKeyName: 'template_family_bal_title',
    translationKeyDescription:
        'template_family_bal_desc', // "Typical family budget with kids expenses."
    iconName: 'family_restroom', // Family
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'house',
        suggestedCategories: [
          'mortgage',
          'groceries',
          'utilities',
          'car insurance',
          'fuel / gas'
        ],
        color: const Color(0xFF1F2937), // Dark Grey
      ),
      PocketTemplate(
        name: 'Kids',
        weight: 0.20,
        iconName: 'child_care',
        suggestedCategories: [
          'school supplies',
          'kids clothing',
          'kids activities',
          'toys & games'
        ],
        color: const Color(0xFFFF9800), // Orange
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.15,
        iconName: 'weekend',
        suggestedCategories: [
          'restaurants',
          'family outings',
          'streaming services'
        ],
        color: const Color(0xFF8B5CF6), // Violet
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.15,
        iconName: 'savings',
        suggestedCategories: [
          'savings',
          'investments',
          'emergency fund',
          'miscellaneous'
        ],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _familySingleIncome = BudgetTemplate(
    id: 'family_single_income',
    translationKeyName: 'template_family_single_title',
    translationKeyDescription:
        'template_family_single_desc', // "Tight budget for families on one salary."
    iconName: 'warning', // Tight budget/Alert
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.70,
        iconName: 'priority_high',
        suggestedCategories: [
          'rent',
          'groceries',
          'utilities',
          'medical care',
          'transport'
        ],
        color: const Color(0xFFDC2626), // Red
      ),
      PocketTemplate(
        name: 'Kids Needs',
        weight: 0.15,
        iconName: 'child_friendly',
        suggestedCategories: [
          'baby supplies',
          'kids clothing',
          'school supplies'
        ],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.10,
        iconName: 'shield',
        suggestedCategories: ['savings', 'emergency fund'],
        color: const Color(0xFF10B981), // Green
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.05,
        iconName: 'favorite',
        suggestedCategories: ['movies & shows', 'parks', 'library'],
        color: const Color(0xFFEC4899), // Pink
      ),
    ],
  );

  static final _familyPetLovers = BudgetTemplate(
    id: 'family_pets',
    translationKeyName: 'template_family_pets_title',
    translationKeyDescription:
        'template_family_pets_desc', // "Household with multiple pets and related costs."
    iconName: 'pets', // Pets
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'home',
        suggestedCategories: ['rent', 'groceries', 'utilities'],
        color: const Color(0xFF4B5563), // Grey
      ),
      PocketTemplate(
        name: 'Pets',
        weight: 0.25,
        iconName: 'pets',
        suggestedCategories: [
          'pet food',
          'vet visits',
          'pet insurance',
          'pet grooming',
          'pet medicine'
        ],
        color: const Color(0xFFD97706), // Amber-700
      ),
      PocketTemplate(
        name: 'Everyday Spending',
        weight: 0.15,
        iconName: 'shopping_bag',
        suggestedCategories: ['transport', 'clothing & shoes', 'personal care'],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.10,
        iconName: 'savings',
        suggestedCategories: ['savings', 'emergency fund', 'miscellaneous'],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _familyHealthFocus = BudgetTemplate(
    id: 'family_health',
    translationKeyName: 'template_family_health_title',
    translationKeyDescription:
        'template_family_health_desc', // "High medical needs, therapy, or pregnancy."
    iconName: 'medical_services', // Health
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.45,
        iconName: 'house',
        suggestedCategories: [
          'mortgage',
          'utilities',
          'groceries',
          'phone bill'
        ],
        color: const Color(0xFF64748B), // Slate
      ),
      PocketTemplate(
        name: 'Healthcare',
        weight: 0.30,
        iconName: 'medical_services',
        suggestedCategories: [
          'medical care',
          'pharmacy',
          'therapy',
          'health insurance',
          'specialists'
        ],
        color: const Color(0xFFEF4444), // Red
      ),
      PocketTemplate(
        name: 'Wellness',
        weight: 0.15,
        iconName: 'healing',
        suggestedCategories: [
          'supplements',
          'healthy food',
          'fitness & gym',
          'spa & massage'
        ],
        color: const Color(0xFF8B5CF6), // Violet
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.10,
        iconName: 'account_balance',
        suggestedCategories: ['savings'],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _familyActiveKids = BudgetTemplate(
    id: 'family_active',
    translationKeyName: 'template_family_active_title',
    translationKeyDescription:
        'template_family_active_desc', // "Sports, music lessons, and clubs dominate."
    iconName: 'sports_soccer', // Active kids
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'house',
        suggestedCategories: ['rent', 'groceries', 'utilities'],
        color: const Color(0xFF374151), // Dark Grey
      ),
      PocketTemplate(
        name: 'Activities',
        weight: 0.30,
        iconName: 'sports_soccer',
        suggestedCategories: [
          'sports clubs',
          'courses & classes',
          'sports & exercise',
          'kids clothing'
        ],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Transport',
        weight: 0.10,
        iconName: 'directions_car',
        suggestedCategories: ['fuel / gas', 'parking', 'tolls', 'car repairs'],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.10,
        iconName: 'savings',
        suggestedCategories: ['savings', 'emergency fund', 'miscellaneous'],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _familySocialHosts = BudgetTemplate(
    id: 'family_hosts',
    translationKeyName: 'template_family_host_title',
    translationKeyDescription:
        'template_family_host_desc', // "Frequent parties, guests, and community events."
    iconName: 'celebration', // Hosts
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.45,
        iconName: 'house',
        suggestedCategories: [
          'mortgage',
          'utilities',
          'cleaning supplies',
          'home services'
        ],
        color: const Color(0xFF57534E), // Stone
      ),
      PocketTemplate(
        name: 'Food & Hosting',
        weight: 0.35,
        iconName: 'celebration',
        suggestedCategories: [
          'groceries',
          'alcohol',
          'parties & hosting',
          'gifts',
          'decor'
        ],
        color: const Color(0xFFEC4899), // Pink
      ),
      PocketTemplate(
        name: 'Family Needs',
        weight: 0.10,
        iconName: 'people',
        suggestedCategories: ['kids activities', 'clothing & shoes'],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.10,
        iconName: 'savings',
        suggestedCategories: ['savings', 'emergency fund', 'miscellaneous'],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  // ===========================================================================
  // GROUP 3: SHARED - HOUSEMATES/FRIENDS
  // ===========================================================================

  static final _matesSplitEssentials = BudgetTemplate(
    id: 'mates_split',
    translationKeyName: 'template_mates_split_title',
    translationKeyDescription:
        'template_mates_split_desc', // "Strictly shared bills. Personal spending is private."
    iconName: 'receipt_long', // Split bills
    pockets: [
      PocketTemplate(
        name: 'Shared Bills',
        weight: 0.80,
        iconName: 'receipt_long',
        suggestedCategories: [
          'rent',
          'electricity',
          'water',
          'heating & gas',
          'internet'
        ],
        color: const Color(0xFF1E40AF), // Dark Blue
      ),
      PocketTemplate(
        name: 'Shared Supplies',
        weight: 0.20,
        iconName: 'cleaning_services',
        suggestedCategories: [
          'household supplies',
          'cleaning supplies',
          'trash & recycling'
        ],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _matesPartyHouse = BudgetTemplate(
    id: 'mates_party',
    translationKeyName: 'template_mates_party_title',
    translationKeyDescription:
        'template_mates_party_desc', // "Budget for a social house with shared entertainment."
    iconName: 'party_mode', // Party house
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'house',
        suggestedCategories: ['rent', 'utilities', 'internet'],
        color: const Color(0xFF475569), // Slate
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.25,
        iconName: 'local_bar',
        suggestedCategories: [
          'bars & drinks',
          'parties & hosting',
          'games & apps',
          'music & streaming'
        ],
        color: const Color(0xFF8B5CF6), // Violet
      ),
      PocketTemplate(
        name: 'Food & Drinks',
        weight: 0.20,
        iconName: 'fastfood',
        suggestedCategories: ['takeout & delivery', 'snacks', 'soda'],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _matesDigitalNomads = BudgetTemplate(
    id: 'mates_nomads',
    translationKeyName: 'template_mates_nomads_title',
    translationKeyDescription:
        'template_mates_nomads_desc', // "Remote workers sharing a workspace/home."
    iconName: 'wifi', // Digital nomads/Work
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'hotel',
        suggestedCategories: [
          'rent',
          'cleaning services',
          'laundry / dry cleaning'
        ],
        color: const Color(0xFF607D8B), // BlueGrey
      ),
      PocketTemplate(
        name: 'Work',
        weight: 0.25,
        iconName: 'wifi',
        suggestedCategories: [
          'internet',
          'coworking space',
          'coffee & tea',
          'software tools'
        ],
        color: const Color(0xFF2563EB), // Blue
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.20,
        iconName: 'map',
        suggestedCategories: [
          'travel',
          'restaurants',
          'transport',
          'activities'
        ],
        color: const Color(0xFFF43F5E), // Rose
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _matesStudentDorm = BudgetTemplate(
    id: 'mates_student',
    translationKeyName: 'template_mates_student_title',
    translationKeyDescription:
        'template_mates_student_desc', // "Low budget student living."
    iconName: 'school', // Student
    pockets: [
      PocketTemplate(
        name: 'Rent & Internet',
        weight: 0.60,
        iconName: 'apartment',
        suggestedCategories: ['rent', 'internet'],
        color: const Color(0xFFEF4444), // Red
      ),
      PocketTemplate(
        name: 'Groceries',
        weight: 0.25,
        iconName: 'ramen_dining',
        suggestedCategories: ['groceries', 'snacks', 'coffee & tea'],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Personal Essentials',
        weight: 0.10,
        iconName: 'soap',
        suggestedCategories: [
          'laundry / dry cleaning',
          'cleaning supplies',
          'toiletries'
        ],
        color: const Color(0xFF10B981), // Green
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _matesCommunalLiving = BudgetTemplate(
    id: 'mates_communal',
    translationKeyName: 'template_mates_communal_title',
    translationKeyDescription:
        'template_mates_communal_desc', // "Co-op style with heavy shared groceries and events."
    iconName: 'group', // Communal/Group
    pockets: [
      PocketTemplate(
        name: 'Home & Bills',
        weight: 0.40,
        iconName: 'house',
        suggestedCategories: ['rent', 'utilities', 'garden', 'home repairs'],
        color: const Color(0xFF57534E), // Stone
      ),
      PocketTemplate(
        name: 'Groceries',
        weight: 0.35,
        iconName: 'local_grocery_store',
        suggestedCategories: [
          'groceries',
          'household supplies',
          'community events'
        ],
        color: const Color(0xFF10B981), // Green
      ),
      PocketTemplate(
        name: 'Shared Stuff',
        weight: 0.20,
        iconName: 'inventory_2',
        suggestedCategories: ['pet food', 'tools', 'appliances'],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _matesMinimalist = BudgetTemplate(
    id: 'mates_minimalist',
    translationKeyName: 'template_mates_min_title',
    translationKeyDescription:
        'template_mates_min_desc', // "Just rent and utilities. Nothing else."
    iconName: 'remove', // Minimalist
    pockets: [
      PocketTemplate(
        name: 'Rent',
        weight: 0.75,
        iconName: 'house',
        suggestedCategories: ['rent'],
        color: const Color(0xFF1F2937), // Dark Grey
      ),
      PocketTemplate(
        name: 'Utilities',
        weight: 0.25,
        iconName: 'bolt',
        suggestedCategories: [
          'electricity',
          'water',
          'internet',
          'heating & gas'
        ],
        color: const Color(0xFFFBBF24), // Amber
      ),
    ],
  );

  // ===========================================================================
  // GROUP 4: PERSONAL - SPECIALTY
  // ===========================================================================

  static final _personalFreelancer = BudgetTemplate(
    id: 'personal_freelancer',
    translationKeyName: 'template_pers_freelancer_title',
    translationKeyDescription:
        'template_pers_freelancer_desc', // "Variable income management with tax holding."
    iconName: 'work', // Freelancer/Work
    pockets: [
      PocketTemplate(
        name: 'Taxes (Set Aside)',
        weight: 0.25,
        iconName: 'policy',
        suggestedCategories: ['taxes', 'licensing & fees'],
        color: const Color(0xFFDC2626), // Red
      ),
      PocketTemplate(
        name: 'Business',
        weight: 0.15,
        iconName: 'work',
        suggestedCategories: [
          'software tools',
          'home office',
          'professional services',
          'ads & marketing'
        ],
        color: const Color(0xFF2563EB), // Blue
      ),
      PocketTemplate(
        name: 'Essentials',
        weight: 0.40,
        iconName: 'house',
        suggestedCategories: ['rent', 'groceries', 'utilities', 'transport'],
        color: const Color(0xFF4B5563), // Grey
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.20,
        iconName: 'savings',
        suggestedCategories: ['savings', 'emergency fund', 'miscellaneous'],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _personalStudentLean = BudgetTemplate(
    id: 'personal_student',
    translationKeyName: 'template_pers_student_title',
    translationKeyDescription:
        'template_pers_student_desc', // "University focused. High tuition/books, low extras."
    iconName: 'school', // Student
    pockets: [
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'house',
        suggestedCategories: ['rent', 'groceries', 'transport'],
        color: const Color(0xFFEF4444), // Red
      ),
      PocketTemplate(
        name: 'Tuition & Books',
        weight: 0.35,
        iconName: 'school',
        suggestedCategories: [
          'books & study materials',
          'courses & classes',
          'tuition'
        ],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Fun Money',
        weight: 0.10,
        iconName: 'people',
        suggestedCategories: ['bars & drinks', 'coffee & tea'],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _personalLuxury = BudgetTemplate(
    id: 'personal_luxury',
    translationKeyName: 'template_pers_luxury_title',
    translationKeyDescription:
        'template_pers_luxury_desc', // "High earner enjoying lifestyle and self-care."
    iconName: 'diamond', // Luxury
    pockets: [
      PocketTemplate(
        name: 'Lifestyle',
        weight: 0.40,
        iconName: 'diamond',
        suggestedCategories: [
          'clothing & shoes',
          'restaurants',
          'travel',
          'hobbies'
        ],
        color: const Color(0xFF8B5CF6), // Violet
      ),
      PocketTemplate(
        name: 'Self Care',
        weight: 0.20,
        iconName: 'spa',
        suggestedCategories: [
          'spa & massage',
          'beauty & cosmetics',
          'personal care',
          'fitness & gym'
        ],
        color: const Color(0xFFEC4899), // Pink
      ),
      PocketTemplate(
        name: 'Essentials',
        weight: 0.20,
        iconName: 'house',
        suggestedCategories: ['rent', 'utilities', 'bills'],
        color: const Color(0xFF9CA3AF), // Grey
      ),
      PocketTemplate(
        name: 'Goals',
        weight: 0.20,
        iconName: 'trending_up',
        suggestedCategories: [
          'investments',
          'savings',
          'emergency fund',
          'miscellaneous'
        ],
        color: const Color(0xFF10B981), // Green
      ),
    ],
  );

  static final _personalCarCommuter = BudgetTemplate(
    id: 'personal_commuter',
    translationKeyName: 'template_pers_car_title',
    translationKeyDescription:
        'template_pers_car_desc', // "Heavy travel/commute costs."
    iconName: 'directions_car', // Commuter
    pockets: [
      PocketTemplate(
        name: 'Car',
        weight: 0.35,
        iconName: 'directions_car',
        suggestedCategories: [
          'fuel / gas',
          'car insurance',
          'car repairs',
          'tolls',
          'parking',
          'car wash'
        ],
        color: const Color(0xFFDC2626), // Red
      ),
      PocketTemplate(
        name: 'Essentials',
        weight: 0.45,
        iconName: 'house',
        suggestedCategories: ['rent', 'groceries', 'utilities'],
        color: const Color(0xFF4B5563), // Grey
      ),
      PocketTemplate(
        name: 'Car Replacement',
        weight: 0.15,
        iconName: 'savings',
        suggestedCategories: ['savings'],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _personalBiohacker = BudgetTemplate(
    id: 'personal_biohacker',
    translationKeyName: 'template_pers_bio_title',
    translationKeyDescription:
        'template_pers_bio_desc', // "Fitness, supplements, and organic food focus."
    iconName: 'fitness_center', // Biohacker/Fitness
    pockets: [
      PocketTemplate(
        name: 'Fitness & Wellness',
        weight: 0.40,
        iconName: 'fitness_center',
        suggestedCategories: [
          'fitness & gym',
          'supplements',
          'sports & exercise',
          'wearables',
          'coaching'
        ],
        color: const Color(0xFF10B981), // Green
      ),
      PocketTemplate(
        name: 'Groceries',
        weight: 0.30,
        iconName: 'local_grocery_store',
        suggestedCategories: ['groceries', 'healthy food', 'meal prep'],
        color: const Color(0xFFF59E0B), // Amber
      ),
      PocketTemplate(
        name: 'Essentials',
        weight: 0.25,
        iconName: 'house',
        suggestedCategories: ['rent', 'utilities', 'transport'],
        color: const Color(0xFF64748B), // Slate
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );

  static final _personalTechGamer = BudgetTemplate(
    id: 'personal_gamer',
    translationKeyName: 'template_pers_gamer_title',
    translationKeyDescription:
        'template_pers_gamer_desc', // "Priority on tech, games, and digital services."
    iconName: 'sports_esports', // Gamer/Tech
    pockets: [
      PocketTemplate(
        name: 'Games & Tech',
        weight: 0.25,
        iconName: 'sports_esports',
        suggestedCategories: [
          'games & apps',
          'electronics',
          'software tools',
          'cloud storage',
          'music & streaming'
        ],
        color: const Color(0xFF8B5CF6), // Violet
      ),
      PocketTemplate(
        name: 'Essentials',
        weight: 0.50,
        iconName: 'house',
        suggestedCategories: [
          'rent',
          'internet',
          'electricity',
          'groceries',
          'takeout & delivery'
        ],
        color: const Color(0xFF1F2937), // Dark Grey
      ),
      PocketTemplate(
        name: 'Upgrades',
        weight: 0.20,
        iconName: 'savings',
        suggestedCategories: ['savings'],
        color: const Color(0xFF3B82F6), // Blue
      ),
      PocketTemplate(
        name: 'Buffer',
        weight: 0.05,
        iconName: 'account_balance_wallet',
        suggestedCategories: ['miscellaneous', 'emergency fund', 'savings'],
        color: const Color(0xFF64748B), // Slate
      ),
    ],
  );
}
