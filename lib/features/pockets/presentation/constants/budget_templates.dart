import 'package:flutter/material.dart';

// Modern Muted Color Palette System
// Low-saturation, soft colors for a cohesive visual experience

class TemplateColors {
  // Rich Blue - Serene & Trustworthy (Stronger visibility)
  static const List<Color> softBlue = [
    Color(0xFF5D87FF), // Primary Rich Blue (Mid-tone)
    Color(0xFF4570EA), // Deep Blue Accent
    Color(0xFF7CA1FF), // Lighter Blue (Visible)
    Color(0xFFECF2FF), // Very Light Tint (Backgrounds)
    Color(0xFF2A52BE), // Strong Emphasis
  ];

  // Deep Sage - Nature & Balance (More distinct from Teal/Gray)
  static const List<Color> gentleSage = [
    Color(0xFF4CA684), // Primary Deep Sage
    Color(0xFF388E6E), // Darker Green Accent
    Color(0xFF7BC4A9), // Soft Green (Visible)
    Color(0xFFE6F6EF), // Very Light Tint
    Color(0xFF2D6A53), // Strong Forest
  ];

  // Warm Terracotta - Earthy & Grounded (Distinct Orange-Brown)
  static const List<Color> warmTerracotta = [
    Color(0xFFE07A5F), // Primary Terra
    Color(0xFFCC6245), // Deep Brick
    Color(0xFFF29B85), // Soft Clay
    Color(0xFFFFF0EB), // Very Light Tint
    Color(0xFF9C3E26), // Strong Earth
  ];

  // Rich Lavender - Dreamy & Creative (Purple, not Lilac)
  static const List<Color> softLavender = [
    Color(0xFF9D84D9), // Primary Lavender
    Color(0xFF8366C9), // Deep Violet
    Color(0xFFBCA6EB), // Soft Purple
    Color(0xFFF2EFFF), // Very Light Tint
    Color(0xFF6246A3), // Strong Purple
  ];

  // Solid Teal - Fresh & Clean (Distinct from Blue/Green)
  static const List<Color> mutedTeal = [
    Color(0xFF2A9D8F), // Primary Teal
    Color(0xFF20877B), // Deep Teal
    Color(0xFF64C2B6), // Soft Aqua
    Color(0xFFE0F5F3), // Very Light Tint
    Color(0xFF165951), // Dark Teal
  ];

  // Dusty Rose - Warm & Gentle (Distinct Pink)
  static const List<Color> dustyRose = [
    Color(0xFFD66A84), // Primary Rose
    Color(0xFFBF4E6A), // Deep Berry
    Color(0xFFE894A8), // Soft Pink
    Color(0xFFFFF0F3), // Very Light Tint
    Color(0xFF9E2A46), // Strong Magenta
  ];

  // Golden Amber - Bright & Optimistic (Yellow-Orange)
  static const List<Color> softAmber = [
    Color(0xFFE9C46A), // Primary Gold
    Color(0xFFD4AF37), // Deep Ochre
    Color(0xFFF4D58D), // Soft Yellow
    Color(0xFFFFFBEB), // Very Light Tint
    Color(0xFFA67C00), // Strong Bronze
  ];

  // Slate Gray - Minimal & Sleek (Neutral but visible)
  static const List<Color> coolGray = [
    Color(0xFF6C757D), // Primary Slate
    Color(0xFF495057), // Dark Slate
    Color(0xFFADB5BD), // Soft Gray
    Color(0xFFF8F9FA), // Very Light Tint
    Color(0xFF343A40), // Dark Charcoal
  ];

  // Deep Indigo - Deep & Stable (Distinct Blue-Purple)
  static const List<Color> mutedIndigo = [
    Color(0xFF6F74DD), // Primary Indigo
    Color(0xFF535AC8), // Deep Indigo
    Color(0xFF9499F0), // Soft Indigo
    Color(0xFFEEF0FC), // Very Light Tint
    Color(0xFF3C4299), // Strong Navy
  ];

  // Vibrant Coral - Vibrant & Alert (Red-Orange, distinct from Rose)
  static const List<Color> softCoral = [
    Color(0xFFFF8A65), // Primary Coral
    Color(0xFFFF7043), // Deep Orange-Red
    Color(0xFFFFAB91), // Soft Peach-Red
    Color(0xFFFFF3E0), // Very Light Tint
    Color(0xFFD84315), // Strong Burnt
  ];
}

// -----------------------------------------------------------------------------
// CORE MODEL
// -----------------------------------------------------------------------------

class PocketTemplate {
  String name;
  double percentage; // 0.0 to 1.0
  String iconName;
  List<String> suggestedCategories;
  Color? color;

  PocketTemplate({
    required this.name,
    required this.percentage,
    required this.iconName,
    List<String> suggestedCategories = const [],
    this.color,
  }) : suggestedCategories =
            _canonicalizeTemplateCategories(suggestedCategories);

  PocketTemplate copyWith({
    String? name,
    double? percentage,
    String? iconName,
    List<String>? suggestedCategories,
    Color? color,
  }) {
    return PocketTemplate(
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
      iconName: iconName ?? this.iconName,
      suggestedCategories: suggestedCategories ?? this.suggestedCategories,
      color: color ?? this.color,
    );
  }
}

