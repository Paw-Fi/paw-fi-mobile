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

final Map<String, Color> categoryColors = {
  'transfers': const Color(0xFF8B5CF6),
  'shopping': const Color(0xFFEC4899),
  'utilities': const Color(0xFF3B82F6),
  'entertainment': const Color(0xFFF59E0B),
  'restaurants': const Color(0xFF10B981),
  'food': const Color(0xFFF97316),
  'groceries': const Color(0xFF06B6D4),
  'transport': const Color(0xFFEF4444),
  'transportation': const Color(0xFFEF4444),
  'health': const Color(0xFF14B8A6),
  'medical': const Color(0xFF0EA5E9),
  'text': const Color(0xFF22D3EE),
  'education': const Color(0xFFA855F7),
  'tuition': const Color(0xFFA855F7),
  'subscriptions': const Color(0xFF6366F1),
  'services': const Color(0xFF6366F1),
  'housing': const Color(0xFF3B82F6),
  'rent': const Color(0xFF2563EB),
  'mortgage': const Color(0xFF1D4ED8),
  'bills': const Color(0xFF1E293B),
  'insurance': const Color(0xFF0284C7),
  'savings': const Color(0xFF34D399),
  'investment': const Color(0xFF22C55E),
  'investments': const Color(0xFF22C55E),
  'income': const Color(0xFF16A34A),
  'salary': const Color(0xFF15803D),
  'bonus': const Color(0xFF0F766E),
  'travel': const Color(0xFF0EA5E9),
  'flights': const Color(0xFF0284C7),
  'vacation': const Color(0xFF0EA5E9),
  'pets': const Color(0xFFF472B6),
  'kids': const Color(0xFFFB7185),
  'family': const Color(0xFFF97316),
  'gifts': const Color(0xFFFACC15),
  'charity': const Color(0xFF14B8A6),
  'fees': const Color(0xFF6B7280),
  'loan': const Color(0xFF1E3A8A),
  'loans': const Color(0xFF1E3A8A),
  'debt': const Color(0xFF1F2937),
  'personal care': const Color(0xFFF472B6),
  'beauty': const Color(0xFFDB2777),
  'entertainment_subscriptions': const Color(0xFF6366F1),
  'misc': const Color(0xFF9CA3AF),
  'uncategorized': const Color(0xFF9CA3AF),
};

final Map<String, IconData> categoryIcons = {
  'transfers': Icons.swap_horiz,
  'shopping': Icons.shopping_bag,
  'utilities': Icons.home_repair_service,
  'entertainment': Icons.sports_esports,
  'entertainment_subscriptions': Icons.tv,
  'restaurants': Icons.restaurant,
  'food': Icons.fastfood,
  'groceries': Icons.shopping_cart,
  'transport': Icons.directions_car,
  'transportation': Icons.directions_car,
  'travel': Icons.flight_takeoff,
  'flights': Icons.flight,
  'vacation': Icons.beach_access,
  'health': Icons.favorite,
  'medical': Icons.local_hospital,
  'text': Icons.sms,
  'education': Icons.school,
  'tuition': Icons.school,
  'subscriptions': Icons.autorenew,
  'services': Icons.design_services,
  'housing': Icons.home,
  'rent': Icons.apartment,
  'mortgage': Icons.house_siding,
  'bills': Icons.receipt_long,
  'insurance': Icons.shield,
  'savings': Icons.savings,
  'investment': Icons.trending_up,
  'investments': Icons.trending_up,
  'income': Icons.attach_money,
  'salary': Icons.payments,
  'bonus': Icons.card_giftcard,
  'pets': Icons.pets,
  'kids': Icons.child_friendly,
  'family': Icons.family_restroom,
  'gifts': Icons.card_giftcard,
  'charity': Icons.volunteer_activism,
  'fees': Icons.receipt_long,
  'loan': Icons.account_balance,
  'loans': Icons.account_balance,
  'debt': Icons.balance,
  'personal care': Icons.spa,
  'beauty': Icons.brush,
  'misc': Icons.widgets,
  'uncategorized': Icons.category,
};

Color getCategoryColor(String? category) {
  final key = (category ?? 'uncategorized').toLowerCase();
  final mapped = categoryColors[key];
  if (mapped != null) return mapped;

  final paletteIndex = key.hashCode.abs() % _fallbackPalette.length;
  return _fallbackPalette[paletteIndex];
}

IconData getCategoryIcon(String? category) {
  final key = (category ?? 'uncategorized').toLowerCase();
  return categoryIcons[key] ?? Icons.category;
}

/// Translates category names to localized strings
String getCategoryTranslation(BuildContext context, String? category) {
  final l10n = context.l10n;
  final key = (category ?? 'uncategorized').toLowerCase();
  
  // Map category names to their corresponding localization keys
  switch (key) {
    case 'transfers':
      return l10n.categoryTransfers;
    case 'shopping':
      return l10n.categoryShopping;
    case 'utilities':
      return l10n.categoryUtilities;
    case 'entertainment':
      return l10n.categoryEntertainment;
    case 'entertainment_subscriptions':
      return l10n.categoryEntertainmentSubscriptions;
    case 'restaurants':
      return l10n.categoryRestaurants;
    case 'food':
      return l10n.categoryFood;
    case 'groceries':
      return l10n.categoryGroceries;
    case 'transport':
      return l10n.categoryTransport;
    case 'transportation':
      return l10n.categoryTransportation;
    case 'travel':
      return l10n.categoryTravel;
    case 'flights':
      return l10n.categoryFlights;
    case 'vacation':
      return l10n.categoryVacation;
    case 'health':
      return l10n.categoryHealth;
    case 'medical':
      return l10n.categoryMedical;
    case 'text':
      return l10n.categoryText;
    case 'education':
      return l10n.categoryEducation;
    case 'tuition':
      return l10n.categoryTuition;
    case 'subscriptions':
      return l10n.categorySubscriptions;
    case 'services':
      return l10n.categoryServices;
    case 'housing':
      return l10n.categoryHousing;
    case 'rent':
      return l10n.categoryRent;
    case 'mortgage':
      return l10n.categoryMortgage;
    case 'bills':
      return l10n.categoryBills;
    case 'insurance':
      return l10n.categoryInsurance;
    case 'savings':
      return l10n.categorySavings;
    case 'investment':
      return l10n.categoryInvestment;
    case 'investments':
      return l10n.categoryInvestments;
    case 'income':
      return l10n.categoryIncome;
    case 'salary':
      return l10n.categorySalary;
    case 'bonus':
      return l10n.categoryBonus;
    case 'pets':
      return l10n.categoryPets;
    case 'kids':
      return l10n.categoryKids;
    case 'family':
      return l10n.categoryFamily;
    case 'gifts':
      return l10n.categoryGifts;
    case 'charity':
      return l10n.categoryCharity;
    case 'fees':
      return l10n.categoryFees;
    case 'loan':
      return l10n.categoryLoan;
    case 'loans':
      return l10n.categoryLoans;
    case 'debt':
      return l10n.categoryDebt;
    case 'personal care':
      return l10n.categoryPersonalCare;
    case 'beauty':
      return l10n.categoryBeauty;
    case 'misc':
      return l10n.categoryMisc;
    case 'uncategorized':
      return l10n.categoryUncategorized;
    default:
      // Fallback: capitalize first letter and return the rest as-is
      final fallbackCategory = category ?? 'uncategorized';
      return fallbackCategory.substring(0, 1).toUpperCase() + fallbackCategory.substring(1);
  }
}
