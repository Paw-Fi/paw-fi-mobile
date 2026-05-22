import 'package:moneko/features/home/presentation/models/expense_entry.dart';

ExpenseEntry resolveTransactionRowDisplayEntry(
  ExpenseEntry groupedEntry,
  Map<String, ExpenseEntry> originalEntriesById,
) {
  return originalEntriesById[groupedEntry.id] ?? groupedEntry;
}
