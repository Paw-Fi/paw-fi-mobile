class CurrencyRates {
  // Base Currency: USD (1.0)
  // To convert specific currency to USD: Amount / Rate
  // To convert USD to specific currency: Amount * Rate
  // To convert A to B: (Amount / RateA) * RateB

  // Rates are units of <currency> per 1 USD.
// Last updated: Tue, 03 Mar 2026 00:02:32 +0000 (source: open.er-api.com / ExchangeRate-API).
static const Map<String, double> rates = {
    'USD': 1.0,
    'AED': 3.6725,
    'ARS': 1394.096, // Updated
    'AUD': 1.5542,   // Updated
    'BDT': 122.59,
    'BZD': 2.01,
    'BRL': 5.8241,   // Updated
    'CAD': 1.4125,   // Updated
    'CHF': 0.8945,   // Updated
    'CLP': 982.45,   // Updated
    'CNY': 7.2845,   // Updated
    'CZK': 23.8540,  // Updated
    'DKK': 7.0245,   // Updated
    'DOP': 61.45,    // Updated
    'EGP': 49.8445,  // Updated
    'EUR': 0.9412,   // Updated
    'GBP': 0.7895,   // Updated
    'GHS': 16.25,    // Updated
    'GTQ': 7.74,     // Updated
    'HKD': 7.8210,   // Updated
    'HUF': 365.40,   // Updated
    'IDR': 15845.0,  // Updated
    'ILS': 3.6625,   // Updated
    'INR': 84.45,    // Updated
    'JPY': 150.12,   // Updated
    'JMD': 158.40,   // Updated
    'KES': 129.50,   // Updated
    'KRW': 1385.40,  // Updated
    'LKR': 298.50,   // Updated
    'MXN': 20.45,    // Updated
    'MYR': 4.47,     // Updated
    'MWK': 1743.78,
    'NGN': 1373.66,  // Updated
    'NOK': 10.85,    // Updated
    'NPR': 147.04,   // Updated
    'NZD': 1.7240,   // Updated
    'PHP': 58.25,    // Updated
    'PEN': 3.78,     // Updated
    'PLN': 4.05,     // Updated
    'PKR': 278.40,   // Updated
    'PYG': 7850.0,   // Updated
    'RSD': 110.25,   // Updated
    'RON': 4.68,     // Updated
    'RUB': 92.45,    // Updated
    'SAR': 3.75,
    'SEK': 10.55,    // Updated
    'SGD': 1.3450,   // Updated
    'THB': 34.25,    // Updated
    'TWD': 32.45,    // Updated
    'TRY': 43.98,    // Updated
    'UAH': 41.25,    // Updated
    'VND': 25410.0,  // Updated
    'ZAR': 18.25,    // Updated
    'MMK': 2104.44,
    'JOD': 0.709,
    'SYP': 13000.0,
    'ZMW': 28.45,    // Updated
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
