library;

import 'package:moneko/features/utils/currency_flags.dart';

/// Returns an asset path for a Plaid country flag.
///
/// Reuses the existing currency flag map by mapping Plaid country codes
/// to a representative currency code, then delegating to [getCurrencyFlagPath].
///
/// For countries where we don't have a direct mapping, we fall back to EUR,
/// which uses the European flag in the shared currency flag utility.
String getPlaidCountryFlagPath(String countryCode) {
  final code = countryCode.toUpperCase();

  const countryToCurrency = {
    // Americas
    'US': 'USD',
    'CA': 'CAD',
    'MX': 'MXN',
    'BR': 'BRL',
    'CL': 'CLP',
    'PY': 'PYG',
    'GT': 'GTQ',
    'DO': 'DOP',
    'AR': 'ARS',
    'JM': 'JMD',
    'PE': 'PEN',

    // Core Europe / Eurozone → EUR (European flag)
    'DE': 'EUR',
    'FR': 'EUR',
    'ES': 'EUR',
    'IT': 'EUR',
    'NL': 'EUR',
    'BE': 'EUR',
    'AT': 'EUR',
    'IE': 'EUR',
    'LU': 'EUR',
    'PT': 'EUR',
    'GR': 'EUR',
    'FI': 'EUR',
    'SK': 'EUR',
    'SI': 'EUR',
    'MT': 'EUR',
    'CY': 'EUR',
    'MD': 'EUR',
    'BY': 'EUR',
    'RO': 'EUR',
    'AL': 'EUR',
    'ME': 'EUR',
    'BA': 'EUR',
    'MK': 'EUR',

    // Non‑euro Europe with dedicated flags
    'GB': 'GBP',
    'CH': 'CHF',
    'SE': 'SEK',
    'NO': 'NOK',
    'DK': 'DKK',
    'PL': 'PLN',
    'CZ': 'CZK',
    'HU': 'HUF',
    'RS': 'RSD',
    'UA': 'UAH',

    // Asia‑Pacific
    'CN': 'CNY',
    'HK': 'HKD',
    'JP': 'JPY',
    'KR': 'KRW',
    'VN': 'VND',
    'TH': 'THB',
    'ID': 'IDR',
    'IN': 'INR',
    'MY': 'MYR',
    'PH': 'PHP',
    'SG': 'SGD',
    'AU': 'AUD',
    'NZ': 'NZD',
    'LK': 'LKR',
    'PK': 'PKR',
    'TW': 'TWD',
    'MM': 'MMK',

    // Africa & Middle East
    'NG': 'NGN',
    'EG': 'EGP',
    'GH': 'GHS',
    'KE': 'KES',
    'ZA': 'ZAR',
    'AE': 'AED',
    'SA': 'SAR',
    'MW': 'MWK',
    'TR': 'TRY',
  };

  final currencyCode = countryToCurrency[code] ?? 'EUR';
  // Fallback to EUR flag if specific mapping or flag asset is missing.
  return getCurrencyFlagPath(currencyCode) ?? getCurrencyFlagPath('EUR')!;
}
