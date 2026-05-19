class CurrencyRateTable {
  const CurrencyRateTable({
    required this.baseCurrency,
    required this.rates,
    this.fetchedAt,
    this.source,
    this.isStale = false,
  });

  final String baseCurrency;
  final Map<String, double> rates;
  final DateTime? fetchedAt;
  final String? source;
  final bool isStale;

  factory CurrencyRateTable.fromJson(Map<String, dynamic> json) {
    final rawRates = json['rates'];
    final parsedRates = <String, double>{};
    if (rawRates is Map) {
      for (final entry in rawRates.entries) {
        final code = entry.key.toString().trim().toUpperCase();
        final value = entry.value;
        final rate = value is num
            ? value.toDouble()
            : value is String
                ? double.tryParse(value)
                : null;
        if (code.isNotEmpty && rate != null && rate > 0) {
          parsedRates[code] = rate;
        }
      }
    }

    final fetchedAtRaw = json['fetchedAt'] ?? json['fetched_at'];
    return CurrencyRateTable(
      baseCurrency: (json['baseCurrency'] ?? json['base_currency'] ?? 'USD')
          .toString()
          .trim()
          .toUpperCase(),
      rates: parsedRates,
      fetchedAt: fetchedAtRaw == null
          ? null
          : DateTime.tryParse(fetchedAtRaw.toString()),
      source: json['source']?.toString(),
      isStale: json['isStale'] == true || json['is_stale'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseCurrency': baseCurrency,
        'rates': rates,
        if (fetchedAt != null)
          'fetchedAt': fetchedAt!.toUtc().toIso8601String(),
        if (source != null) 'source': source,
        'isStale': isStale,
      };

  double convert(double amount, String fromCurrency, String toCurrency) {
    return CurrencyRates.convertWithRates(
      amount,
      fromCurrency,
      toCurrency,
      rates,
    );
  }
}

class CurrencyRates {
  // Base Currency: USD (1.0)
  // To convert specific currency to USD: Amount / Rate
  // To convert USD to specific currency: Amount * Rate
  // To convert A to B: (Amount / RateA) * RateB

// Rates are units of <currency> per 1 USD.
// Last updated: Wed, 06 May 2026 00:02:31 +0000 (source: open.er-api.com / ExchangeRate-API).
  static const Map<String, double> rates = {
    'USD': 1.0,
    'AED': 3.6725,
    'ARS': 1395.1909,
    'AUD': 1.391429,
    'BDT': 122.744284,
    'BZD': 2.0,
    'BRL': 4.942622,
    'CAD': 1.360999,
    'CHF': 0.782642,
    'CLP': 912.486453,
    'CNY': 6.8399,
    'COP': 3731.053097,
    'CZK': 20.845189,
    'DKK': 6.378283,
    'DOP': 59.584894,
    'DZD': 132.512019,
    'EGP': 53.691296,
    'ETB': 156.305041,
    'EUR': 0.854338,
    'GBP': 0.737688,
    'GHS': 11.225852,
    'GTQ': 7.637151,
    'HKD': 7.835985,
    'HUF': 309.123813,
    'IDR': 17431.73152,
    'ILS': 2.943936,
    'INR': 95.312484,
    'JPY': 157.672786,
    'JMD': 157.49548,
    'KES': 129.179288,
    'KRW': 1469.385911,
    'LKR': 319.752066,
    'MXN': 17.389514,
    'MYR': 3.963291,
    'MWK': 1742.440452,
    'NGN': 1366.120815,
    'NOK': 9.249454,
    'NPR': 152.499536,
    'NZD': 1.695767,
    'PHP': 61.554354,
    'PEN': 3.499217,
    'PLN': 3.630686,
    'PKR': 279.010022,
    'PYG': 6196.802902,
    'RSD': 100.451526,
    'RON': 4.465543,
    'RUB': 75.472926,
    'SAR': 3.75,
    'SEK': 9.260373,
    'SGD': 1.275701,
    'THB': 32.537811,
    'TWD': 31.618685,
    'TRY': 45.244809,
    'UAH': 44.003978,
    'VND': 26213.47859,
    'ZAR': 16.631956,
    'MMK': 2099.893809,
    'JOD': 0.709,
    'SYP': 112.360994,
    'ZMW': 18.853683,
    'XOF': 560.395083,
    'CRC': 455.121888,
    'XAF': 560.395083,
  };

  /// Converts an [amount] from [fromCurrency] to [toCurrency].
  /// Returns the original amount if currency codes are invalid or missing.
  static double convert(double amount, String fromCurrency, String toCurrency) {
    return convertWithRates(amount, fromCurrency, toCurrency, rates);
  }

  static double convertWithRates(
    double amount,
    String fromCurrency,
    String toCurrency,
    Map<String, double> sourceRates,
  ) {
    if (fromCurrency == toCurrency) return amount;

    // Normalize codes to uppercase
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();

    // Check if rates exist
    if (!sourceRates.containsKey(from) || !sourceRates.containsKey(to)) {
      // Fallback: If we can't convert, return the original amount
      // (or handle error as preferred, here we fail silent/safe for UI)
      return amount;
    }

    final fromRate = sourceRates[from]!;
    final toRate = sourceRates[to]!;

    // Math: Convert 'from' to USD, then USD to 'to'
    // USD Amount = amount / fromRate
    // Final Amount = USD Amount * toRate
    return (amount / fromRate) * toRate;
  }
}
