/// Bank provider routing logic for determining which bank sync provider
/// to use based on country code.
///
/// Plaid handles US banks only. Tink handles all other countries.

import 'dart:math';

/// Supported bank sync providers.
enum BankProvider {
  /// Plaid - US banks only
  plaid,

  /// Tink - All non-US countries
  tink,
}

/// Countries where Plaid is the primary provider.
/// Currently only the United States.
const Set<String> plaidSupportedCountries = {'US'};

/// Countries where Tink is the primary provider.
/// This includes all countries from plaidCountryOptions except US.
const Set<String> tinkSupportedCountries = {
  // Americas (non-US)
  'CA', 'MX', 'BR', 'CL', 'PY', 'GT', 'DO',

  // Africa & Middle East
  'NG', 'EG', 'GH', 'KE', 'ZA', 'AE', 'SA',

  // Asia-Pacific
  'CN', 'HK', 'JP', 'KR', 'VN', 'TH', 'ID', 'IN', 'MY', 'PH', 'SG', 'AU', 'NZ',
  'LK', 'PK',

  // Core Europe
  'DE', 'FR', 'GB', 'IT', 'ES', 'NL', 'BE', 'CH', 'AT', 'IE', 'LU',

  // Northern Europe
  'SE', 'NO', 'FI', 'DK', 'IS',

  // Southern Europe / Mediterranean
  'PT', 'GR', 'HR', 'RS', 'BG', 'SI', 'MK', 'AL', 'ME', 'BA', 'MT', 'CY',

  // Eastern Europe
  'PL', 'CZ', 'SK', 'HU', 'RO', 'MD', 'UA', 'BY',
};

/// Returns the appropriate bank provider for the given country code.
///
/// - Returns [BankProvider.plaid] for US
/// - Returns [BankProvider.tink] for all other countries
BankProvider getProviderForCountry(String countryCode) {
  final code = countryCode.toUpperCase();
  if (plaidSupportedCountries.contains(code)) {
    return BankProvider.plaid;
  }
  return BankProvider.tink;
}

/// Returns whether the given country is supported by any bank provider.
bool isCountrySupported(String countryCode) {
  final code = countryCode.toUpperCase();
  return plaidSupportedCountries.contains(code) ||
      tinkSupportedCountries.contains(code);
}

/// Returns the display name for the bank provider.
String getProviderDisplayName(BankProvider provider) {
  switch (provider) {
    case BankProvider.plaid:
      return 'Plaid';
    case BankProvider.tink:
      return 'Tink';
  }
}

/// Generates an idempotency key for bank connection requests.
/// This prevents duplicate connections if the user retries after a failure.
///
/// Format: `{userId}_{timestamp}_{random}` to ensure uniqueness.
String generateIdempotencyKey(String userId) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random().nextInt(99999).toString().padLeft(5, '0');
  return '${userId}_${timestamp}_$random';
}
