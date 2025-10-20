import 'package:flutter/foundation.dart';
import 'package:moneko/features/home/presentation/models/models.dart';

const Map<String, String> currencyOptions = {
  'AED': 'د.إ',
  'AUD': 'A\$',
  'BRL': 'R\$',
  'CAD': 'C\$',
  'CHF': 'CHF',
  'CNY': '¥',
  'CZK': 'Kč',
  'DKK': 'kr',
  'DOP': 'RD\$',
  'EGP': 'E£',
  'EUR': '€',
  'GHS': '₵',
  'GBP': '£',
  'HKD': 'HK\$',
  'IDR': 'Rp',
  'INR': '₹',
  'JPY': '¥',
  'KES': 'KSh',
  'KRW': '₩',
  'MXN': 'Mex\$',
  'MYR': 'RM',
  'NGN': '₦',
  'NOK': 'kr',
  'NZD': 'NZ\$',
  'PHP': '₱',
  'PLN': 'zł',
  'RUB': '₽',
  'SAR': 'ر.س',
  'SEK': 'kr',
  'SGD': 'S\$',
  'THB': '฿',
  'TRY': '₺',
  'USD': '\$',
  'VND': '₫',
  'ZAR': 'R',
};

const String _defaultCurrencySymbol = r'$';

String resolveCurrencySymbol(String? currencyCode) {
  final code = currencyCode?.trim().toUpperCase();
  if (code == null || code.isEmpty) {
    return _defaultCurrencySymbol;
  }
  
  // Validate currency code before use
  if (!isSupportedCurrencyCode(code)) {
    if (kDebugMode) {
      debugPrint('⚠️ Invalid currency code: $code, falling back to default');
    }
    return _defaultCurrencySymbol;
  }

  return currencyOptions[code]!; // Safe to use ! now after validation
}

String getCurrencySymbol(UserContact? contact) {
  return resolveCurrencySymbol(contact?.preferredCurrency);
}

Map<String, String> getAvailableCurrencyOptions() {
  return Map.unmodifiable(currencyOptions);
}

bool isSupportedCurrencyCode(String? code) {
  if (code == null || code.isEmpty) return false;
  final upper = code.toUpperCase().trim();
  
  // Only allow 3-letter ISO codes
  if (upper.length != 3) return false;
  
  // Only allow A-Z characters (security: prevents SQL injection and special characters)
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(upper)) return false;
  
  return currencyOptions.containsKey(upper);
}
