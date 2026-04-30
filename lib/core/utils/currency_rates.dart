class CurrencyRates {
  // Base Currency: USD (1.0)
  // To convert specific currency to USD: Amount / Rate
  // To convert USD to specific currency: Amount * Rate
  // To convert A to B: (Amount / RateA) * RateB

  // Rates are units of <currency> per 1 USD.
// Last updated: 27 Apr 2026 00:02:32 +0000 (source: open.er-api.com / ExchangeRate-API).
static const Map<String, double> rates = {
  'USD': 1.0,
  'AED': 3.6725,
  'ARS': 1397.2063,
  'AUD': 1.400116,
  'BDT': 122.826174,
  'BZD': 2.0,
  'BRL': 4.989744,
  'CAD': 1.367654,
  'CHF': 0.786439,
  'CLP': 895.458534,
  'CNY': 6.841274,
  'COP': 4200.0,
  'CZK': 20.792137,
  'DKK': 6.373198,
  'DOP': 59.570551,
  'DZD': 132.450964,
  'EGP': 52.669544,
  'ETB': 125.0,
  'EUR': 0.854233,
  'GBP': 0.740223,
  'GHS': 11.113256,
  'GTQ': 7.637537,
  'HKD': 7.835287,
  'HUF': 311.970982,
  'IDR': 17218.060413,
  'ILS': 2.984365,
  'INR': 94.340265,
  'JPY': 159.540595,
  'JMD': 157.63099,
  'KES': 129.371573,
  'KRW': 1476.462523,
  'LKR': 317.368174,
  'MXN': 17.41027,
  'MYR': 3.964955,
  'MWK': 1735.8552,
  'NGN': 1352.76852,
  'NOK': 9.32879,
  'NPR': 150.944259,
  'NZD': 1.703252,
  'PHP': 60.740568,
  'PEN': 3.467555,
  'PLN': 3.623251,
  'PKR': 278.773042,
  'PYG': 6306.554847,
  'RSD': 100.216187,
  'RON': 4.346755,
  'RUB': 75.322373,
  'SAR': 3.75,
  'SEK': 9.244999,
  'SGD': 1.276897,
  'THB': 32.402494,
  'TWD': 31.488823,
  'TRY': 45.043141,
  'UAH': 43.953264,
  'VND': 26178.015881,
  'ZAR': 16.576855,
  'MMK': 2097.441627,
  'JOD': 0.709,
  'SYP': 112.518772,
  'ZMW': 18.908195,
  'XOF': 605.0,
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
