import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

// Preserve the icon keys already stored on wallets, pockets, and templates.
const _walletPocketImageNames = <String, String>{
  'wallet': 'wallet',
  'account_balance_wallet': 'account-balance-wallet',
  'checking': 'checking',
  'account_balance': 'account-balance',
  'bank': 'bank',
  'joint': 'shared-family',
  'people': 'people',
  'cash': 'cash',
  'cash_envelope': 'cash-payments',
  'card': 'credit-card',
  'debt': 'debt',
  'paypal': 'money-payments',
  'savings': 'savings',
  'reserve': 'protected-secure',
  'shield': 'shield',
  'education': 'education',
  'school': 'school',
  'backpack': 'backpack',
  'medical': 'medical-healthcare',
  'medical_services': 'medical-services',
  'healing': 'healing',
  'favorite': 'favorite',
  'emergency': 'health-medical',
  'allowance': 'kids-baby',
  'child_care': 'child-care',
  'child_friendly': 'child-friendly',
  'pet': 'pet',
  'pets': 'pets',
  'investment': 'investments',
  'trending_up': 'trending-up',
  'brokerage': 'trading',
  'gold': 'rewards',
  'diamond': 'diamond',
  'retirement': 'retirement',
  'loan': 'bills-financial-documents',
  'mortgage': 'mortgage',
  'tax': 'bills-receipts',
  'receipt_long': 'receipt-long',
  'budget': 'budget',
  'category': 'category',
  'priority_high': 'priority-high',
  'business': 'business',
  'work': 'work',
  'insurance': 'insurance',
  'policy': 'policy',
  'crypto': 'crypto',
  'travel': 'travel',
  'plane': 'plane',
  'flight': 'flight',
  'flight_takeoff': 'flight-takeoff',
  'map': 'map',
  'home': 'home',
  'house': 'house',
  'apartment': 'apartment',
  'house_siding': 'house-siding',
  'local_cafe': 'local-cafe',
  'analytics': 'analytics',
  'custom-icon-image': 'custom-icon-image',
};

const _pocketCategoryImageKeys = <String, String>{
  'bolt': 'electricity',
  'build_circle': 'home repairs',
  'celebration': 'parties & hosting',
  'cleaning_services': 'cleaning supplies',
  'coffee': 'coffee & tea',
  'delete_outline': 'trash & recycling',
  'shopping_bag': 'clothing & shoes',
  'restaurant': 'restaurants',
  'directions_car': 'transportation',
  'fastfood': 'takeout & delivery',
  'hotel': 'hotels',
  'inventory_2': 'storage',
  'kitchen': 'appliances',
  'local_grocery_store': 'groceries',
  'ramen_dining': 'food & drinks',
  'sports_esports': 'games & apps',
  'sports_soccer': 'sports & exercise',
  'fitness_center': 'fitness & gym',
  'local_bar': 'bars & drinks',
  'movie': 'movies & shows',
  'music_note': 'music & streaming',
  'self_improvement': 'mental health',
  'soap': 'personal care',
  'spa': 'spa & massage',
  'weekend': 'furniture',
  'wifi': 'internet',
};

String getWalletPocketIconImageAsset(
  String? iconName, {
  String fallback = 'wallet',
}) {
  final key = iconName?.trim().toLowerCase() ?? '';
  final category = _pocketCategoryImageKeys[key];
  if (category != null) {
    return getCategoryImageAsset(category)!;
  }
  final filename = _walletPocketImageNames[key] ??
      (_walletPocketImageNames.values.contains(key) ? key : fallback);
  return 'lib/assets/images/wallet-pockets/$filename.png';
}

List<String> uniqueWalletPocketIconNames(
  Iterable<String> iconNames, {
  String fallback = 'wallet',
}) {
  final seenAssets = <String>{};
  return iconNames
      .where((iconName) => seenAssets.add(
            getWalletPocketIconImageAsset(iconName, fallback: fallback),
          ))
      .toList(growable: false);
}

Widget buildWalletPocketIcon(
  String? iconName, {
  double size = 20,
  String fallback = 'wallet',
}) {
  return Image.asset(
    getWalletPocketIconImageAsset(iconName, fallback: fallback),
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => SizedBox.square(dimension: size),
  );
}

Widget buildPocketIcon(String? iconName, {double size = 20}) =>
    buildWalletPocketIcon(iconName, size: size, fallback: 'budget');
