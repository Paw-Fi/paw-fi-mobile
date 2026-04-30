import 'dart:math' as math;

import 'package:moneko/features/utils/currency.dart';

const Map<String, double> pocketCurrencyBudgetBaselines = {
  // Keep in sync with currencyOptions in features/utils/currency.dart.
  'AED': 35000,
  'ARS': 10000000,
  'AUD': 10000,
  'BDT': 500000,
  'BZD': 20000,
  'BRL': 12000,
  'CAD': 10000,
  'CHF': 10000,
  'CLP': 900000,
  'CNY': 20000,
  'COP': 40000000,
  'CZK': 60000,
  'DKK': 40000,
  'DOP': 150000,
  'DZD': 1500000,
  'EGP': 70000,
  'ETB': 1250000,
  'EUR': 10000,
  'GBP': 10000,
  'GHS': 40000,
  'GTQ': 12000,
  'HKD': 60000,
  'HUF': 300000,
  'IDR': 15000000,
  'ILS': 35000,
  'INR': 100000,
  'JPY': 300000,
  'JMD': 1500000,
  'KES': 120000,
  'KRW': 6000000,
  'LKR': 300000,
  'MXN': 30000,
  'MYR': 10000,
  'MWK': 20000000,
  'NGN': 2000000,
  'NOK': 50000,
  'NPR': 700000,
  'NZD': 10000,
  'PHP': 70000,
  'PEN': 30000,
  'PLN': 12000,
  'PKR': 300000,
  'PYG': 20000000,
  'RSD': 120000,
  'RON': 50000,
  'RUB': 150000,
  'SAR': 12000,
  'SEK': 40000,
  'SGD': 12000,
  'THB': 70000,
  'TWD': 300000,
  'TRY': 70000,
  'UAH': 250000,
  'USD': 10000,
  'VND': 25000000,
  'ZAR': 25000,
  'MMK': 5000000,
  'JOD': 7000,
  'SYP': 50000000,
  'ZMW': 250000,
  'XOF': 6000000,
};

String _normalizePocketCurrencyCode(String currencyCode) {
  final normalizedCode = currencyCode.trim().toUpperCase();
  return isSupportedCurrencyCode(normalizedCode) ? normalizedCode : 'USD';
}

double pocketCurrencyBaselineMax(String currencyCode) {
  const defaultBaseline = 10000.0;
  final normalizedCode = _normalizePocketCurrencyCode(currencyCode);
  return pocketCurrencyBudgetBaselines[normalizedCode] ?? defaultBaseline;
}

double pocketCurrencyChunk(String currencyCode) {
  final baseline = pocketCurrencyBaselineMax(currencyCode);
  final rawChunk = baseline / 10;
  return pocketNiceNumber(rawChunk);
}

double calculatePocketBudgetSliderMax({
  required String currencyCode,
  required List<double> values,
}) {
  final normalizedCode = _normalizePocketCurrencyCode(currencyCode);
  final baseline = pocketCurrencyBaselineMax(normalizedCode);
  final roundingChunk = pocketCurrencyChunk(normalizedCode);

  final observedMax = values
      .where((value) => value.isFinite && value > 0)
      .fold<double>(0, math.max);
  final paddedObserved = observedMax > 0 ? observedMax * 1.25 : 0;
  final hardCap = baseline * 3;
  final candidate = math.max(baseline, paddedObserved);
  final capped = math.min(candidate, hardCap).toDouble();

  return roundPocketAmountUpToChunk(
    capped,
    roundingChunk,
  );
}

double calculatePocketBudgetSliderStep(double min, double max) {
  final span = max - min;
  if (span <= 0) return 1;

  final targetDivisions = span <= 50000
      ? 1000
      : span <= 500000
          ? 700
          : span <= 20000000
              ? 450
              : 300;
  final rawStep = span / targetDivisions;
  return pocketNiceNumber(rawStep);
}

int calculatePocketBudgetSliderDivisions(double min, double max, double step) {
  if (step <= 0) return 1;
  final divisions = ((max - min) / step).round();
  return math.max(1, math.min(divisions, 1200));
}

int pocketBudgetAdjustmentStepCents(String currencyCode) {
  final sliderMax = calculatePocketBudgetSliderMax(
    currencyCode: currencyCode,
    values: const [],
  );
  final majorUnitStep = calculatePocketBudgetSliderStep(0, sliderMax);
  return math.max(100, (majorUnitStep * 100).round());
}

int quantizePocketBudgetAmountCents(
  int amountCents, {
  required int stepCents,
}) {
  final safeStep = math.max(1, stepCents);
  if (amountCents <= 0) return 0;
  return (amountCents ~/ safeStep) * safeStep;
}

int normalizePocketBudgetAmountCentsForCurrency(
  int amountCents,
  String currencyCode,
) {
  return quantizePocketBudgetAmountCents(
    amountCents,
    stepCents: pocketBudgetAdjustmentStepCents(currencyCode),
  );
}

double roundPocketAmountUpToChunk(double value, double chunk) {
  final safeChunk = chunk.isFinite && chunk > 0 ? chunk : 10000.0;
  if (!value.isFinite || value <= 0) return safeChunk;
  final quotient = value / safeChunk;
  final rounded = quotient.isFinite ? quotient.ceilToDouble() : 1.0;
  return rounded * safeChunk;
}

double pocketNiceNumber(double rawStep) {
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
