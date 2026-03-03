import 'package:flutter/foundation.dart';

class CustomCategoryStyle {
  const CustomCategoryStyle({
    required this.colorArgb,
    required this.iconKey,
  });

  final int? colorArgb;
  final String? iconKey;
}

final ValueNotifier<Map<String, CustomCategoryStyle>>
    customCategoryStyleOverridesNotifier =
    ValueNotifier<Map<String, CustomCategoryStyle>>(
        <String, CustomCategoryStyle>{});

Map<String, CustomCategoryStyle> getCustomCategoryStyleOverrides() {
  return customCategoryStyleOverridesNotifier.value;
}

void setCustomCategoryStyleOverrides(
    Map<String, CustomCategoryStyle> overrides) {
  customCategoryStyleOverridesNotifier.value = Map.unmodifiable(overrides);
}
