import 'package:flutter/material.dart';

/// Stable string keys for Material icons used by custom categories.
///
/// We store the key (not codepoint) in Supabase so we can evolve UI safely.
const Map<String, IconData> customCategoryIconOptions = {
  // General & Essential
  'tag': Icons.sell,
  'star': Icons.star,
  'help': Icons.help_outline,
  'bolt': Icons.bolt,
  'leaf': Icons.eco,

  // Home & Living
  'home': Icons.home,
  'apartment': Icons.apartment,
  'tools': Icons.handyman,
  'cleaning': Icons.cleaning_services,
  'chair': Icons.chair,
  'kitchen': Icons.kitchen,

  // Shopping & Food
  'shopping': Icons.shopping_bag,
  'cart': Icons.shopping_cart,
  'food': Icons.fastfood,
  'coffee': Icons.local_cafe,
  'restaurant': Icons.restaurant,
  'delivery': Icons.delivery_dining,
  'grocery': Icons.local_grocery_store,

  // Transport & Travel
  'car': Icons.directions_car,
  'bus': Icons.directions_bus,
  'train': Icons.train,
  'plane': Icons.flight,
  'gas': Icons.local_gas_station,
  'parking': Icons.local_parking,

  // Health & Personal Care
  'health': Icons.favorite,
  'medical': Icons.medical_services,
  'hospital': Icons.local_hospital,
  'fitness': Icons.fitness_center,
  'spa': Icons.spa,

  // Family & Pets
  'people': Icons.groups,
  'child': Icons.child_care,
  'baby': Icons.child_friendly,
  'pet': Icons.pets,

  // Education & Work
  'book': Icons.menu_book,
  'school': Icons.school,
  'work': Icons.work,
  'laptop': Icons.laptop_mac,
  'business': Icons.business_center,

  // Finance & Bills
  'bill': Icons.receipt_long,
  'bank': Icons.account_balance_wallet,
  'money': Icons.attach_money,
  'card': Icons.credit_card,
  'savings': Icons.savings,
  'chart': Icons.trending_up,
  'taxes': Icons.account_balance,
  'shield': Icons.security,

  // Entertainment & Tech
  'music': Icons.music_note,
  'game': Icons.sports_esports,
  'movie': Icons.movie,
  'party': Icons.celebration,
  'gift': Icons.card_giftcard,
  'phone': Icons.phone_iphone,
  'tv': Icons.tv,
};

IconData customCategoryIconForKey(String? key) {
  if (key == null || key.isEmpty) return Icons.category;
  return customCategoryIconOptions[key] ?? Icons.category;
}
