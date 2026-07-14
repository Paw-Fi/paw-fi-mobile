import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:moneko/features/subscription/data/regional_pricing.generated.dart';

export 'regional_pricing.generated.dart';

String? resolveDeviceRegionalPricingCountry() {
  try {
    final locales = <ui.Locale>[
      ui.PlatformDispatcher.instance.locale,
      ...ui.PlatformDispatcher.instance.locales,
    ];
    for (final locale in locales) {
      final countryCode = locale.countryCode?.trim().toUpperCase();
      if (countryCode != null &&
          regionalPricingCountryToMarket.containsKey(countryCode)) {
        return countryCode;
      }
    }
  } catch (_) {
    // The generated catalog has a deterministic USD fallback.
  }
  return null;
}

RegionalPricingMarket deviceRegionalPricingMarket() {
  return regionalPricingForCountry(resolveDeviceRegionalPricingCountry());
}

int regionalPriceForPlan(
  RegionalPricingMarket market, {
  required String plan,
  String? billingInterval,
}) {
  if (plan == 'lifetime') return market.lifetime;
  return billingInterval == 'yearly' ? market.yearly : market.monthly;
}

String formatRegionalPrice(
  RegionalPricingMarket market,
  int amountInMinorUnits,
) {
  final divisor = switch (market.minorUnits) {
    0 => 1,
    1 => 10,
    2 => 100,
    3 => 1000,
    _ => 100,
  };
  final locale = Intl.canonicalizedLocale(market.locale.replaceAll('-', '_'));
  try {
    return NumberFormat.currency(
      locale: locale,
      name: market.currencyCode,
      decimalDigits: market.minorUnits,
    ).format(amountInMinorUnits / divisor);
  } catch (_) {
    return NumberFormat.currency(
      locale: 'en_US',
      name: market.currencyCode,
      decimalDigits: market.minorUnits,
    ).format(amountInMinorUnits / divisor);
  }
}
