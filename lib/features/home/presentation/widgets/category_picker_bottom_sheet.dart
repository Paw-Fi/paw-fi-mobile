import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/l10n/l10n.dart';

import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/core/theme/app_theme.dart';

class CategoryPickerBottomSheet extends StatelessWidget {
  const CategoryPickerBottomSheet({
    super.key,
    required this.allCategories,
    required this.selectedCategories,
    required this.onChanged,
    this.isSingleSelect = false,
  });

  final List<String> allCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onChanged;
  final bool isSingleSelect;

  @override
  Widget build(BuildContext context) {
    return CategoryPicker(
      allCategories: allCategories,
      selectedCategories: selectedCategories,
      onChanged: onChanged,
      title: "",
      isSingleSelect: isSingleSelect,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}

/// Low-level picker content that can be embedded in any surface or sheet.
class CategoryPicker extends HookWidget {
  const CategoryPicker({
    super.key,
    required this.allCategories,
    required this.selectedCategories,
    required this.onChanged,
    required this.title,
    this.isSingleSelect = false,
    this.onClose,
  });

  final List<String> allCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onChanged;
  final String title;
  final bool isSingleSelect;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchBackground = colorScheme.brightness == Brightness.dark
        ? AppTheme.darkInputBg
        : AppTheme.lightInputBg;
    final searchController = useTextEditingController();
    final searchQuery = useState<String>('');
    final initialSelected = isSingleSelect && selectedCategories.isNotEmpty
        ? <String>{selectedCategories.first}
        : selectedCategories.toSet();
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

    final grouped = _buildGroups(context, allCategories);
    final filtered = _filterGroups(context, grouped, searchQuery.value);

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
                      children: [
                        for (final entry in filtered.entries)
                          _CategoryGroupSection(
                            groupTitle: entry.key,
                            categories: entry.value,
                            selected: selected.value,
                            onToggle: handleToggle,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
    );
  }
}

Map<String, List<String>> _buildGroups(
  BuildContext context,
  List<String> categories,
) {
  final allowed = categories.toSet();
  final Map<String, List<String>> groups = {};

  categoryGroups.forEach((groupKey, groupCategories) {
    final items = groupCategories.where(allowed.contains).toList();
    if (items.isEmpty) return;

    final title = getCategoryGroupTranslation(context, groupKey);
    groups[title] = items;
  });

  // Add any categories not covered by the known groups to Other
  final groupedItems = groups.values.expand((e) => e).toSet();
  final remaining = allowed.difference(groupedItems).toList()..sort();
  if (remaining.isNotEmpty) {
    final miscTitle = getCategoryGroupTranslation(context, 'misc');
    groups[miscTitle] = [...?groups[miscTitle], ...remaining];
  }

  return groups;
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
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
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
  });

  final String groupTitle;
  final List<String> categories;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

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
    required this.onTap,
  });

  final String categoryKey;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = getCategoryColor(categoryKey);
    final icon = getCategoryIcon(categoryKey);
    final label = getCategoryTranslation(context, categoryKey);

    final circleColor = isSelected ? color : Colors.transparent;
    final iconColor = isSelected ? Colors.white : color.withValues(alpha: 0.2);

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
                border: isSelected ? null : Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ] : null,
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
