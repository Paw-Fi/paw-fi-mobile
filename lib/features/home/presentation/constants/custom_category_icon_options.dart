/// Stable string keys for custom category illustrations.
///
/// We store the key (not codepoint) in Supabase so we can evolve UI safely.
const Set<String> customCategoryIconKeys = {
  // General & Essential
  'tag',
  'star',
  'help',
  'bolt',
  'leaf',

  // Home & Living
  'home',
  'apartment',
  'tools',
  'cleaning',
  'chair',
  'kitchen',

  // Shopping & Food
  'shopping',
  'cart',
  'food',
  'coffee',
  'restaurant',
  'delivery',
  'grocery',

  // Transport & Travel
  'car',
  'bus',
  'train',
  'plane',
  'gas',
  'parking',

  // Health & Personal Care
  'health',
  'medical',
  'hospital',
  'fitness',
  'spa',

  // Family & Pets
  'people',
  'child',
  'baby',
  'pet',

  // Education & Work
  'book',
  'school',
  'work',
  'laptop',
  'business',

  // Finance & Bills
  'bill',
  'bank',
  'money',
  'card',
  'savings',
  'chart',
  'taxes',
  'shield',

  // Entertainment & Tech
  'music',
  'game',
  'movie',
  'party',
  'gift',
  'phone',
  'tv',
};
