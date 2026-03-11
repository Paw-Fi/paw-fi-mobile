import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/import/domain/import_models.dart';

/// Marks duplicate rows in [rows] against both:
/// 1. [existing] database records (sets [DuplicateReason.inDb])
/// 2. Earlier rows within the same file (sets [DuplicateReason.inFile])
///
/// The dedupe key now includes a normalized description to prevent false
/// positives for same-day/same-amount transactions with different descriptions.
List<ImportParsedRow> markDuplicates(
  List<ImportParsedRow> rows,
  List<ExpenseEntry> existing,
) {
  final existingKeys = existing.map(_keyForExpense).toSet();
  final seenKeys = <String, int>{}; // key → first row index

  return rows.map((row) {
    final key = _keyForRow(row);
    if (key == null) {
      return row.copyWith(
        isDuplicate: false,
        duplicateReason: DuplicateReason.none,
      );
    }

    // Check against database records first.
    if (existingKeys.contains(key)) {
      return row.copyWith(
        isDuplicate: true,
        duplicateReason: DuplicateReason.inDb,
        issues: [
          ...row.issues.where((i) =>
              i != RowIssue.duplicateInFile && i != RowIssue.duplicateInDb),
          RowIssue.duplicateInDb,
        ],
      );
    }

    // Check against earlier rows in the same file.
    if (seenKeys.containsKey(key)) {
      return row.copyWith(
        isDuplicate: true,
        duplicateReason: DuplicateReason.inFile,
        issues: [
          ...row.issues.where((i) =>
              i != RowIssue.duplicateInFile && i != RowIssue.duplicateInDb),
          RowIssue.duplicateInFile,
        ],
      );
    }

    seenKeys[key] = row.index;
    return row.copyWith(
      isDuplicate: false,
      duplicateReason: DuplicateReason.none,
    );
  }).toList();
}

/// Builds a composite key from a parsed row. Includes description to prevent
/// false positives for same-day/same-amount transactions.
///
/// Key format: `date|amountCents|currency|category|type|descriptionPrefix`
///
/// The description is truncated to the first 40 chars (normalized) to avoid
/// minor whitespace or punctuation differences causing false negatives.
String? _keyForRow(ImportParsedRow row) {
  if (!row.isValid) return null;
  final date = row.date!;
  final dateKey = '${date.year}-${date.month}-${date.day}';
  final category = (row.category ?? '').trim().toLowerCase();
  final currency = (row.currency ?? '').trim().toUpperCase();
  final type = (row.type ?? 'expense').trim().toLowerCase();
  final desc = _normalizeDescription(row.description);
  return '$dateKey|${row.amountCents}|$currency|$category|$type|$desc';
}

/// Builds a composite key from an existing database entry.
String _keyForExpense(ExpenseEntry entry) {
  final date = entry.date.toLocal();
  final dateKey = '${date.year}-${date.month}-${date.day}';
  final category = (entry.category ?? '').trim().toLowerCase();
  final currency = (entry.currency ?? '').trim().toUpperCase();
  final type = (entry.type ?? 'expense').trim().toLowerCase();
  final desc = _normalizeDescription(entry.rawText);
  return '$dateKey|${entry.amountCents}|$currency|$category|$type|$desc';
}

/// Normalizes a description for dedupe comparison:
/// lowercase, strip non-alphanumeric, truncate to 40 chars.
String _normalizeDescription(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final cleaned =
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (cleaned.length <= 40) return cleaned;
  return cleaned.substring(0, 40);
}
