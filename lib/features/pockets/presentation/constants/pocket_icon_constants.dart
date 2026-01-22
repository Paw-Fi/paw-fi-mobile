import 'package:flutter/material.dart';

/// Shared constants for pocket/envelope icons
/// This ensures consistency across the app when displaying pocket icons
const pocketIconNames = [
  'account_balance',
  'account_balance_wallet',
  'apartment',
  'backpack',
  'bolt',
  'build_circle',
  'celebration',
  'child_care',
  'child_friendly',
  'cleaning_services',
  'coffee',
  'delete_outline',
  'diamond',
  'shopping_bag',
  'restaurant',
  'directions_car',
  'home',
  'house',
  'house_siding',
  'flight',
  'flight_takeoff',
  'fastfood',
  'favorite',
  'healing',
  'hotel',
  'inventory_2',
  'kitchen',
  'local_grocery_store',
  'map',
  'medical_services',
  'people',
  'policy',
  'priority_high',
  'ramen_dining',
  'receipt_long',
  'school',
  'pets',
  'sports_esports',
  'sports_soccer',
  'fitness_center',
  'local_cafe',
  'local_bar',
  'movie',
  'music_note',
  'self_improvement',
  'shield',
  'soap',
  'spa',
  'savings',
  'trending_up',
  'weekend',
  'wifi',
  'work',
];

/// Maps pocket icon names to Flutter IconData
/// Used to convert string icon names from the database to actual icons
IconData getPocketIconData(String? iconName) {
  switch (iconName) {
    case 'account_balance':
      return Icons.account_balance;
    case 'account_balance_wallet':
      return Icons.account_balance_wallet;
    case 'apartment':
      return Icons.apartment;
    case 'backpack':
      return Icons.backpack;
    case 'bolt':
      return Icons.bolt;
    case 'build_circle':
      return Icons.build_circle;
    case 'celebration':
      return Icons.celebration;
    case 'child_care':
      return Icons.child_care;
    case 'child_friendly':
      return Icons.child_friendly;
    case 'cleaning_services':
      return Icons.cleaning_services;
    case 'coffee':
      return Icons.local_cafe;
    case 'delete_outline':
      return Icons.delete_outline;
    case 'diamond':
      return Icons.diamond;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_car':
      return Icons.directions_car;
    case 'home':
      return Icons.home;
    case 'house':
      return Icons.house;
    case 'house_siding':
      return Icons.house_siding;
    case 'flight':
      return Icons.flight;
    case 'flight_takeoff':
      return Icons.flight_takeoff;
    case 'fastfood':
      return Icons.fastfood;
    case 'favorite':
      return Icons.favorite;
    case 'healing':
      return Icons.healing;
    case 'hotel':
      return Icons.hotel;
    case 'inventory_2':
      return Icons.inventory_2;
    case 'kitchen':
      return Icons.kitchen;
    case 'local_grocery_store':
      return Icons.local_grocery_store;
    case 'map':
      return Icons.map;
    case 'medical_services':
      return Icons.medical_services;
    case 'people':
      return Icons.people;
    case 'policy':
      return Icons.policy;
    case 'priority_high':
      return Icons.priority_high;
    case 'ramen_dining':
      return Icons.ramen_dining;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'school':
      return Icons.school;
    case 'pets':
      return Icons.pets;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'local_cafe':
      return Icons.local_cafe;
    case 'local_bar':
      return Icons.local_bar;
    case 'movie':
      return Icons.movie;
    case 'music_note':
      return Icons.music_note;
    case 'savings':
      return Icons.savings;
    case 'self_improvement':
      return Icons.self_improvement;
    case 'shield':
      return Icons.shield;
    case 'soap':
      return Icons.soap;
    case 'spa':
      return Icons.spa;
    case 'trending_up':
      return Icons.trending_up;
    case 'weekend':
      return Icons.weekend;
    case 'wifi':
      return Icons.wifi;
    case 'work':
      return Icons.work;
    default:
      return Icons.savings_outlined;
  }
}
