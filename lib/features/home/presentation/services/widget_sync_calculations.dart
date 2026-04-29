import 'package:moneko/features/home/presentation/models/expense_entry.dart';

bool isWidgetSpendExpense(ExpenseEntry entry) {
  return (entry.type ?? 'expense').toLowerCase() != 'income';
}

int widgetSpentCents(ExpenseEntry entry) {
  if (!isWidgetSpendExpense(entry)) return 0;
  return entry.amountCents.abs();
}

int calculateWidgetSpentCents(Iterable<ExpenseEntry> entries) {
  return entries.fold<int>(
    0,
    (sum, entry) => sum + widgetSpentCents(entry),
  );
}

Map<String, int> calculateWidgetCategorySpentCents(
  Iterable<ExpenseEntry> entries,
) {
  final totals = <String, int>{};
  for (final entry in entries) {
    final spentCents = widgetSpentCents(entry);
    if (spentCents <= 0) continue;

    final category = entry.category ?? 'uncategorized';
    totals[category] = (totals[category] ?? 0) + spentCents;
  }
  return totals;
}

double widgetCentsToAmount(int cents) => cents / 100.0;
