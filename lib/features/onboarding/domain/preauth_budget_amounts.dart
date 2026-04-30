import 'dart:math' as math;

class PreauthBudgetRange {
  const PreauthBudgetRange({
    required this.baseline,
    required this.min,
    required this.max,
    required this.rounding,
  });

  final double baseline;
  final double min;
  final double max;
  final double rounding;
}

PreauthBudgetRange preauthBudgetRangeForCurrency(String currencyCode) {
  final normalized = currencyCode.trim().toUpperCase();
  final baseline = _currencyBaselines[normalized] ?? 10000;
  final rounding = _currencyRounding[normalized] ?? _niceNumber(baseline / 10);
  final min =
      _currencyMinimums[normalized] ?? math.max(rounding, baseline * 0.1);
  final max = _currencyMaximums[normalized] ?? baseline * 3;

  return PreauthBudgetRange(
    baseline: baseline,
    min: min,
    max: max,
    rounding: rounding,
  );
}

double roundBudgetForCurrency(double amount, String currencyCode) {
  final range = preauthBudgetRangeForCurrency(currencyCode);
  if (!amount.isFinite || amount <= 0) {
    return range.min;
  }
  final rounded = (amount / range.rounding).round() * range.rounding;
  return rounded.clamp(range.min, range.max).toDouble();
}

double _niceNumber(double rawStep) {
  if (!rawStep.isFinite || rawStep <= 0) return 1;
  final exponent = (math.log(rawStep) / math.ln10).floor();
  final magnitude = math.pow(10.0, exponent).toDouble();
  final fraction = rawStep / magnitude;

  double niceFraction;
  if (fraction <= 1) {
    niceFraction = 1;
  } else if (fraction <= 5) {
    niceFraction = 5;
  } else {
    niceFraction = 10;
  }

  return math.max(1, niceFraction * magnitude);
}

const Map<String, double> _currencyBaselines = {
  'USD': 10000,
  'EUR': 10000,
  'GBP': 10000,
  'CHF': 10000,
  'SGD': 12000,
  'AUD': 10000,
  'CAD': 10000,
  'NZD': 10000,
  'HKD': 60000,
  'CNY': 20000,
  'COP': 40000000,
  'JPY': 300000,
  'KRW': 6000000,
  'MYR': 10000,
  'INR': 100000,
  'IDR': 15000000,
  'THB': 70000,
  'PHP': 70000,
  'VND': 25000000,
  'PYG': 20000000,
  'BRL': 12000,
  'MXN': 30000,
  'ZAR': 25000,
  'TRY': 70000,
  'NGN': 2000000,
  'PKR': 300000,
  'EGP': 70000,
  'ETB': 1250000,
  'GHS': 40000,
  'KES': 120000,
  'UAH': 250000,
  'RUB': 150000,
  'RSD': 120000,
  'HUF': 300000,
  'CZK': 60000,
  'PLN': 12000,
  'NOK': 50000,
  'SEK': 40000,
  'DKK': 40000,
  'AED': 35000,
  'SAR': 12000,
  'GTQ': 12000,
  'CLP': 900000,
  'DOP': 150000,
  'LKR': 300000,
  'JMD': 1500000,
  'MWK': 20000000,
  'XOF': 6000000,
};

const Map<String, double> _currencyMinimums = {
  'JPY': 50000,
};

const Map<String, double> _currencyMaximums = {};

const Map<String, double> _currencyRounding = {
  'USD': 50,
  'EUR': 50,
  'GBP': 50,
  'CHF': 50,
  'SGD': 50,
  'AUD': 50,
  'CAD': 50,
  'NZD': 50,
  'HKD': 500,
  'CNY': 100,
  'COP': 50000,
  'JPY': 5000,
  'KRW': 50000,
  'MYR': 50,
  'INR': 1000,
  'IDR': 500000,
  'THB': 500,
  'PHP': 500,
  'VND': 500000,
  'PYG': 500000,
  'BRL': 100,
  'MXN': 500,
  'ZAR': 500,
  'TRY': 1000,
  'NGN': 50000,
  'PKR': 5000,
  'EGP': 1000,
  'ETB': 1000,
  'GHS': 500,
  'KES': 5000,
  'UAH': 10000,
  'RUB': 5000,
  'RSD': 5000,
  'HUF': 10000,
  'CZK': 1000,
  'PLN': 100,
  'NOK': 1000,
  'SEK': 1000,
  'DKK': 1000,
  'AED': 500,
  'SAR': 100,
  'GTQ': 100,
  'CLP': 50000,
  'DOP': 5000,
  'LKR': 10000,
  'JMD': 50000,
  'MWK': 500000,
  'XOF': 5000,
};
