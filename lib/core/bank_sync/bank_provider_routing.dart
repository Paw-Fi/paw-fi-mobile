/// Bank provider routing logic for determining which bank sync provider
/// to use based on country code.
///
/// Plaid handles supported bank connections.

import 'dart:math';

/// Supported bank sync providers.
enum BankProvider {
  /// Plaid-supported banks.
  plaid,

  /// Coming soon - Countries not yet supported
  comingSoon,
}

/// Countries where Plaid is the primary provider.
/// Add countries here to enable Plaid for them.
const Set<String> plaidSupportedCountries = {
  'US', // United States
  'CA', // Canada
};

/// Returns the appropriate bank provider for the given country code.
///
/// - Returns [BankProvider.plaid] for US/Canada
/// - Returns [BankProvider.comingSoon] for all other countries
BankProvider getProviderForCountry(String countryCode) {
  final code = countryCode.toUpperCase();
  if (plaidSupportedCountries.contains(code)) {
    return BankProvider.plaid;
  }
  return BankProvider.comingSoon;
}

BankProvider resolveBankProviderForConnection({
  required String? connectionId,
  required String countryCode,
}) =>
    connectionId?.trim().isNotEmpty == true
        ? BankProvider.plaid
        : getProviderForCountry(countryCode);

String? resolveBankConnectionId({
  required String? requestedConnectionId,
  required String? responseConnectionId,
}) {
  final responseId = responseConnectionId?.trim();
  if (responseId != null && responseId.isNotEmpty) return responseId;
  final requestedId = requestedConnectionId?.trim();
  return requestedId == null || requestedId.isEmpty ? null : requestedId;
}

/// Returns whether the given country is supported by any bank provider.
bool isCountrySupported(String countryCode) {
  final code = countryCode.toUpperCase();
  return plaidSupportedCountries.contains(code);
}

/// Returns the display name for the bank provider.
String getProviderDisplayName(BankProvider provider) {
  switch (provider) {
    case BankProvider.plaid:
      return 'Plaid';
    case BankProvider.comingSoon:
      return 'Coming Soon';
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
