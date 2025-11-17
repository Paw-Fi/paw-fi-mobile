import 'package:flutter/material.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

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
  final categories = isIncome ? getIncomeCategories() : getExpenseCategories();
  final initial = categories.contains(currentCategory) 
      ? currentCategory 
      : (isIncome ? 'salary' : categories.first);
  
  return await showTransactionSelectionSheet<String>(
    context: context,
    items: categories,
    getLabel: (category) => getCategoryTranslation(context, category),
    initial: initial,
  );
}
