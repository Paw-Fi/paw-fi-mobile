import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:moneko/features/home/presentation/constants/category_constants.dart';

class CategoryPickerBottomSheet extends HookWidget {
  const CategoryPickerBottomSheet({
    super.key,
    required this.allCategories,
    required this.selectedCategories,
    required this.onChanged,
    this.title = 'Categories',
  });

  final List<String> allCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();
    final searchQuery = useState<String>('');
    final selected = useState<Set<String>>(selectedCategories.toSet());

    useEffect(() {
      void listener() {
        searchQuery.value = searchController.text.trim().toLowerCase();
      }

      searchController.addListener(listener);
      return () {
        searchController.removeListener(listener);
      };
    }, [searchController]);

    final grouped = _buildGroups(allCategories);
    final filtered = _filterGroups(context, grouped, searchQuery.value);

    void handleToggle(String key) {
      final current = selected.value;
      final next = <String>{...current};
      if (next.contains(key)) {
        next.remove(key);
      } else {
        next.add(key);
      }
      selected.value = next;
      onChanged(next.toList());
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                    onClose: () => Navigator.of(context).pop(),
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
              child: AdaptiveCard(
                borderRadius: BorderRadius.circular(28),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AdaptiveTextField(
                  controller: searchController,
                  placeholder: 'Search',
                  prefixIcon: Icon(
                    PlatformInfo.isIOS
                        ? CupertinoIcons.search
                        : Icons.search,
                  ),
                  suffixIcon: searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            PlatformInfo.isIOS
                                ? CupertinoIcons.xmark_circle_fill
                                : Icons.clear,
                          ),
                          onPressed: () {
                            searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, List<String>> _buildGroups(List<String> categories) {
  const Map<String, String> groupLabels = {
    'entertainment': 'Entertainment',
    'entertainment_subscriptions': 'Entertainment',
    'shopping': 'Shopping',
    'restaurants': 'Food & drinks',
    'food': 'Food & drinks',
    'groceries': 'Food & drinks',
    'transport': 'Transport',
    'transportation': 'Transport',
    'travel': 'Travel',
    'flights': 'Travel',
    'vacation': 'Travel',
    'health': 'Health',
    'medical': 'Health',
    'healthcare': 'Health',
    'housing': 'Housing',
    'rent': 'Housing',
    'mortgage': 'Housing',
    'bills': 'Housing',
    'insurance': 'Housing',
    'savings': 'Savings',
    'investment': 'Savings',
    'investments': 'Savings',
    'income': 'Income',
    'salary': 'Income',
    'bonus': 'Income',
    'pets': 'Family & pets',
    'kids': 'Family & kids',
    'family': 'Family & kids',
    'gifts': 'Gifts & charity',
    'gift': 'Gifts & charity',
    'charity': 'Gifts & charity',
  };

  final Map<String, List<String>> groups = {};
  for (final raw in categories) {
    final key = raw.toLowerCase();
    final label = groupLabels[key] ?? 'Other';
    groups.putIfAbsent(label, () => <String>[]).add(raw);
  }

  final sorted = <String, List<String>>{};
  final titles = groups.keys.toList()..sort();
  for (final title in titles) {
    final items = groups[title]!..sort();
    sorted[title] = items;
  }
  return sorted;
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
    return Row(
      children: [
        AdaptiveButton.icon(
          onPressed: onClose,
          icon: PlatformInfo.isIOS ? CupertinoIcons.xmark : Icons.close,
        ),
        const Spacer(),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
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

    final circleColor = isSelected ? color : color.withOpacity(0.15);
    final iconColor = isSelected ? Colors.white : color;

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
