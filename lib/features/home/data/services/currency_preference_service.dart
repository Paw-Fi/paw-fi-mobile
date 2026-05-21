import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing currency preferences in local storage
/// Provides a clean abstraction over SharedPreferences for currency-related settings
class CurrencyPreferenceService {
  static const String _selectedCurrencyKey = 'selected_currency';
  static const String _selectedCurrenciesKey = 'selected_currencies';
  static const String _currencyOrderKey = 'currency_order';

  // In-memory cache to reduce SharedPreferences reads
  String? _cachedCurrency;
  List<String>? _cachedSelectedCurrencies;
  List<String>? _cachedOrder;

  /// Get the selected currency (cached for performance)
  /// Returns null if no currency has been selected
  Future<String?> getSelectedCurrency() async {
    if (_cachedCurrency != null) return _cachedCurrency;

    final prefs = await SharedPreferences.getInstance();
    _cachedCurrency = prefs.getString(_selectedCurrencyKey);
    return _cachedCurrency;
  }

  /// Set the selected currency and update cache
  Future<void> setSelectedCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCurrencyKey, currency);
    _cachedCurrency = currency;
  }

  /// Clear the selected currency preference
  Future<void> clearSelectedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedCurrencyKey);
    _cachedCurrency = null;
  }

  /// Get locally selected currencies for filtering dashboards and lists.
  /// Returns null if the user has not configured a multi-currency selection.
  Future<List<String>?> getSelectedCurrencies() async {
    if (_cachedSelectedCurrencies != null) return _cachedSelectedCurrencies;

    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_selectedCurrenciesKey);
    if (values == null) return null;

    _cachedSelectedCurrencies = _normalizeCurrencyList(values);
    return _cachedSelectedCurrencies;
  }

  /// Set the local multi-currency filter selection.
  Future<void> setSelectedCurrencies(List<String> currencies) async {
    final normalized = _normalizeCurrencyList(currencies);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedCurrenciesKey, normalized);
    _cachedSelectedCurrencies = normalized;
  }

  /// Clear only the local multi-currency filter selection.
  Future<void> clearSelectedCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedCurrenciesKey);
    _cachedSelectedCurrencies = null;
  }

  /// Get custom currency display order
  /// Returns null if no custom order has been set
  Future<List<String>?> getCurrencyOrder() async {
    if (_cachedOrder != null) return _cachedOrder;

    final prefs = await SharedPreferences.getInstance();
    final orderString = prefs.getString(_currencyOrderKey);
    if (orderString != null && orderString.isNotEmpty) {
      _cachedOrder = orderString.split(',');
    }
    return _cachedOrder;
  }

  /// Set custom currency display order
  Future<void> setCurrencyOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyOrderKey, order.join(','));
    _cachedOrder = order;
  }

  /// Clear all currency preferences
  Future<void> clearAll() async {
    await clearSelectedCurrency();
    await clearSelectedCurrencies();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currencyOrderKey);
    _cachedOrder = null;
  }

  List<String> _normalizeCurrencyList(List<String> currencies) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final currency in currencies) {
      final code = currency.trim().toUpperCase();
      if (code.isEmpty || seen.contains(code)) continue;
      seen.add(code);
      normalized.add(code);
    }
    return normalized;
  }
}
