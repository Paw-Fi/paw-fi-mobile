import 'package:flutter/material.dart';

final Map<String, Color> categoryColors = {
  'transfers': const Color(0xFF8B5CF6),
  'shopping': const Color(0xFFEC4899),
  'utilities': const Color(0xFF3B82F6),
  'entertainment': const Color(0xFFF59E0B),
  'restaurants': const Color(0xFF10B981),
  'groceries': const Color(0xFF06B6D4),
  'transport': const Color(0xFFEF4444),
  'health': const Color(0xFF14B8A6),
  'uncategorized': Colors.grey,
};

Color getCategoryColor(String? category) {
  final key = (category ?? 'uncategorized').toLowerCase();
  return categoryColors[key] ?? Colors.grey;
}

IconData getCategoryIcon(String? category) {
  final key = (category ?? 'uncategorized').toLowerCase();
  switch (key) {
    case 'transfers':
      return Icons.swap_horiz;
    case 'shopping':
      return Icons.shopping_bag;
    case 'utilities':
      return Icons.home;
    case 'entertainment':
      return Icons.sports_esports;
    case 'restaurants':
      return Icons.restaurant;
    case 'groceries':
      return Icons.shopping_cart;
    case 'transport':
      return Icons.directions_car;
    case 'health':
      return Icons.favorite;
    default:
      return Icons.category;
  }
}
