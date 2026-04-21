import 'package:flutter/material.dart';

IconData resolveWalletIcon(String? iconName) {
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
    case 'investment':
      return Icons.trending_up_rounded;
    case 'retirement':
      return Icons.account_balance_rounded;
    case 'loan':
      return Icons.request_quote_rounded;
    case 'mortgage':
      return Icons.house_rounded;
    case 'insurance':
      return Icons.verified_user_rounded;
    case 'business':
      return Icons.business_center_rounded;
    case 'crypto':
      return Icons.currency_bitcoin_rounded;
    case 'checking':
      return Icons.account_balance_rounded;
    case 'joint':
      return Icons.groups_rounded;
    case 'allowance':
      return Icons.child_care_rounded;
    case 'education':
      return Icons.school_rounded;
    case 'medical':
      return Icons.local_hospital_rounded;
    case 'tax':
      return Icons.receipt_long_rounded;
    case 'reserve':
      return Icons.shield_rounded;
    case 'brokerage':
      return Icons.candlestick_chart_rounded;
    case 'gold':
      return Icons.workspace_premium_rounded;
    case 'cash_envelope':
      return Icons.local_atm_rounded;
    case 'pet':
      return Icons.pets_rounded;
    case 'paypal':
      return Icons.payments_rounded;
    default:
      return Icons.account_balance_wallet_rounded;
  }
}

Color parseWalletColor(String? colorHex, Color fallback) {
  final raw = (colorHex ?? '').trim();
  if (!raw.startsWith('#') || raw.length < 7) return fallback;
  final hex = raw.substring(1, 7);
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return fallback;
  return Color(0xFF000000 | parsed);
}
