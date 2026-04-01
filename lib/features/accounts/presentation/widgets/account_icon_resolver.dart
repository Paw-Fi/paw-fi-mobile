import 'package:flutter/material.dart';

IconData resolveAccountIcon(String? iconName) {
  final key = (iconName ?? '').trim().toLowerCase();
  switch (key) {
    case 'wallet':
    case 'account_balance_wallet':
      return Icons.account_balance_wallet_rounded;
    case 'savings':
      return Icons.savings_rounded;
    case 'debt':
      return Icons.credit_card_rounded;
    case 'emergency':
      return Icons.health_and_safety_rounded;
    case 'budget':
      return Icons.pie_chart_rounded;
    case 'bank':
      return Icons.account_balance_rounded;
    case 'card':
      return Icons.credit_card;
    case 'cash':
      return Icons.payments_rounded;
    case 'travel':
    case 'plane':
      return Icons.flight_takeoff_rounded;
    case 'home':
      return Icons.home_rounded;
    default:
      return Icons.account_balance_wallet_rounded;
  }
}

Color parseAccountColor(String? colorHex, Color fallback) {
  final raw = (colorHex ?? '').trim();
  if (!raw.startsWith('#') || raw.length < 7) return fallback;
  final hex = raw.substring(1, 7);
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return fallback;
  return Color(0xFF000000 | parsed);
}
