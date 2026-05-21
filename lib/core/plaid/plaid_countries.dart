class PlaidCountryOption {
  const PlaidCountryOption({
    required this.code,
    required this.label,
  });

  /// ISO 3166-1 alpha-2 country code used by Plaid `country_codes`.
  final String code;

  /// Human-readable country name for display in the UI.
  final String label;
}

/// Countries we want to expose for Plaid Link country selection.
///
/// This is intentionally broader than Plaid's current coverage; for some
/// countries Plaid may not yet have any institutions, but we prefer to
/// surface the full list of supported currencies/regions from the app.
const List<PlaidCountryOption> plaidCountryOptions = [
  // Americas / default
  PlaidCountryOption(code: 'US', label: 'United States'),
  PlaidCountryOption(code: 'CA', label: 'Canada'),
  //We only supports US and CA banks right now!
  // PlaidCountryOption(code: 'MX', label: 'Mexico'),
  // PlaidCountryOption(code: 'BR', label: 'Brazil'),
  // PlaidCountryOption(code: 'CL', label: 'Chile'),
  // PlaidCountryOption(code: 'PY', label: 'Paraguay'),
  // PlaidCountryOption(code: 'GT', label: 'Guatemala'),
  // PlaidCountryOption(code: 'DO', label: 'Dominican Republic'),
  // PlaidCountryOption(code: 'AR', label: 'Argentina'),
  // PlaidCountryOption(code: 'JM', label: 'Jamaica'),
  // PlaidCountryOption(code: 'PE', label: 'Peru'),

  // // Africa & Middle East
  // PlaidCountryOption(code: 'NG', label: 'Nigeria'),
  // PlaidCountryOption(code: 'EG', label: 'Egypt'),
  // PlaidCountryOption(code: 'GH', label: 'Ghana'),
  // PlaidCountryOption(code: 'KE', label: 'Kenya'),
  // PlaidCountryOption(code: 'ZA', label: 'South Africa'),
  // PlaidCountryOption(code: 'AE', label: 'United Arab Emirates'),
  // PlaidCountryOption(code: 'SA', label: 'Saudi Arabia'),
  // PlaidCountryOption(code: 'MW', label: 'Malawi'),
  // PlaidCountryOption(code: 'TR', label: 'Turkey'),

  // // Asia-Pacific
  // PlaidCountryOption(code: 'CN', label: 'China'),
  // PlaidCountryOption(code: 'HK', label: 'Hong Kong'),
  // PlaidCountryOption(code: 'JP', label: 'Japan'),
  // PlaidCountryOption(code: 'KR', label: 'South Korea'),
  // PlaidCountryOption(code: 'VN', label: 'Vietnam'),
  // PlaidCountryOption(code: 'TH', label: 'Thailand'),
  // PlaidCountryOption(code: 'ID', label: 'Indonesia'),
  // PlaidCountryOption(code: 'IN', label: 'India'),
  // PlaidCountryOption(code: 'MY', label: 'Malaysia'),
  // PlaidCountryOption(code: 'PH', label: 'Philippines'),
  // PlaidCountryOption(code: 'SG', label: 'Singapore'),
  // PlaidCountryOption(code: 'AU', label: 'Australia'),
  // PlaidCountryOption(code: 'NZ', label: 'New Zealand'),
  // PlaidCountryOption(code: 'LK', label: 'Sri Lanka'),
  // PlaidCountryOption(code: 'PK', label: 'Pakistan'),
  // PlaidCountryOption(code: 'TW', label: 'Taiwan'),
  // PlaidCountryOption(code: 'MM', label: 'Myanmar'),
  // PlaidCountryOption(code: 'JO', label: 'Jordan'),

  // // Core Europe (including all you listed explicitly)
  // PlaidCountryOption(code: 'DE', label: 'Germany'),
  // PlaidCountryOption(code: 'FR', label: 'France'),
  // PlaidCountryOption(code: 'GB', label: 'United Kingdom'),
  // PlaidCountryOption(code: 'IT', label: 'Italy'),
  // PlaidCountryOption(code: 'ES', label: 'Spain'),
  // PlaidCountryOption(code: 'NL', label: 'Netherlands'),
  // PlaidCountryOption(code: 'BE', label: 'Belgium'),
  // PlaidCountryOption(code: 'CH', label: 'Switzerland'),
  // PlaidCountryOption(code: 'AT', label: 'Austria'),
  // PlaidCountryOption(code: 'IE', label: 'Ireland'),
  // PlaidCountryOption(code: 'LU', label: 'Luxembourg'),

  // // Northern Europe
  // PlaidCountryOption(code: 'SE', label: 'Sweden'),
  // PlaidCountryOption(code: 'NO', label: 'Norway'),
  // PlaidCountryOption(code: 'FI', label: 'Finland'),
  // PlaidCountryOption(code: 'DK', label: 'Denmark'),
  // PlaidCountryOption(code: 'IS', label: 'Iceland'),

  // // Southern Europe / Mediterranean
  // PlaidCountryOption(code: 'PT', label: 'Portugal'),
  // PlaidCountryOption(code: 'GR', label: 'Greece'),
  // PlaidCountryOption(code: 'HR', label: 'Croatia'),
  // PlaidCountryOption(code: 'RS', label: 'Serbia'),
  // PlaidCountryOption(code: 'BG', label: 'Bulgaria'),
  // PlaidCountryOption(code: 'SI', label: 'Slovenia'),
  // PlaidCountryOption(code: 'MK', label: 'North Macedonia'),
  // PlaidCountryOption(code: 'AL', label: 'Albania'),
  // PlaidCountryOption(code: 'ME', label: 'Montenegro'),
  // PlaidCountryOption(code: 'BA', label: 'Bosnia and Herzegovina'),
  // PlaidCountryOption(code: 'MT', label: 'Malta'),
  // PlaidCountryOption(code: 'CY', label: 'Cyprus'),

  // // Eastern Europe
  // PlaidCountryOption(code: 'PL', label: 'Poland'),
  // PlaidCountryOption(code: 'CZ', label: 'Czech Republic'),
  // PlaidCountryOption(code: 'SK', label: 'Slovakia'),
  // PlaidCountryOption(code: 'HU', label: 'Hungary'),
  // PlaidCountryOption(code: 'RO', label: 'Romania'),
  // PlaidCountryOption(code: 'MD', label: 'Moldova'),
  // PlaidCountryOption(code: 'UA', label: 'Ukraine'),
  // PlaidCountryOption(code: 'BY', label: 'Belarus'),
];
