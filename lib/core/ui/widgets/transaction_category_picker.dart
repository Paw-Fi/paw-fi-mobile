import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';

String _normalizePickerCategoryKey(String rawCategory) {
  return rawCategory.trim().toLowerCase();
}

String _resolvePickerCurrentCategory({
  required String currentCategory,
  required List<String> baseCategories,
}) {
  final strict = _normalizePickerCategoryKey(currentCategory);
  if (strict.isEmpty) return strict;
  if (baseCategories.contains(strict)) return strict;

  final legacyNormalized = normalizeCategory(currentCategory);
  if (baseCategories.contains(legacyNormalized)) {
    return legacyNormalized;
  }
  return strict;
}

/// Shows a category picker for expense or income transactions
///
/// This is a low-level widget that only handles showing the category
/// selection UI and returning the selected category. It has no knowledge
/// of what will be done with the selected category.
///
/// [context] - BuildContext for showing the modal
/// [currentCategory] - Currently selected category
/// [isIncome] - Whether to show income categories or expense categories
///
/// Returns the selected category code or null if cancelled
Future<String?> showCategoryPicker({
  required BuildContext context,
  required String currentCategory,
  required bool isIncome,
  List<String>? allCategories,
  Future<String?> Function(String name)? onCreateCategory,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final baseCategoriesRaw = allCategories ??
      (isIncome ? getIncomeCategories() : getExpenseCategories());
  final baseCategories = <String>[];
  final seen = <String>{};
  for (final category in baseCategoriesRaw) {
    final normalized = _normalizePickerCategoryKey(category);
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    baseCategories.add(normalized);
  }
  final normalizedCurrent = _resolvePickerCurrentCategory(
    currentCategory: currentCategory,
    baseCategories: baseCategories,
  );
  final builtinCategories =
      isIncome ? getIncomeCategories().toSet() : getExpenseCategories().toSet();

  // If there is no current category, don't preselect anything.
  final categories = normalizedCurrent.isEmpty
      ? baseCategories
      : (baseCategories.contains(normalizedCurrent)
          ? baseCategories
          : [...baseCategories, normalizedCurrent]);
  final customCategories = categories
      .where(
        (category) =>
            !builtinCategories.contains(category) &&
            category != 'other' &&
            category != 'uncategorized',
      )
      .toList();

  final initialSelected =
      normalizedCurrent.isEmpty ? <String>[] : <String>[normalizedCurrent];

  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
    builder: (sheetContext) {
      return CategoryPickerBottomSheet(
        title: context.l10n.selectCategory,
        allCategories: categories,
        customCategories: customCategories,
        onCreateCategory: onCreateCategory,
        selectedCategories: initialSelected,
        isSingleSelect: true,
        onChanged: (value) {
          final next = value.isNotEmpty ? value.first : null;
          Navigator.of(sheetContext).pop(next);
        },
      );
    },
  );
}
