const Map<String, String> _currencySymbols = {
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'USD': '\$',
};

const String _defaultCurrencySymbol = '\$';
  
String resolveCurrencySymbol(String? currencyCode) {
  final code = currencyCode?.trim().toUpperCase();
  if (code == null || code.isEmpty) {
    return _defaultCurrencySymbol;
  }

  return _currencySymbols[code] ?? _defaultCurrencySymbol;
}
