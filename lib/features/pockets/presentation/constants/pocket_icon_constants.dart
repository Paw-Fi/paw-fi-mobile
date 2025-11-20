import 'package:flutter/material.dart';

/// Shared constants for pocket/envelope icons
/// This ensures consistency across the app when displaying pocket icons
const pocketIconNames = [
  'shopping_bag',
  'restaurant',
  'directions_car',
  'home',
  'flight',
  'medical_services',
  'school',
  'pets',
  'sports_esports',
  'fitness_center',
  'local_cafe',
  'local_bar',
  'movie',
  'music_note',
  'savings',
  'account_balance',
];

/// Maps pocket icon names to Flutter IconData
/// Used to convert string icon names from the database to actual icons
IconData getPocketIconData(String? iconName) {
  switch (iconName) {
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_car':
      return Icons.directions_car;
    case 'home':
      return Icons.home;
    case 'flight':
      return Icons.flight;
    case 'medical_services':
      return Icons.medical_services;
    case 'school':
      return Icons.school;
    case 'pets':
      return Icons.pets;
    case 'sports_esports':
      return Icons.sports_esports;
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
    case 'account_balance':
      return Icons.account_balance;
    default:
      return Icons.savings_outlined;
  }
}
