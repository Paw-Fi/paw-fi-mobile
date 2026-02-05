import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/import/domain/import_models.dart';

List<ImportParsedRow> markDuplicates(
  List<ImportParsedRow> rows,
  List<ExpenseEntry> existing,
) {
  final existingKeys = existing.map(_keyForExpense).toSet();
  final seenKeys = <String>{};

  return rows.map((row) {
    final key = _keyForRow(row);
    final isDuplicate =
        key != null && (existingKeys.contains(key) || !seenKeys.add(key));
    return row.copyWith(isDuplicate: isDuplicate);
  }).toList();
}

String? _keyForRow(ImportParsedRow row) {
  if (!row.isValid) return null;
  final date = row.date!;
  final dateKey = '${date.year}-${date.month}-${date.day}';
  final category = (row.category ?? '').trim().toLowerCase();
  final currency = (row.currency ?? '').trim().toUpperCase();
  final type = (row.type ?? 'expense').trim().toLowerCase();
  return '$dateKey|${row.amountCents}|$currency|$category|$type';
}

String _keyForExpense(ExpenseEntry entry) {
  final date = entry.date.toLocal();
  final dateKey = '${date.year}-${date.month}-${date.day}';
  final category = (entry.category ?? '').trim().toLowerCase();
  final currency = (entry.currency ?? '').trim().toUpperCase();
  final type = (entry.type ?? 'expense').trim().toLowerCase();
  return '$dateKey|${entry.amountCents}|$currency|$category|$type';
}
