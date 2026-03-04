import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/l10n/l10n.dart';

import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_icon_options.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_style_overrides.dart';
import 'package:moneko/core/theme/app_theme.dart';

class CategoryPickerBottomSheet extends StatelessWidget {
  const CategoryPickerBottomSheet({
    super.key,
    required this.allCategories,
    this.customCategories = const <String>[],
    required this.selectedCategories,
    required this.onChanged,
    this.isSingleSelect = false,
    this.title = "",
    this.onCreateCategory,
  });

  final List<String> allCategories;
  final List<String> customCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onChanged;
  final bool isSingleSelect;
  final String title;
  final Future<String?> Function(String name)? onCreateCategory;

  @override
  Widget build(BuildContext context) {
    return CategoryPicker(
      allCategories: allCategories,
      customCategories: customCategories,
      selectedCategories: selectedCategories,
      onChanged: onChanged,
      title: title,
      isSingleSelect: isSingleSelect,
      onCreateCategory: onCreateCategory,
      // Let CategoryPicker handle closing behavior. For single-select flows,
      // it will call onChanged and then onClose to pop the sheet exactly once
      // with the selected value. For multi-select, the header close button
      // will use the default Navigator.pop(context).
    );
  }
}

/// Low-level picker content that can be embedded in any surface or sheet.
class CategoryPicker extends HookWidget {
  const CategoryPicker({
    super.key,
    required this.allCategories,
    this.customCategories = const <String>[],
    required this.selectedCategories,
    required this.onChanged,
    required this.title,
    this.isSingleSelect = false,
    this.onClose,
    this.onCreateCategory,
  });

  final List<String> allCategories;
  final List<String> customCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onChanged;
  final String title;
  final bool isSingleSelect;
  final VoidCallback? onClose;
  final Future<String?> Function(String name)? onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchBackground = colorScheme.homeSearchFieldBackground;
    final searchController = useTextEditingController();
    final searchQuery = useState<String>('');
    final canonicalCategories = _canonicalizePickerCategories(allCategories);
    final canonicalCategorySet = canonicalCategories.toSet();
    final initialSelected = isSingleSelect && selectedCategories.isNotEmpty
        ? <String>{
            _resolveInitialSelectedKey(
              selectedCategories.first,
              canonicalCategorySet,
            )
          }
        : selectedCategories
            .map((category) =>
                _resolveInitialSelectedKey(category, canonicalCategorySet))
            .where((category) => category.isNotEmpty)
            .toSet();
    final selected = useState<Set<String>>(initialSelected);

    useEffect(() {
      void listener() {
        searchQuery.value = searchController.text.trim().toLowerCase();
      }

      searchController.addListener(listener);
      return () {
        searchController.removeListener(listener);
      };
    }, [searchController]);

    final canonicalCustomCategories =
        _canonicalizePickerCategories(customCategories).toSet();
    final grouped = _buildGroups(
      context,
      canonicalCategories,
      customCategories: canonicalCustomCategories,
    );
    final filtered = _filterGroups(context, grouped, searchQuery.value);

    final normalizedQuery = searchQuery.value.trim().toLowerCase();
    final normalizedCreateKey = normalizedQuery.isEmpty
        ? ''
        : _normalizePickerCategoryKey(normalizedQuery);

    bool hasExactOrLocalizedMatch(String key) {
      if (key.isEmpty) return false;
      return canonicalCategories.contains(key);
    }

    final canCreateFromQuery = normalizedQuery.isNotEmpty &&
        normalizedCreateKey.isNotEmpty &&
        normalizedCreateKey.length <= 48 &&
        !hasExactOrLocalizedMatch(normalizedCreateKey);

    void handleToggle(String key) {
      final current = <String>{...selected.value};

      if (isSingleSelect) {
        current
          ..clear()
          ..add(key);
        selected.value = current;
        onChanged(current.toList());
        onClose?.call();
        return;
      }

      if (current.contains(key)) {
        current.remove(key);
      } else {
        current.add(key);
      }
      selected.value = current;
      onChanged(current.toList());
    }

