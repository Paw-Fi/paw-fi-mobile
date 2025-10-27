/// Currency flag utilities for mapping currency codes to flag image assets
library;

/// Maps currency codes to flag image paths
/// Returns the asset path for the flag image or null if not available
String? getCurrencyFlagPath(String currencyCode) {
  final code = currencyCode.toUpperCase();
  const flagMap = {
    'USD': 'us',
    'EUR': 'europe',
    'GBP': 'uk',
    'AUD': 'au',
    'CAD': 'ca',
    'CNY': 'cn',
    'JPY': 'jp',
    'HKD': 'hk',
    'SGD': 'sg',
    'NZD': 'nz',
    'CZK': 'cz',
    'CHF': 'switzerland',
    'KRW': 'kr',
    'INR': 'india',
    'RUB': 'russia',
    'BRL': 'brazil',
    'MXN': 'mexico',
    'ZAR': 'south_africa',
    'SEK': 'sweden',
    'NOK': 'norway',
    'DKK': 'denmark',
    'PLN': 'poland',
    'THB': 'thailand',
    'IDR': 'indonesia',
    'MYR': 'my',
    'PHP': 'philippines',
    'TRY': 'turkey',
    'AED': 'uae',
    'SAR': 'saudi_arabia',
    'EGP': 'egypt',
    'NGN': 'nigeria',
    'PKR': 'pakistan',
    'KES': 'kenya',
    'GHS': 'ghana',
    'VND': 'vietnam',
    'DOP': 'dominican',
    'PYG': 'paraguay',
    'UAH': 'ukraine',
    'LKR': 'sri_lanka',
    'GTQ': 'guatemala',
    'CLP': 'chile',
    'RSD': 'serbia',
  };
  
  final flagName = flagMap[code];
  return flagName != null ? 'lib/assets/images/flags/$flagName.png' : null;
}
