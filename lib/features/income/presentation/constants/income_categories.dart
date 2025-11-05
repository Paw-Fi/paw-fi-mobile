/// Income category constants
/// Predefined income categories with localization keys

const List<String> incomeCategories = [
  'income:salary',
  'income:freelance',
  'income:investment',
  'income:refund',
  'income:gift',
  'income:bonus',
  'income:rental',
  'income:other',
];

/// Get icon for income category
String getIncomeCategoryIcon(String category) {
  switch (category) {
    case 'income:salary':
      return '💼';
    case 'income:freelance':
      return '💻';
    case 'income:investment':
      return '📈';
    case 'income:refund':
      return '↩️';
    case 'income:gift':
      return '🎁';
    case 'income:bonus':
      return '🎉';
    case 'income:rental':
      return '🏠';
    case 'income:other':
      return '💰';
    default:
      return '💵';
  }
}

/// Get color for income category
String getIncomeCategoryColor(String category) {
  // All income categories use green shades (positive inflow)
  switch (category) {
    case 'income:salary':
      return '#10B981'; // Green-500
    case 'income:freelance':
      return '#059669'; // Green-600
    case 'income:investment':
      return '#047857'; // Green-700
    case 'income:refund':
      return '#6EE7B7'; // Green-300
    case 'income:gift':
      return '#34D399'; // Green-400
    case 'income:bonus':
      return '#10B981'; // Green-500
    case 'income:rental':
      return '#059669'; // Green-600
    case 'income:other':
      return '#6EE7B7'; // Green-300
    default:
      return '#10B981'; // Green-500
  }
}
