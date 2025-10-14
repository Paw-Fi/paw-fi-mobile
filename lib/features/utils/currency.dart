import 'package:moneko/features/home/presentation/models/models.dart';

const Map<String, String> currencyOptions = {
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'AUD': r'$',
  'CAD': r'$',
  'NGN': '₦',
  'KES': 'KSh',
  'GHS': '₵',
};

const String _defaultCurrencySymbol = r'$';

String resolveCurrencySymbol(String? currencyCode) {
  final code = currencyCode?.trim().toUpperCase();
  if (code == null || code.isEmpty) {
    return _defaultCurrencySymbol;
  }

  return currencyOptions[code] ?? _defaultCurrencySymbol;
}

String getCurrencySymbol(UserContact? contact) {
  return resolveCurrencySymbol(contact?.preferredCurrency);
}

Map<String, String> getAvailableCurrencyOptions() {
  return Map.unmodifiable(currencyOptions);
}

bool isSupportedCurrencyCode(String? code) {
  if (code == null) return false;
  return currencyOptions.containsKey(code.toUpperCase());
}