    return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.appBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryPickerHeader(
                        title: title,
                        onClose: onClose ?? () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            if (canCreateFromQuery)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.categoryOther,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    Semantics(
                                      button: true,
                                      label: normalizedCreateKey,
                                      child: Material(
                                        color: colorScheme.surface
                                            .withValues(alpha: 0.0),
                                        borderRadius: BorderRadius.circular(14),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          onTap: () async {
                                            if (onCreateCategory != null) {
                                              final created =
                                                  await onCreateCategory!(
                                                normalizedCreateKey,
                                              );
                                              if (created != null &&
                                                  created.trim().isNotEmpty) {
                                                handleToggle(created.trim());
                                                return;
                                              }
                                            }
                                            handleToggle(normalizedCreateKey);
                                          },
                                          child: Ink(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surface
                                                  .withValues(alpha: 0.0),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: colorScheme.border,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.add,
                                                  size: 18,
                                                  color: colorScheme.primary,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    normalizedCreateKey,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: colorScheme
                                                          .foreground,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    context.l10n.missingCategoryHint,
                                    style: TextStyle(
                                      color: colorScheme.mutedForeground,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Icon(
                                    Icons.settings,
                                    size: 14,
                                    color: colorScheme.mutedForeground,
                                  ),
                                  Text(
                                    ' Settings',
                                    style: TextStyle(
                                      color: colorScheme.mutedForeground,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final entry in filtered.entries)
                              _CategoryGroupSection(
                                groupTitle: (entry.key == 'custom'
                                        ? context.l10n.custom
                                        : getCategoryGroupTranslation(
                                            context,
                                            entry.key,
                                          ))
                                    .toUpperCase(),
                                categories: entry.value,
                                selected: selected.value,
                                onToggle: handleToggle,
                                isCustomGroup: entry.key == 'custom',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: searchBackground,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colorScheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PlatformInfo.isIOS
                              ? CupertinoIcons.search
                              : Icons.search,
                          color: colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: context.l10n.search,
                              hintStyle: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 14,
                              ),
                            ),
                            style: TextStyle(
                              color: colorScheme.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (searchQuery.value.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => searchController.clear(),
                            child: Icon(
                              PlatformInfo.isIOS
                                  ? CupertinoIcons.xmark_circle_fill
                                  : Icons.clear,
                              color: colorScheme.mutedForeground,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

Map<String, List<String>> _buildGroups(
    BuildContext context, List<String> categories,
    {required Set<String> customCategories}) {
  final allowed = categories.toSet();
  final Map<String, List<String>> groups = {};

  final customItems = customCategories.where(allowed.contains).toList()
    ..sort((a, b) => a.compareTo(b));
  if (customItems.isNotEmpty) {
    groups['custom'] = customItems;
  }

  categoryGroups.forEach((groupKey, groupCategories) {
    final items = groupCategories
        .where((category) =>
            allowed.contains(category) && !customCategories.contains(category))
        .toList();
    if (items.isEmpty) return;

    groups[groupKey] = items;
  });

  // Add any categories not covered by the known groups to Other
  final groupedItems = groups.values.expand((e) => e).toSet();
  final remaining = allowed.difference(groupedItems).toList()..sort();
  if (remaining.isNotEmpty) {
    groups['misc'] = [...?groups['misc'], ...remaining];
  }

  return groups;
}

String _normalizePickerCategoryKey(String category) {
  return category.trim().toLowerCase();
}

String _resolveInitialSelectedKey(String category, Set<String> allowed) {
  final strict = _normalizePickerCategoryKey(category);
  if (strict.isEmpty) return strict;
  if (allowed.contains(strict)) return strict;

  final legacyNormalized = normalizeCategory(category);
  if (allowed.contains(legacyNormalized)) return legacyNormalized;
  return strict;
}

List<String> _canonicalizePickerCategories(List<String> categories) {
  final seen = <String>{};
  final result = <String>[];
  for (final category in categories) {
    final normalized = _normalizePickerCategoryKey(category);
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    result.add(normalized);
  }
  return result;
}

Map<String, List<String>> _filterGroups(
  BuildContext context,
  Map<String, List<String>> groups,
  String query,
) {
  if (query.isEmpty) {
    return groups;
  }
  final lower = query.toLowerCase();
  final Map<String, List<String>> result = {};
  for (final entry in groups.entries) {
    final filtered = entry.value.where((key) {
      final localized = getCategoryTranslation(context, key).toLowerCase();
      return key.toLowerCase().contains(lower) || localized.contains(lower);
    }).toList();
    if (filtered.isNotEmpty) {
      result[entry.key] = filtered;
    }
  }
  return result;
}

class _CategoryPickerHeader extends StatelessWidget {
  const _CategoryPickerHeader({
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle =
        title.trim().isEmpty ? context.l10n.selectCategory : title;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            resolvedTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroupSection extends StatelessWidget {
  const _CategoryGroupSection({
    required this.groupTitle,
    required this.categories,
    required this.selected,
    required this.onToggle,
    required this.isCustomGroup,
  });

  final String groupTitle;
  final List<String> categories;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool isCustomGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final key in categories)
                _CategoryTile(
                  categoryKey: key,
                  isSelected: selected.contains(key),
                  isCustomCategory: isCustomGroup,
                  onTap: () => onToggle(key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.categoryKey,
    required this.isSelected,
    required this.isCustomCategory,
    required this.onTap,
  });

  final String categoryKey;
  final bool isSelected;
  final bool isCustomCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color =
        _categoryColor(categoryKey, isCustomCategory: isCustomCategory);
    final icon = _categoryIcon(categoryKey, isCustomCategory: isCustomCategory);
    final label = _categoryLabel(
      context,
      categoryKey,
      isCustomCategory: isCustomCategory,
    );

    final circleColor =
        isSelected ? color : colorScheme.surface.withValues(alpha: 0.0);
    final iconColor = isSelected
        ? colorScheme.primaryForeground
        : color.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleColor,
                border: isSelected
                    ? null
                    : Border.all(
                        color: color.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(
  BuildContext context,
  String categoryKey, {
  required bool isCustomCategory,
}) {
  if (isCustomCategory) {
    return categoryKey;
  }
  return getCategoryTranslation(context, categoryKey);
}

Color _categoryColor(String categoryKey, {required bool isCustomCategory}) {
  if (!isCustomCategory) {
    return getCategoryColor(categoryKey);
  }

  final style = getCustomCategoryStyleOverrides()[categoryKey];
  if (style?.colorArgb case final int colorArgb) {
    return Color(colorArgb);
  }

  final palette = getCustomCategoryColorOptions();
  final index = categoryKey.hashCode.abs() % palette.length;
  return palette[index];
}

IconData _categoryIcon(String categoryKey, {required bool isCustomCategory}) {
  if (!isCustomCategory) {
    return getCategoryIcon(categoryKey);
  }

  final style = getCustomCategoryStyleOverrides()[categoryKey];
  final iconKey = style?.iconKey?.trim();
  if (iconKey != null && iconKey.isNotEmpty) {
    return customCategoryIconForKey(iconKey);
  }

  return customCategoryIconForKey('tag');
}
