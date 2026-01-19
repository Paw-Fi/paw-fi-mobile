import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';

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
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final normalizedCurrent = currentCategory.trim().toLowerCase();
  final baseCategories =
      isIncome ? getIncomeCategories() : getExpenseCategories();

  // If there is no current category, don't preselect anything.
  final categories = normalizedCurrent.isEmpty
      ? baseCategories
      : (baseCategories.contains(normalizedCurrent)
          ? baseCategories
          : [...baseCategories, normalizedCurrent]);

  final initialSelected =
      normalizedCurrent.isEmpty ? <String>[] : <String>[normalizedCurrent];

  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
    builder: (sheetContext) {
      return CategoryPickerBottomSheet(
        allCategories: categories,
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