List<String> _canonicalizeTemplateCategories(List<String> rawCategories) {
  // IMPORTANT: CategoryPickerBottomSheet is typically fed expense-only
  // categories. If we store income-only keys (e.g. salary/income/investments)
  // in a template, they won't render as selected and can't be edited.
  final incomeKeys = <String>{
    'salary',
    'paycheck',
    'income',
    'investments',
    'freelance',
    'business'
  };

  const directAliases = <String, String>{
    // Common template terms -> canonical categories
    'subscriptions': 'music & streaming',
    'streaming': 'music & streaming',
    'netflix': 'music & streaming',
    'spotify': 'music & streaming',
    'disney+': 'music & streaming',
    'groceries': 'groceries',
    'grocery': 'groceries',
    'food': 'groceries',
    'restaurant': 'eating out',
    'restaurants': 'eating out',
    'dining': 'eating out',
    'takeout': 'eating out',
    'delivery': 'eating out',
    'gas': 'transportation',
    'fuel': 'transportation',
    'gasoline': 'transportation',
    'car': 'transportation',
    'auto': 'transportation',
    'insurance': 'insurance',
    'utilities': 'utilities',
    'electric': 'utilities',
    'electricity': 'utilities',
    'water': 'utilities',
    'phone': 'phone',
    'internet': 'internet',
    'cell phone': 'phone',
    'mobile': 'phone',
    'mortgage': 'housing',
    'rent': 'housing',
    'housing': 'housing',
    'medical': 'healthcare',
    'health': 'healthcare',
    'healthcare': 'healthcare',
    'doctor': 'healthcare',
    'dental': 'healthcare',
    'gym': 'fitness',
    'fitness': 'fitness',
    'exercise': 'fitness',
    'savings': 'savings',
    'emergency fund': 'savings',
    'emergency': 'savings',
    'retirement': 'savings',
    'investing': 'savings',
    'investments': 'savings',
    'debt': 'debt',
    'loan': 'debt',
    'credit card': 'debt',
    'student loan': 'debt',
    'car loan': 'debt',
    'personal loan': 'debt',
    'education': 'education',
    'school': 'education',
    'tuition': 'education',
    'college': 'education',
    'university': 'education',
    'childcare': 'kids',
    'kids': 'kids',
    'children': 'kids',
    'child': 'kids',
    'baby': 'kids',
    'pets': 'pets',
    'pet': 'pets',
    'dog': 'pets',
    'cat': 'pets',
    'vet': 'pets',
    'veterinary': 'pets',
    'clothing': 'clothing',
    'clothes': 'clothing',
    'apparel': 'clothing',
    'shoes': 'clothing',
    'shopping': 'shopping',
    'amazon': 'shopping',
    'electronics': 'shopping',
    'travel': 'travel',
    'vacation': 'travel',
    'trip': 'travel',
    'holiday': 'travel',
    'entertainment': 'entertainment',
    'movies': 'entertainment',
    'concerts': 'entertainment',
    'sports': 'entertainment',
    'tickets': 'entertainment',
    'games': 'entertainment',
    'gaming': 'entertainment',
    'books': 'entertainment',
    'music': 'entertainment',
    'hobbies': 'entertainment',
    'gifts': 'gifts',
    'gift': 'gifts',
    'charity': 'giving',
    'charitable': 'giving',
    'donation': 'giving',
    'donations': 'giving',
    'church': 'giving',
    'tithing': 'giving',
    'home': 'home improvement',
    'home improvement': 'home improvement',
    'maintenance': 'home improvement',
    'repairs': 'home improvement',
    'furniture': 'home improvement',
    'decor': 'home improvement',
    'garden': 'home improvement',
    'yard': 'home improvement',
    'office': 'work',
    'work': 'work',
    'business': 'work',
    'professional': 'work',
    'career': 'work',
    'commuting': 'transportation',
    'public transit': 'transportation',
    'bus': 'transportation',
    'train': 'transportation',
    'subway': 'transportation',
    'uber': 'transportation',
    'lyft': 'transportation',
    'taxi': 'transportation',
    'parking': 'transportation',
    'tolls': 'transportation',
    'car maintenance': 'transportation',
    'auto repair': 'transportation',
    'oil change': 'transportation',
    'car wash': 'transportation',
    'registration': 'transportation',
    'inspection': 'transportation',
    'haircut': 'personal care',
    'hair': 'personal care',
    'salon': 'personal care',
    'barber': 'personal care',
    'spa': 'personal care',
    'personal care': 'personal care',
    'toiletries': 'personal care',
    'cosmetics': 'personal care',
    'skincare': 'personal care',
    'pharmacy': 'healthcare',
    'prescription': 'healthcare',
    'medicine': 'healthcare',
    'drugs': 'healthcare',
    'eyeglasses': 'healthcare',
    'contacts': 'healthcare',
    'orthodontist': 'healthcare',
    'chiropractor': 'healthcare',
    'therapy': 'healthcare',
    'mental health': 'healthcare',
    'counseling': 'healthcare',
    'psychologist': 'healthcare',
    'psychiatrist': 'healthcare',
    'social security': 'income',
    'pension': 'income',
    'annuity': 'income',
    'dividends': 'income',
    'interest': 'income',
    'capital gains': 'income',
    'rental income': 'income',
    'royalties': 'income',
    'side hustle': 'income',
    'tips': 'income',
    'bonus': 'income',
    'commission': 'income',
    'overtime': 'income',
  };

  final result = <String>[];
  final seen = <String>{};

  for (final raw in rawCategories) {
    final lower = raw.toLowerCase().trim();
    final preMapped = directAliases[lower];
    final normalized = preMapped ?? raw;
    final expenseSafe =
        incomeKeys.contains(normalized) ? 'savings' : normalized;
    final canonical = expenseSafe.isNotEmpty ? expenseSafe : 'other';
    if (seen.add(canonical)) {
      result.add(canonical);
    }
  }

  return result;
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
// TEMPLATE LIBRARY (COMMUNITY INSPIRED)
// -----------------------------------------------------------------------------

class BudgetTemplates {
  static List<BudgetTemplate> get all => [
        _ynabTeachYnab,
        _ynabNewPuppy,
        _ynabFamily,
        _ynabKid,
        _ynabABetterEmergencyFund,
        _ynabDebtPayoff,
        _ynabHappiness,
        _ynabChristmas,
        _ynabJobLayoff,
        _ynabNonMonthlyExpenses,
        _ynabRockretirementclub,
        _ynabTravel,
        _ynabYnabBeginnerTemplate,
        _ynabDivorce,
        _ynabNavigatingLoss,
        _ynabNewBaby,
        _ynabRecentlyGraduated,
        _ynabWedding,
        _ynabBuyingAHome,
        _ynabDisasterPrep,
        _ynabHomeProject,
        _ynabHouseProjectsQueue,
        _ynabKitchenRemodel,
        _ynabMoving,
        _ynabCollege,
        _ynabDisney,
        _ynabTeen,
        _ynabFood,
        _ynabMinimalistYnab,
        _ynabNewYearsResolutions,
        _ynabNickTruesStarterTemplate,
        _ynabNickTruesValuesTemplate,
        _ynabVariableIncome,
        _ynabWishFarm,
      ];

  static final _ynabTeachYnab = BudgetTemplate(
    id: 'ynab_teach-ynab',
    translationKeyName: 'template_ynab_teach_ynab_title',
    translationKeyDescription: 'template_ynab_teach_ynab_desc',
    iconName: 'school',
    pockets: [
      PocketTemplate(
        name: 'Monthly',
        percentage: 0.2173,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Mortgage',
          'Internet',
          'Electric',
          'Phone',
          'Subscriptions',
          'Student Loan',
          'Auto Loan',
          'Groceries',
          'Eating Out',
          'Transportation',
          'My Fun Money',
          'Your Fun Money',
        ],
      ),
      PocketTemplate(
        name: 'Non-Monthly',
        percentage: 0.0517,
        iconName: 'calendar_today',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'Auto Maintenance',
          'Car Insurance',
          'Clothing',
          'Gifts & Holidays',
          'Home Maintenance',
          'Medical',
          'Stuff I Forgot',
          'Vehicle Registration',
          'Pets',
        ],
      ),
      PocketTemplate(
        name: 'Goals',
        percentage: 0.731,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[1],
        suggestedCategories: [
          'New Deck',
          'Vacation',
          'Coffee Grinder',
        ],
      ),
    ],
  );

  static final _ynabNewPuppy = BudgetTemplate(
    id: 'ynab_new-puppy',
    translationKeyName: 'template_ynab_new_puppy_title',
    translationKeyDescription: 'template_ynab_new_puppy_desc',
    iconName: 'pets',
    pockets: [
      PocketTemplate(
        name: 'Fur Baby',
        percentage: 0.7233,
        iconName: 'pets',
        color: TemplateColors.softLavender[0],
        suggestedCategories: [
          'Adoption/Breeder Fee',
          'Vaccinations',
          'Supplies',
          'Training/Classes',
        ],
      ),
      PocketTemplate(
        name: 'Ongoing Puppy',
        percentage: 0.2767,
        iconName: 'pets',
        color: TemplateColors.softLavender[1],
        suggestedCategories: [
          'Food',
          'Toys',
          'Pet Medical',
          'Day Care',
          'Pawdicures',
          'Surprise Vet Visits',
          'Puppy Mischief Money',
          'Extra phone storage for all the pics',
        ],
      ),
    ],
  );

  static final _ynabFamily = BudgetTemplate(
    id: 'ynab_family',
    translationKeyName: 'template_ynab_family_title',
    translationKeyDescription: 'template_ynab_family_desc',
    iconName: 'family_restroom',
    pockets: [
      PocketTemplate(
        name: 'Family Life',
        percentage: 1,
        iconName: 'family_restroom',
        color: TemplateColors.warmTerracotta[1],
        suggestedCategories: [
          'School Supplies',
          'Childcare',
          'Haircuts & Clothes',
          'Cell Phone',
          'Violin',
          'Sports & Activities',
          'Birthday Party Gifts (Friends)',
          'Birthday (Their Party)',
          'Christmas',
          'Family Fun',
          'Summer Camp',
          'Family Vacation',
          'Cushion',
        ],
      ),
    ],
  );

  static final _ynabKid = BudgetTemplate(
    id: 'ynab_kid',
    translationKeyName: 'template_ynab_kid_title',
    translationKeyDescription: 'template_ynab_kid_desc',
    iconName: 'family_restroom',
    pockets: [
      PocketTemplate(
        name: 'Piggy Bank',
        percentage: 1,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'Spend',
          'Save | Soon',
          'Save | Later',
          'Give',
        ],
      ),
    ],
  );

  static final _ynabABetterEmergencyFund = BudgetTemplate(
    id: 'ynab_a-better-emergency-fund',
    translationKeyName: 'template_ynab_a_better_emergency_fund_title',
    translationKeyDescription: 'template_ynab_a_better_emergency_fund_desc',
    iconName: 'savings',
    pockets: [
      PocketTemplate(
        name: 'Ready for Emergencies',
        percentage: 1,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[1],
        suggestedCategories: [
          'Tech Replacement',
          'Pet Illness',
          'Car Repairs',
          'ER/Urgent Care Visits',
          'Appliance Repair/Replacement',
          'Income Replacement',
          'Natural Disasters',
          'Home Repairs',
          'Insurance Deductibles',
          'Funerals/Grief Fund',
          'Unexpected Travel',
          'Helping Others',
          'Change of Plans',
          'Locksmith',
        ],
      ),
    ],
  );

  static final _ynabDebtPayoff = BudgetTemplate(
    id: 'ynab_debt-payoff',
    translationKeyName: 'template_ynab_debt_payoff_title',
    translationKeyDescription: 'template_ynab_debt_payoff_desc',
    iconName: 'credit_card',
    pockets: [
      PocketTemplate(
        name: 'Monthly Expenses',
        percentage: 0.7489,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Rent/Mortgage',
          'Internet',
          'Phone',
          'Electric',
          'Focus Debt',
          'Debt #2',
          'Debt #3',
          'Groceries',
          'Transportation',
          'Credit Card Interest',
          'Subscriptions',
        ],
      ),
      PocketTemplate(
        name: 'Non-Monthly Expenses',
        percentage: 0.1781,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[2],
        suggestedCategories: [
          'Auto Maintenance',
          'Car Insurance',
          'Clothing',
          'Gifts & Holidays',
          'Home Maintenance',
          'Medical',
          'Water',
          'Vet',
        ],
      ),
      PocketTemplate(
        name: 'Fun Money',
        percentage: 0.0731,
        iconName: 'celebration',
        color: TemplateColors.dustyRose[1],
        suggestedCategories: [
          'My Spending Money',
          'Your Spending Money',
          'Eating Out',
          'Vacation',
        ],
      ),
    ],
  );

  static final _ynabHappiness = BudgetTemplate(
    id: 'ynab_happiness',
    translationKeyName: 'template_ynab_happiness_title',
    translationKeyDescription: 'template_ynab_happiness_desc',
    iconName: 'celebration',
    pockets: [
      PocketTemplate(
        name: 'Money CAN Buy Happiness!',
        percentage: 1,
        iconName: 'celebration',
        color: TemplateColors.dustyRose[2],
        suggestedCategories: [
          'Plants',
          'Laughter',
          'Random Acts of Kindness',
          'Just Leave',
          'Broadway Shows',
          'Books',
          'Treat Yo\' Self',
          'Suncatchers',
          'Special Meals',
          'Taking Friends Out',
          'Giving',
          'Coziness',
          'Supporting Local Businesses',
          'Learning New Things',
          'Massages',
          'Quality over Quantity',
          'Hobbies',
          'Touch Grass',
          'Quality Time with Family',
          'Delegating Care Tasks',
        ],
      ),
    ],
  );

  static final _ynabChristmas = BudgetTemplate(
    id: 'ynab_christmas',
    translationKeyName: 'template_ynab_christmas_title',
    translationKeyDescription: 'template_ynab_christmas_desc',
    iconName: 'celebration',
    pockets: [
      PocketTemplate(
        name: 'North Pole',
        percentage: 1,
        iconName: 'account_balance_wallet',
        color: TemplateColors.warmTerracotta[0],
        suggestedCategories: [
          'Decorations',
          'Presents',
          'Parties',
          'Stocking Stuffers',
          'Holiday Food',
          'Christmas Magic',
          'Liquid Holiday Cheer',
          'Holiday Outfits',
          'Christmas Cards',
          'Travel',
          'Shipping',
          'Last Minute Holiday Stuff',
        ],
      ),
    ],
  );

  static final _ynabJobLayoff = BudgetTemplate(
    id: 'ynab_job-layoff',
    translationKeyName: 'template_ynab_job_layoff_title',
    translationKeyDescription: 'template_ynab_job_layoff_desc',
    iconName: 'warning',
    pockets: [
      PocketTemplate(
        name: 'Essentials to Protect',
        percentage: 0.4496,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[0],
        suggestedCategories: [
          'Rent/Mortgage',
          'Utilities',
          'Groceries',
          'Transportation',
          'Minimum Debt Payments',
          'Insurance Premiums',
          'Prescriptions/Medical Essentials',
        ],
      ),
      PocketTemplate(
        name: 'Transition & Job Search',
        percentage: 0.5269,
        iconName: 'account_balance_wallet',
        color: TemplateColors.mutedIndigo[0],
        suggestedCategories: [
          'COBRA/Health Coverage Gap',
          'Job Search Costs',
          'Skill Building/Courses',
          'Networking & Coffee Meetings',
          'Childcare (While Job Hunting)',
          'Unemployment Taxes',
          'Moving Costs',
        ],
      ),
      PocketTemplate(
        name: 'Rebuilding & What\'s Next',
        percentage: 0.0234,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[4],
        suggestedCategories: [
          'Rebuild Emergency Fund',
          'Catch Up on Savings Goals',
          'Care & Recovery',
          'Celebrate the New Job',
        ],
      ),
    ],
  );

  static final _ynabNonMonthlyExpenses = BudgetTemplate(
    id: 'ynab_non-monthly-expenses',
    translationKeyName: 'template_ynab_non_monthly_expenses_title',
    translationKeyDescription: 'template_ynab_non_monthly_expenses_desc',
    iconName: 'receipt_long',
    pockets: [
      PocketTemplate(
        name: 'Non-Monthly Bills',
        percentage: 0.5481,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[3],
        suggestedCategories: [
          'Water bill',
          'Trash service',
          'Gas bill',
          'Transportation',
          'Auto maintenance',
          'Car registration',
          'Car insurance premiums',
          'Home maintenance',
          'Renter/home insurance',
          'Health care',
          'Property taxes',
          'Life insurance',
          'Taxes',
        ],
      ),
      PocketTemplate(
        name: 'Non-Monthly Expenses',
        percentage: 0.4519,
        iconName: 'receipt_long',
        color: TemplateColors.dustyRose[3],
        suggestedCategories: [
          'Clothing',
          'Gifts',
          'Birthday Bash Bucks',
          'Charitable giving',
          'Computer/phone replacement',
          'Software subscriptions',
          'Entertainment subscriptions',
          'Vacation',
          'Muscle money',
          'Education',
          'Gaming',
          'Holiday',
          'Other Holidays',
          'Hosting',
          'Dates',
          'Beauty',
          'Entertainment',
          'Warehouse membership',
          'Credit card annual fee',
          'House decor',
          'Banking',
          'Household goods',
          'Fur baby',
        ],
      ),
    ],
  );

  static final _ynabRockretirementclub = BudgetTemplate(
    id: 'ynab_rockretirementclub',
    translationKeyName: 'template_ynab_rockretirementclub_title',
    translationKeyDescription: 'template_ynab_rockretirementclub_desc',
    iconName: 'savings',
    pockets: [
      PocketTemplate(
        name: 'Needs: Base Great Life',
        percentage: 0.4286,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'Housing',
          'Food',
          'Utilities & service subscriptions',
          'Clothing',
          'Entertainment & Base Travel',
          'Transportation',
          'Healthcare',
          'Insurance Policy Premium',
          'Insert Your Own Here',
        ],
      ),
      PocketTemplate(
        name: 'Wants',
        percentage: 0.2381,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'Additional Travel',
          'Retirement Hobbies & Fun',
          'Home Improvement',
          'Gifting',
          'Insert Your Own Here',
        ],
      ),
      PocketTemplate(
        name: 'Wishes',
        percentage: 0.2857,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[2],
        suggestedCategories: [
          'Celebration',
          'Provide Care for Loved One',
          'Education for Kids/Grandkids',
          'New Home',
          'Start Business',
          'Insert Your Own Here',
        ],
      ),
      PocketTemplate(
        name: 'Contingency Fund',
        percentage: 0.0476,
        iconName: 'celebration',
        color: TemplateColors.gentleSage[1],
        suggestedCategories: [
          'Contingency Fund',
        ],
      ),
    ],
  );

  static final _ynabTravel = BudgetTemplate(
    id: 'ynab_travel',
    translationKeyName: 'template_ynab_travel_title',
    translationKeyDescription: 'template_ynab_travel_desc',
    iconName: 'flight',
    pockets: [
      PocketTemplate(
        name: 'Vacation',
        percentage: 1,
        iconName: 'flight',
        color: TemplateColors.softAmber[2],
        suggestedCategories: [
          'Flights',
          'Lodging',
          'Transportation',
          'Snacks',
          'Meals',
          'Tips/Gratuities',
          'Activities/Experiences',
          'Trip Treasures',
          'Pet Sitting/House Sitting',
          'Parking',
        ],
      ),
    ],
  );

  static final _ynabYnabBeginnerTemplate = BudgetTemplate(
    id: 'ynab_ynab-beginner-template',
    translationKeyName: 'template_ynab_ynab_beginner_template_title',
    translationKeyDescription: 'template_ynab_ynab_beginner_template_desc',
    iconName: 'home_work',
    pockets: [
      PocketTemplate(
        name: 'Monthly',
        percentage: 0.5331,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Mortgage',
          'Phone',
          'Netflix',
          'Water',
          'Electric',
          'Internet',
          'Spotify',
          'Groceries',
          'Gas',
        ],
      ),
      PocketTemplate(
        name: 'Fun',
        percentage: 0.0562,
        iconName: 'celebration',
        color: TemplateColors.dustyRose[1],
        suggestedCategories: [
          'Your Spending Money',
          'My Spending Money',
          'Take-Out/Delivery',
          'Dates',
          'Home Decor',
        ],
      ),
      PocketTemplate(
        name: 'Debt Paydown',
        percentage: 0.1167,
        iconName: 'credit_card',
        color: TemplateColors.softBlue[2],
        suggestedCategories: [
          'Capital One Payment',
          'Credit Card Interest',
          'Car Loan',
        ],
      ),
      PocketTemplate(
        name: 'Kids',
        percentage: 0.0346,
        iconName: 'family_restroom',
        color: TemplateColors.warmTerracotta[1],
        suggestedCategories: [
          'Swim Lessons',
          'Kid #1',
          'Kid #2',
        ],
      ),
      PocketTemplate(
        name: 'Non-Monthly/Annual',
        percentage: 0.1643,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[4],
        suggestedCategories: [
          'Home Maintenance',
          'Auto Maintenance',
          'Medical',
          'Vet',
          'Auto Insurance',
          'Budget App Subscription',
          'Gifts',
          'Holiday Spending',
        ],
      ),
      PocketTemplate(
        name: 'Savings',
        percentage: 0.0519,
        iconName: 'savings',
        color: TemplateColors.gentleSage[2],
        suggestedCategories: [
          'Emergency Fund',
          '529',
        ],
      ),
      PocketTemplate(
        name: 'Wishlist',
        percentage: 0.0432,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[3],
        suggestedCategories: [
          'Garden Project',
          'New Laptop',
          'Sunshine Trip',
        ],
      ),
    ],
  );

  static final _ynabDivorce = BudgetTemplate(
    id: 'ynab_divorce',
    translationKeyName: 'template_ynab_divorce_title',
    translationKeyDescription: 'template_ynab_divorce_desc',
    iconName: 'warning',
    pockets: [
      PocketTemplate(
        name: 'Needs',
        percentage: 0.9113,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'Lawyer Fees',
          'Financial Consultant',
          'Couple\'s Therapist',
          'Mobile Phone',
          'Subscriptions/Streaming Services',
          'Health Insurance',
          'My Therapy',
          'Kids\' Therapy',
          'Moving Company and Supplies',
        ],
      ),
      PocketTemplate(
        name: 'Self-Kindness',
        percentage: 0.0886,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[0],
        suggestedCategories: [
          'Takeout for Bad Days',
          'Coffee with Supportive Friends',
          'Books and Audiobooks',
          'Travel with Kids',
          'Crock Pot Money (Holding Category)',
        ],
      ),
      PocketTemplate(
        name: 'Situational',
        percentage: 0.0002,
        iconName: 'account_balance_wallet',
        color: TemplateColors.warmTerracotta[2],
        suggestedCategories: [
          'Babysitter/Additional Child Care',
          'Kids Activities',
        ],
      ),
    ],
  );

  static final _ynabNavigatingLoss = BudgetTemplate(
    id: 'ynab_navigating-loss',
    translationKeyName: 'template_ynab_navigating_loss_title',
    translationKeyDescription: 'template_ynab_navigating_loss_desc',
    iconName: 'warning',
    pockets: [
      PocketTemplate(
        name: 'Funeral & Memorial',
        percentage: 0.4853,
        iconName: 'celebration',
        color: TemplateColors.coolGray[2],
        suggestedCategories: [
          'Funeral Home Services',
          'Cremation or Burial',
          'Clergy Fee',
          'Obituary',
          'Casket or Urn',
          'Burial Plot or Headstone',
          'Clothing for Service',
        ],
      ),
      PocketTemplate(
        name: 'Celebration or Gathering',
        percentage: 0.1387,
        iconName: 'account_balance_wallet',
        color: TemplateColors.coolGray[0],
        suggestedCategories: [
          'Venue Rental',
          'Flowers',
          'Food & Drinks',
          'Programs & Photos',
          'Music or A/V',
          'Memorial Keepsakes',
        ],
      ),
      PocketTemplate(
        name: 'Legal & Administrative',
        percentage: 0.1627,
        iconName: 'account_balance_wallet',
        color: TemplateColors.mutedIndigo[1],
        suggestedCategories: [
          'Death Certificates',
          'Estate or Legal Fees',
          'Notary or Administrative Costs',
          'Travel for Legal Matters',
        ],
      ),
      PocketTemplate(
        name: 'Travel & Logistics',
        percentage: 0.0667,
        iconName: 'flight',
        color: TemplateColors.softAmber[1],
        suggestedCategories: [
          'Flights or Gas',
          'Hotels & Lodging',
          'Meals',
          'Childcare / Petcare',
        ],
      ),
      PocketTemplate(
        name: 'Accounts & Ongoing Costs',
        percentage: 0.0773,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[3],
        suggestedCategories: [
          'Canceling Subscriptions & Utilities',
          'Social Media Accounts',
          'Estate or Home Expenses',
          'Cleaning / Storage',
          'Thank-Yous',
        ],
      ),
      PocketTemplate(
        name: 'Support & Grieving',
        percentage: 0.0427,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[0],
        suggestedCategories: [
          'Counseling or Therapy',
          'Grief Support or Books',
          'Self Care',
          'Grief Brain',
        ],
      ),
      PocketTemplate(
        name: 'Honoring Their Memory',
        percentage: 0.0267,
        iconName: 'account_balance_wallet',
        color: TemplateColors.coolGray[4],
        suggestedCategories: [
          'Charitable Donations',
          'Legacy Gifts',
          'Website Hosting',
          'Photo & Video Digitization',
        ],
      ),
    ],
  );

  static final _ynabNewBaby = BudgetTemplate(
    id: 'ynab_new-baby',
    translationKeyName: 'template_ynab_new_baby_title',
    translationKeyDescription: 'template_ynab_new_baby_desc',
    iconName: 'family_restroom',
    pockets: [
      PocketTemplate(
        name: 'Stork Delivery',
        percentage: 1,
        iconName: 'account_balance_wallet',
        color: TemplateColors.warmTerracotta[0],
        suggestedCategories: [
          'Medical Costs',
          'Doula Service',
          'Baby Gear',
          'Nursery',
          'Income Replacement',
          'Maternity Clothes',
          'Diapers & Wipes',
          'Memories and Announcements',
          'Just for Me',
          'Miscellaneous',
          'Dark Days Food Delivery',
          'Don\'t Know Yet',
        ],
      ),
    ],
  );

  static final _ynabRecentlyGraduated = BudgetTemplate(
    id: 'ynab_recently-graduated',
    translationKeyName: 'template_ynab_recently_graduated_title',
    translationKeyDescription: 'template_ynab_recently_graduated_desc',
    iconName: 'school',
    pockets: [
      PocketTemplate(
        name: 'Monthly Expenses',
        percentage: 0.1161,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Rent/Utilities',
          'Groceries/Personal',
          'Transportation',
          'Dining Out',
          'Health/Fitness',
          'Health Insurance',
          'Personal Care',
          'Car Insurance',
          'Phone Bill',
        ],
      ),
      PocketTemplate(
        name: 'Non-Monthly Expenses',
        percentage: 0.0529,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[2],
        suggestedCategories: [
          'Credit Card Annual Fee',
          'Entertainment',
          'Car Maintenance',
          'Music Business Expenses',
          'Household Items',
          'Dates',
          'Gifts',
          'Music Gear',
          'Travel',
          'Taxes',
        ],
      ),
      PocketTemplate(
        name: 'Savings',
        percentage: 0.831,
        iconName: 'savings',
        color: TemplateColors.gentleSage[2],
        suggestedCategories: [
          'Six-Month Buffer',
          'Europe 2026',
          'Investments',
        ],
      ),
    ],
  );

  static final _ynabWedding = BudgetTemplate(
    id: 'ynab_wedding',
    translationKeyName: 'template_ynab_wedding_title',
    translationKeyDescription: 'template_ynab_wedding_desc',
    iconName: 'celebration',
    pockets: [
      PocketTemplate(
        name: 'Ceremony & Reception',
        percentage: 0.5116,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'Venue',
          'Catering',
          'Cake',
          'Drinks',
          'Marriage License',
          'Musicians',
          'DJ',
          'Wedding Night Hotel',
          'Miscellaneous',
        ],
      ),
      PocketTemplate(
        name: 'Invitations and Guests',
        percentage: 0.0683,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[1],
        suggestedCategories: [
          'Invites, Save the Dates, Postage',
          'Transportation',
          'Favors',
          'Gifts for Bridal Party',
        ],
      ),
      PocketTemplate(
        name: 'Wardrobe',
        percentage: 0.1395,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[2],
        suggestedCategories: [
          'Wedding Bands',
          'Alterations',
          'Accessories',
          'Hair & Makeup',
          'Dress/Suit/Tux/Attire',
        ],
      ),
      PocketTemplate(
        name: 'Vendors',
        percentage: 0.186,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[3],
        suggestedCategories: [
          'Florist',
          'Photographer',
          'Videographer',
          'Event Coordinator',
          'Tips',
        ],
      ),
      PocketTemplate(
        name: 'Decor & More',
        percentage: 0.0872,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[4],
        suggestedCategories: [
          'Decor',
          'Rehearsal Dinner',
          'Miscellaneous',
        ],
      ),
      PocketTemplate(
        name: 'Surviving Wedding Week',
        percentage: 0.0073,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[3],
        suggestedCategories: [
          'Late-night pizza delivery',
          'Emergency massage',
          'Powered by caffeine',
        ],
      ),
    ],
  );

  static final _ynabBuyingAHome = BudgetTemplate(
    id: 'ynab_buying-a-home',
    translationKeyName: 'template_ynab_buying_a_home_title',
    translationKeyDescription: 'template_ynab_buying_a_home_desc',
    iconName: 'home',
    pockets: [
      PocketTemplate(
        name: 'Home Sweet Home',
        percentage: 1,
        iconName: 'home',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'Down Payment',
          'Closing Costs',
          'Inspections',
          'Appraisal Fee',
          'Property Taxes',
          'Moving Costs',
          'Repairs and Maintenance',
          'Utility Setup Fees',
          'Furniture and Appliances',
          'Stress Food',
          'Prudent Reserves',
        ],
      ),
    ],
  );

  static final _ynabDisasterPrep = BudgetTemplate(
    id: 'ynab_disaster-prep',
    translationKeyName: 'template_ynab_disaster_prep_title',
    translationKeyDescription: 'template_ynab_disaster_prep_desc',
    iconName: 'warning',
    pockets: [
      PocketTemplate(
        name: 'Evacuation',
        percentage: 0.0577,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softAmber[0],
        suggestedCategories: [
          'Lodging',
          'Groceries/Dining Out',
          'Transportation',
          'Entertainment',
        ],
      ),
      PocketTemplate(
        name: 'Disaster Recovery',
        percentage: 0.7878,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Grocery Replacements',
          'Electric Repair',
          'Lawn Repair',
          'Roof Repair',
          'Tree & Stump Removal',
          'Insurance Deductible',
        ],
      ),
      PocketTemplate(
        name: 'Preparing for the Worst',
        percentage: 0.1545,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[0],
        suggestedCategories: [
          'Chainsaw',
          'Cooler',
          'Bathtub Water Collector',
          '7-gallon canteens + Water Bottles',
          'Shelf Stable Meals',
          'Gas Cans, Gas, and Propane',
          'Generator + Extension Cords',
          'Backup Battery + Batteries',
          'Cash',
          'Emergency Radio',
          'Hot Weather Gear',
          'Cold Weather Gear',
          'Bug Out Bags',
          'Small Kindnesses',
        ],
      ),
    ],
  );

  static final _ynabHomeProject = BudgetTemplate(
    id: 'ynab_home-project',
    translationKeyName: 'template_ynab_home_project_title',
    translationKeyDescription: 'template_ynab_home_project_desc',
    iconName: 'home',
    pockets: [
      PocketTemplate(
        name: 'Labor',
        percentage: 0.5369,
        iconName: 'account_balance_wallet',
        color: TemplateColors.mutedIndigo[0],
        suggestedCategories: [
          'Demolition',
          'Electrician',
          'Plumber/HVAC',
          'General contractor',
          'Designer',
          'Refinishing hardwood floor',
          'Locksmith',
        ],
      ),
      PocketTemplate(
        name: 'Materials',
        percentage: 0.2127,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[2],
        suggestedCategories: [
          'Countertops',
          'Backsplash',
          'Flooring and tile',
          'Paint',
          'Cabinets',
        ],
      ),
      PocketTemplate(
        name: 'Appliances',
        percentage: 0.0422,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[3],
        suggestedCategories: [
          'Kitchen appliances',
          'Range hood',
        ],
      ),
      PocketTemplate(
        name: 'Fixtures',
        percentage: 0.0645,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[4],
        suggestedCategories: [
          'Lighting',
          'Kitchen faucet',
          'Bathroom fixtures',
        ],
      ),
      PocketTemplate(
        name: 'Decor',
        percentage: 0.0922,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'Rugs',
          'Furniture',
          'TV and speakers',
        ],
      ),
      PocketTemplate(
        name: 'Miscellaneous',
        percentage: 0.0515,
        iconName: 'account_balance_wallet',
        color: TemplateColors.coolGray[0],
        suggestedCategories: [
          'Dumpster rental',
          'Self care during renovation',
          'Emergency fund',
        ],
      ),
    ],
  );

  static final _ynabHouseProjectsQueue = BudgetTemplate(
    id: 'ynab_house-projects-queue',
    translationKeyName: 'template_ynab_house_projects_queue_title',
    translationKeyDescription: 'template_ynab_house_projects_queue_desc',
    iconName: 'home',
    pockets: [
      PocketTemplate(
        name: 'Home Projects',
        percentage: 1,
        iconName: 'home',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'New Bed',
          '\$8K For Surprises',
          'Radon Mitigation',
          '(De)humidifier',
          'Water Quality Test',
          'Water Filtration',
          'HVAC Cleaning',
          'Hot Water Heater',
          'Popcorn Ceiling Removal & Fresh Paint',
          'Electrical To Code',
          'Drainage Solutions',
          'Chimney Flashing',
          'Washer & Dryer',
          'Starter Garden',
          'Chickens',
          'Replace Interior Door',
          'Refrigerator',
          'Tree Removal',
          'Cost To Refinance',
          'Stove Hood Vent',
          'Glass Front Door',
          'Goats Landscaping',
          'Retaining Wall',
          'Ridge Vent',
          'Roof Soft Cleaning',
          'Furniture',
        ],
      ),
    ],
  );

  static final _ynabKitchenRemodel = BudgetTemplate(
    id: 'ynab_kitchen-remodel',
    translationKeyName: 'template_ynab_kitchen_remodel_title',
    translationKeyDescription: 'template_ynab_kitchen_remodel_desc',
    iconName: 'home',
    pockets: [
      PocketTemplate(
        name: 'Kitchen Remodel',
        percentage: 1,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Dishwasher',
          'Vent Hood',
          'New Cooktop',
          'Countertops',
          'Sink',
          'Backsplash',
          'Lighting',
          'Bathroom Tile',
          'Gas Line and Plumbing',
          'Painting & Ceiling Repair',
          'Labor',
          'Surprise Problems',
          'Stuff We Forgot at Lowe\'s',
          'Kitchen in Shambles Meals',
        ],
      ),
    ],
  );

  static final _ynabMoving = BudgetTemplate(
    id: 'ynab_moving',
    translationKeyName: 'template_ynab_moving_title',
    translationKeyDescription: 'template_ynab_moving_desc',
    iconName: 'home',
    pockets: [
      PocketTemplate(
        name: 'Before You Move',
        percentage: 0.546,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[2],
        suggestedCategories: [
          'Security Deposit',
          'First Month\'s Rent',
          'Rent/Mortgage Difference',
          'Application Fees',
          'Utility Set-Up Fees',
          'Renter\'s/Home Insurance',
        ],
      ),
      PocketTemplate(
        name: 'Supplies & Services',
        percentage: 0.2184,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[4],
        suggestedCategories: [
          'Moving Supplies',
          'Moving Truck',
          'Professional Movers',
          'Storage Unit',
          'Cleaning Supplies',
          'Cleaning Services',
        ],
      ),
      PocketTemplate(
        name: 'Helpers & Hospitality',
        percentage: 0.0415,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[3],
        suggestedCategories: [
          'Pizza & Drinks',
          'Thank You Gifts',
          'Childcare or Pet Boarding',
        ],
      ),
      PocketTemplate(
        name: 'Transportation & Travel',
        percentage: 0.0576,
        iconName: 'flight',
        color: TemplateColors.softAmber[0],
        suggestedCategories: [
          'Fuel',
          'Hotel',
          'Grab & Go Meals',
        ],
      ),
      PocketTemplate(
        name: 'Unexpected',
        percentage: 0.1365,
        iconName: 'account_balance_wallet',
        color: TemplateColors.coolGray[0],
        suggestedCategories: [
          'Buffer',
          'Lost or Broken Items',
          'Overlap Costs',
          'First Night Takeout',
        ],
      ),
    ],
  );

  static final _ynabCollege = BudgetTemplate(
    id: 'ynab_college',
    translationKeyName: 'template_ynab_college_title',
    translationKeyDescription: 'template_ynab_college_desc',
    iconName: 'school',
    pockets: [
      PocketTemplate(
        name: 'Day-to-Day Life',
        percentage: 0.2857,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'Cell Phone',
          'Transportation',
          'Haircuts',
          'Late-Night Pizza',
        ],
      ),
      PocketTemplate(
        name: 'Living Essentials',
        percentage: 0.2143,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[3],
        suggestedCategories: [
          'Dorm',
          'Meal Plan',
          'Household Supplies',
        ],
      ),
      PocketTemplate(
        name: 'School Stuff',
        percentage: 0.2857,
        iconName: 'account_balance_wallet',
        color: TemplateColors.mutedIndigo[2],
        suggestedCategories: [
          'Tuition',
          'Books',
          'Fees',
          'Supplies',
        ],
      ),
      PocketTemplate(
        name: 'Fun',
        percentage: 0.2143,
        iconName: 'celebration',
        color: TemplateColors.dustyRose[1],
        suggestedCategories: [
          'Going Out',
          'Dorm Decor',
          'Spring Break',
        ],
      ),
    ],
  );

  static final _ynabDisney = BudgetTemplate(
    id: 'ynab_disney',
    translationKeyName: 'template_ynab_disney_title',
    translationKeyDescription: 'template_ynab_disney_desc',
    iconName: 'celebration',
    pockets: [
      PocketTemplate(
        name: 'Theme Park',
        percentage: 1,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'Lodging',
          'Travel Days',
          'Flights',
          'Park Tickets',
          'Park Expenses',
          'Magic Bands',
          'Lightning Lanes',
          'Baggage Fees',
          'Dog Boarding',
          'Vacation Prep',
          'Unexpected Expenses',
        ],
      ),
    ],
  );

  static final _ynabTeen = BudgetTemplate(
    id: 'ynab_teen',
    translationKeyName: 'template_ynab_teen_title',
    translationKeyDescription: 'template_ynab_teen_desc',
    iconName: 'school',
    pockets: [
      PocketTemplate(
        name: 'My Expenses',
        percentage: 0.7315,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[2],
        suggestedCategories: [
          'Snacks & Food',
          'Clothing/Skincare',
          'Gifts & Giving',
          'Fun',
          'Car Costs',
          'Gym!',
          'Phone',
          'Owe the Parents',
        ],
      ),
      PocketTemplate(
        name: 'Wishlist',
        percentage: 0.0093,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[2],
        suggestedCategories: [
          'Travel!',
          'Taylor Swift',
          'Sweatshirt',
          'Ugg Slippers',
          'Phone Case',
        ],
      ),
      PocketTemplate(
        name: 'Someday!',
        percentage: 0.2593,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[1],
        suggestedCategories: [
          'Savings',
          'Roth IRA',
        ],
      ),
    ],
  );

  static final _ynabFood = BudgetTemplate(
    id: 'ynab_food',
    translationKeyName: 'template_ynab_food_title',
    translationKeyDescription: 'template_ynab_food_desc',
    iconName: 'restaurant',
    pockets: [
      PocketTemplate(
        name: 'Nom Noms',
        percentage: 1,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[4],
        suggestedCategories: [
          'Grocery Store',
          'Warehouse Club',
          'Not Cooking',
          'Coffee',
          'Li\'l Treats',
        ],
      ),
    ],
  );

  static final _ynabMinimalistYnab = BudgetTemplate(
    id: 'ynab_minimalist-ynab',
    translationKeyName: 'template_ynab_minimalist_ynab_title',
    translationKeyDescription: 'template_ynab_minimalist_ynab_desc',
    iconName: 'remove',
    pockets: [
      PocketTemplate(
        name: 'The Simple Life',
        percentage: 1,
        iconName: 'remove',
        color: TemplateColors.coolGray[0],
        suggestedCategories: [
          'Food',
          'Needs',
          'Wants',
          'Travel',
          'Emergency',
          'Savings',
        ],
      ),
    ],
  );

  static final _ynabNewYearsResolutions = BudgetTemplate(
    id: 'ynab_new-years-resolutions',
    translationKeyName: 'template_ynab_new_years_resolutions_title',
    translationKeyDescription: 'template_ynab_new_years_resolutions_desc',
    iconName: 'celebration',
    pockets: [
      PocketTemplate(
        name: 'Big Dreams',
        percentage: 0.1118,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'Travel',
          'Bucket List',
          'Lessons (e.g. Music, Art, Karate)',
        ],
      ),
      PocketTemplate(
        name: 'Family & Friends',
        percentage: 0.0851,
        iconName: 'family_restroom',
        color: TemplateColors.dustyRose[2],
        suggestedCategories: [
          'Date Night',
          'Coffee with Friends',
          'Book Club Snacks',
          'Random Act of Kindness',
        ],
      ),
      PocketTemplate(
        name: 'Money',
        percentage: 0.0729,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[1],
        suggestedCategories: [
          'Debt Paydown',
          'Investing a little extra',
          'Charitable Giving',
        ],
      ),
      PocketTemplate(
        name: 'Wellness Goals',
        percentage: 0.333,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[2],
        suggestedCategories: [
          'Meditation App',
          'Gym Membership',
          'Therapy',
          'Nutritionist',
        ],
      ),
      PocketTemplate(
        name: 'Personal Goals',
        percentage: 0.1152,
        iconName: 'account_balance_wallet',
        color: TemplateColors.mutedIndigo[2],
        suggestedCategories: [
          'Language Learning App',
          'Audiobook Subscription',
          'Gratitude Journal',
          'Sunrise Alarm',
          'Volunteering',
          'Learn a new hobby',
          'Social Media Blocking App',
        ],
      ),
      PocketTemplate(
        name: 'Career',
        percentage: 0.282,
        iconName: 'account_balance_wallet',
        color: TemplateColors.mutedIndigo[0],
        suggestedCategories: [
          'Continuing Education',
          'Career Coaching',
          'LinkedIn Premium / Job Board Subscriptions',
        ],
      ),
    ],
  );

  static final _ynabNickTruesStarterTemplate = BudgetTemplate(
    id: 'ynab_nick-trues-starter-template',
    translationKeyName: 'template_ynab_nick_trues_starter_template_title',
    translationKeyDescription: 'template_ynab_nick_trues_starter_template_desc',
    iconName: 'home_work',
    pockets: [
      PocketTemplate(
        name: 'One Month Ahead',
        percentage: 0.0133,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[3],
        suggestedCategories: [
          'Next Month\'s Money',
        ],
      ),
      PocketTemplate(
        name: 'Bills',
        percentage: 0.3164,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'Mortgage + Escrow',
          'Pet Insurance',
          'Utilities',
          'Spotify',
          'Car Insurance',
          'Netflix',
          'Gym',
          'Phone & Internet',
        ],
      ),
      PocketTemplate(
        name: 'Debt Snowball',
        percentage: 0.1143,
        iconName: 'credit_card',
        color: TemplateColors.softBlue[4],
        suggestedCategories: [
          '1) Amex Gold Payment',
          '2) Discover Miles',
          '3) Personal Loan',
          '4) Car Loan',
          'CC Interest',
        ],
      ),
      PocketTemplate(
        name: 'Fun Spending',
        percentage: 0.0652,
        iconName: 'celebration',
        color: TemplateColors.dustyRose[1],
        suggestedCategories: [
          'My Fun Spending',
          'Your Fun Spending',
          'Dining Out',
          'Fast Food',
          'Fun',
          'ATM Cash',
          'Home Decor',
        ],
      ),
      PocketTemplate(
        name: 'Monthly Living Expenses',
        percentage: 0.3273,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Groceries',
          'Amazon',
          'Gas',
          'Clothing',
          'Pet',
          'Haircuts',
          'Giving',
          'Unexpected',
        ],
      ),
      PocketTemplate(
        name: 'Kids',
        percentage: 0.0186,
        iconName: 'family_restroom',
        color: TemplateColors.warmTerracotta[0],
        suggestedCategories: [
          'Nick Jr.',
          'Hanna Jr.',
          'Kids Activities',
        ],
      ),
      PocketTemplate(
        name: 'Irregular & Annual Expenses',
        percentage: 0.0494,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[3],
        suggestedCategories: [
          'Home Maintenance',
          'Auto Maintenance',
          'Routine Medical',
          'Life Insurance',
          'Budget App',
          'Amazon Prime',
          'Gifts',
          'Christmas',
        ],
      ),
      PocketTemplate(
        name: 'Short-Term Savings',
        percentage: 0.0419,
        iconName: 'savings',
        color: TemplateColors.gentleSage[1],
        suggestedCategories: [
          'Long Weekends',
          'Winter Cabin',
          'Thanksgiving',
          'Medical Emergency',
        ],
      ),
      PocketTemplate(
        name: 'Savings (Tracking)',
        percentage: 0.0532,
        iconName: 'savings',
        color: TemplateColors.gentleSage[0],
        suggestedCategories: [
          'Income Loss',
          'IRA Contributions',
          '529 Contributions',
        ],
      ),
      PocketTemplate(
        name: 'Reimbursements',
        percentage: 0.0003,
        iconName: 'account_balance_wallet',
        color: TemplateColors.coolGray[0],
        suggestedCategories: [
          'Reimbursements - Work',
          'Reimbursements - Personal',
        ],
      ),
    ],
  );

  static final _ynabNickTruesValuesTemplate = BudgetTemplate(
    id: 'ynab_nick-trues-values-template',
    translationKeyName: 'template_ynab_nick_trues_values_template_title',
    translationKeyDescription: 'template_ynab_nick_trues_values_template_desc',
    iconName: 'home_work',
    pockets: [
      PocketTemplate(
        name: 'Joy',
        percentage: 0.0703,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'Hanna\'s Art Supplies',
          'Date Night',
          'Coffee Shops',
          'Nick Spending',
          'Hanna Spending',
          'Streaming',
          'Weekend Adventures',
        ],
      ),
      PocketTemplate(
        name: 'Relationship Building',
        percentage: 0.0899,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[2],
        suggestedCategories: [
          'Family Dining Out',
          'Pet Insurance + Expenses',
          'Gifts',
          'Christmas',
        ],
      ),
      PocketTemplate(
        name: 'Home',
        percentage: 0.3272,
        iconName: 'home',
        color: TemplateColors.softBlue[1],
        suggestedCategories: [
          'Mortgage',
          'Phone/Internet',
          'Utilities',
          'Pest Control',
          'Trash',
          'Tools',
          'Large Home Projects',
          'Routine Home Maintenance',
        ],
      ),
      PocketTemplate(
        name: 'Health/Appearance',
        percentage: 0.1885,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[0],
        suggestedCategories: [
          'Groceries + Household',
          'Clothing',
          'Fitness Clothing + Shoes',
          'Cosmetics',
          'Haircut',
          'Fitness App Subscription',
        ],
      ),
      PocketTemplate(
        name: 'Spiritual/Giving',
        percentage: 0.1134,
        iconName: 'account_balance_wallet',
        color: TemplateColors.coolGray[4],
        suggestedCategories: [
          'Giving/Donating',
          'Bible Study',
        ],
      ),
      PocketTemplate(
        name: 'Vehicles',
        percentage: 0.0255,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softAmber[2],
        suggestedCategories: [
          'Gas',
          'Vue Car Insurance',
          'Vue Maintenance',
          'Vue Registration',
        ],
      ),
      PocketTemplate(
        name: 'Camping/Travel',
        percentage: 0.0726,
        iconName: 'flight',
        color: TemplateColors.softAmber[0],
        suggestedCategories: [
          'Gas + Propane',
          'Campgrounds',
          'RV Insurance',
          'Yearly Memberships (RV)',
          'F250 Insurance',
          'F250 Maintenance',
          'F250 Registration',
        ],
      ),
      PocketTemplate(
        name: 'Wealth Building',
        percentage: 0.1047,
        iconName: 'account_balance_wallet',
        color: TemplateColors.gentleSage[1],
        suggestedCategories: [
          'Our Roth IRAs',
        ],
      ),
      PocketTemplate(
        name: 'Preparation',
        percentage: 0.0009,
        iconName: 'account_balance_wallet',
        color: TemplateColors.softBlue[4],
        suggestedCategories: [
          'Emergency: House',
          'Emergency: Income Loss',
          'Emergency: Medical',
          'Emergency: Pets',
          'Health Insurance',
        ],
      ),
      PocketTemplate(
        name: 'Unexpected',
        percentage: 0.007,
        iconName: 'account_balance_wallet',
        color: TemplateColors.coolGray[0],
        suggestedCategories: [
          'Unexpected Expenses',
          'Reimbursements',
        ],
      ),
    ],
  );

  static final _ynabVariableIncome = BudgetTemplate(
    id: 'ynab_variable-income',
    translationKeyName: 'template_ynab_variable_income_title',
    translationKeyDescription: 'template_ynab_variable_income_desc',
    iconName: 'work',
    pockets: [
      PocketTemplate(
        name: 'Personal Expenses',
        percentage: 0.4602,
        iconName: 'receipt_long',
        color: TemplateColors.softBlue[0],
        suggestedCategories: [
          'Rent/Mortgage',
          'Utilities',
          'Groceries',
          'Coffee/Dining Out',
          'Kid Stuff',
          'Subscriptions',
          'Gas',
        ],
      ),
      PocketTemplate(
        name: 'Business Expenses',
        percentage: 0.496,
        iconName: 'work',
        color: TemplateColors.mutedIndigo[0],
        suggestedCategories: [
          'Get a Month Ahead',
          'Booth Rent',
          'Insurance',
          'Color',
          'Hair Products',
          'Foils/Gloves/Materials',
          'Booking System',
          'Marketing (Website, Ads, Tradeshows)',
          'Equipment Repair/Replacement',
          'Taxes',
          'Utilities',
          'Education/Conventions',
          'Business Licence',
          'Health Insurance',
        ],
      ),
      PocketTemplate(
        name: 'Workplace Perks',
        percentage: 0.0437,
        iconName: 'work',
        color: TemplateColors.dustyRose[2],
        suggestedCategories: [
          'Coffee for Coworkers',
          'Holiday Treats',
          'Client Appreciation',
          'Charitable Giving',
          'Vacation',
        ],
      ),
    ],
  );

  static final _ynabWishFarm = BudgetTemplate(
    id: 'ynab_wish-farm',
    translationKeyName: 'template_ynab_wish_farm_title',
    translationKeyDescription: 'template_ynab_wish_farm_desc',
    iconName: 'savings',
    pockets: [
      PocketTemplate(
        name: 'Wishlist (Active)',
        percentage: 0.9997,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[0],
        suggestedCategories: [
          'New Puzzle',
          'Bike',
          'Mediterranean Cruise',
        ],
      ),
      PocketTemplate(
        name: 'Wishlist (Later)',
        percentage: 0.0003,
        iconName: 'account_balance_wallet',
        color: TemplateColors.dustyRose[4],
        suggestedCategories: [
          'Massage',
          'Weekend Away',
          'Bottomless Shrimp Night',
        ],
      ),
    ],
  );
}
