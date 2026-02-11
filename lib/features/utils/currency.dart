import 'package:flutter/foundation.dart';
import 'package:moneko/features/home/presentation/models/models.dart';

const Map<String, String> currencyOptions = {
  'AED': 'د.إ',
  'ARS': 'ARS\$',
  'AUD': 'A\$',
  'BRL': 'R\$',
  'CAD': 'C\$',
  'CHF': 'CHF',
  'CLP': 'CLP\$',
  'CNY': '¥',
  'CZK': 'Kč',
  'DKK': 'kr',
  'DOP': 'RD\$',
  'EGP': 'E£',
  'EUR': '€',
  'GBP': '£',
  'GHS': '₵',
  'GTQ': 'Q',
  'HKD': 'HK\$',
  'HUF': 'Ft',
  'IDR': 'Rp',
  'INR': '₹',
  'JPY': '¥',
  'JMD': 'J\$',
  'KES': 'KSh',
  'KRW': '₩',
  'LKR': 'Rs',
  'MXN': 'MX\$',
  'MYR': 'RM',
  'MWK': 'MK',
  'NGN': '₦',
  'NOK': 'kr',
  'NZD': 'NZ\$',
  'PHP': '₱',
  'PEN': 'S/',
  'PLN': 'zł',
  'PKR': '₨',
  'PYG': '₲',
  'RSD': 'Дин.',
  'RON': 'RON',
  'RUB': '₽',
  'SAR': 'ر.س',
  'SEK': 'kr',
  'SGD': 'S\$',
  'THB': '฿',
  'TWD': 'NT\$',
  'TRY': '₺',
  'UAH': '₴',
  'USD': '\$',
  'VND': '₫',
  'ZAR': 'R',
  'MMK': 'Ks',
  'JOD': 'د.أ',
  'SYP': '£S',
};

const String _defaultCurrencySymbol = r'$';

/// Canonicalize various currency notations/symbols to 3-letter ISO codes
/// Returns uppercased 3-letter code if recognized, otherwise returns the
/// original uppercased trimmed input (which may or may not be valid).
String? canonicalizeCurrencyCode(String? code) {
  if (code == null) return null;
  final raw = code.trim().toUpperCase();
  if (raw.isEmpty) return null;

  // Direct 3-letter codes
  if (raw.length == 3) {
    return raw;
  }

  // Common symbol/alias mappings we see from OCR or legacy data
  final aliases = <String, String>{
    'US\$': 'USD',
    'A\$': 'AUD',
    'C\$': 'CAD',
    'S\$': 'SGD',
    'HK\$': 'HKD',
    'NZ\$': 'NZD',
    'MX\$': 'MXN',
    'R\$': 'BRL',
    // South African Rand often saved as just 'R'
    'R': 'ZAR',
    // Kenyan Shilling
    'KSH': 'KES',
    // Jamaican Dollar
    'J\$': 'JMD',
    // Malawi Kwacha
    'MK': 'MWK',
    '£S': 'SYP',
  };

  if (aliases.containsKey(raw)) {
    return aliases[raw];
  }

  // Fallback: unknown non-ISO string → null (will resolve to default symbol)
  return null;
}

String resolveCurrencySymbol(String? currencyCode) {
  final code = canonicalizeCurrencyCode(currencyCode);
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

/// Formats a monetary amount with smart decimal handling:
/// - Whole numbers show without decimals (e.g., 50.00 → "50")
/// - Numbers with cents show 2 decimals (e.g., 50.25 → "50.25")
///
/// Examples:
/// - formatAmount(50.0) → "50"
/// - formatAmount(50.5) → "50.50"
/// - formatAmount(50.25) → "50.25"
/// - formatAmount(0.0) → "0"
String formatAmount(double amount) {
  // Check if the amount is a whole number
  if (amount == amount.truncate()) {
    // No decimal places needed
    return amount.truncate().toString();
  } else {
    // Show 2 decimal places
    return amount.toStringAsFixed(2);
  }
}

/// Formats a monetary amount with currency symbol and smart decimal handling
///
/// Examples:
/// - formatCurrency(50.0, 'USD') → "$50"
/// - formatCurrency(50.25, 'USD') → "$50.25"
/// - formatCurrency(100.5, 'EUR') → "€100.50"
String formatCurrency(double amount, String? currencyCode) {
  final symbol = resolveCurrencySymbol(currencyCode);
  final formattedAmount = formatAmount(amount);
  return '$symbol$formattedAmount';
}
