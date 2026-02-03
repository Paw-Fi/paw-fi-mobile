class CurrencyRates {
  // Base Currency: USD (1.0)
  // To convert specific currency to USD: Amount / Rate
  // To convert USD to specific currency: Amount * Rate
  // To convert A to B: (Amount / RateA) * RateB

  // NOTE FOR USER: Paste your full list of currency rates here.
  // Ensure the base currency is USD = 1.0.
  static const Map<String, double> rates = {
    'USD': 1.0,
    'EUR': 0.92, // Euro
    'GBP': 0.78, // British Pound
    'JPY': 150.0, // Japanese Yen
    'CAD': 1.35, // Canadian Dollar
    'AUD': 1.52, // Australian Dollar
    'CHF': 0.88, // Swiss Franc
    'CNY': 7.20, // Chinese Yuan
    'HKD': 7.82, // Hong Kong Dollar
    'NZD': 1.63, // New Zealand Dollar
    'SGD': 1.34, // Singapore Dollar
    'KRW': 1330.0, // South Korean Won
    'INR': 83.0, // Indian Rupee
    'BRL': 4.95, // Brazilian Real
    'RUB': 92.5, // Russian Ruble
    'ZAR': 19.0, // South African Rand
    'MXN': 17.0, // Mexican Peso
    'SAR': 3.75, // Saudi Riyal
    'AED': 3.67, // United Arab Emirates Dirham
    'TRY': 31.0, // Turkish Lira
    // Add more currencies here...
  };

  /// Converts an [amount] from [fromCurrency] to [toCurrency].
  /// Returns the original amount if currency codes are invalid or missing.
  static double convert(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;

    // Normalize codes to uppercase
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();

    // Check if rates exist
    if (!rates.containsKey(from) || !rates.containsKey(to)) {
      // Fallback: If we can't convert, return the original amount
      // (or handle error as preferred, here we fail silent/safe for UI)
      return amount;
    }

    final fromRate = rates[from]!;
    final toRate = rates[to]!;

    // Math: Convert 'from' to USD, then USD to 'to'
    // USD Amount = amount / fromRate
    // Final Amount = USD Amount * toRate
    return (amount / fromRate) * toRate;
  }
}
