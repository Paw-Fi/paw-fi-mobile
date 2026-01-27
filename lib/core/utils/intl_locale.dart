import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

/// Returns an intl-safe locale name.
///
/// The app supports some non-standard language codes (e.g. `kr` for Korean),
/// but the intl package expects canonical locale identifiers (e.g. `ko_KR`).
String intlSafeLocaleName(Locale locale) {
  final language = locale.languageCode.toLowerCase();

  final normalizedLanguage = switch (language) {
    // App uses `kr` as Korean, but intl expects `ko`.
    'kr' => 'ko',
    // Legacy/alias codes used on some platforms.
    'iw' => 'he',
    'in' => 'id',
    'ji' => 'yi',
    _ => language,
  };

  String? country = locale.countryCode;

  // If the app locale is `kr` without a region, default to Korea.
  if (language == 'kr' && (country == null || country.isEmpty)) {
    country = 'KR';
  }

  final raw = (country == null || country.isEmpty)
      ? normalizedLanguage
      : '${normalizedLanguage}_${country.toUpperCase()}';

  return intl.Intl.canonicalizedLocale(raw);
}
