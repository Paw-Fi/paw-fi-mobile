class CurrencyRates {
  // Base Currency: USD (1.0)
  // To convert specific currency to USD: Amount / Rate
  // To convert USD to specific currency: Amount * Rate
  // To convert A to B: (Amount / RateA) * RateB

  // Rates are units of <currency> per 1 USD.
// Last updated: Tue, 03 Feb 2026 00:02:32 +0000 (source: open.er-api.com / ExchangeRate-API).
  static const Map<String, double> rates = {
    'USD': 1.0,
    'AED': 3.6725,
    'ARS': 1452.25,
    'AUD': 1.438541,
    'BRL': 5.259668,
    'CAD': 1.367158,
    'CHF': 0.778587,
    'CLP': 872.071166,
    'CNY': 6.951947,
    'CZK': 20.560576,
    'DKK': 6.3122,
    'DOP': 63.264178,
    'EGP': 47.085185,
    'EUR': 0.846294,
    'GBP': 0.731608,
    'GHS': 10.961152,
    'GTQ': 7.692866,
    'HKD': 7.810905,
    'HUF': 322.471388,
    'IDR': 16806.053031,
    'INR': 91.523929,
    'JPY': 155.348973,
    'JMD': 157.158571,
    'KES': 128.975801,
    'KRW': 1451.961052,
    'LKR': 309.350928,
    'MXN': 17.398047,
    'MYR': 3.941977,
    'MWK': 1743.789522,
    'NGN': 1389.026982,
    'NOK': 9.69353,
    'NZD': 1.664528,
    'PHP': 58.905709,
    'PEN': 3.367771,
    'PLN': 3.570934,
    'PKR': 280.066929,
    'PYG': 6711.53431,
    'RSD': 99.258129,
    'RON': 4.305581,
    'RUB': 76.731769,
    'SAR': 3.75,
    'SEK': 8.962244,
    'SGD': 1.272014,
    'THB': 31.576774,
    'TWD': 31.607991,
    'TRY': 43.497391,
    'UAH': 42.99175,
    'VND': 25955.156387,
    'ZAR': 16.069211,
    'MMK': 2104.444036,
    'JOD': 0.709,
    'SYP': 13000.0,
    'ZMW': 26.725894,
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
