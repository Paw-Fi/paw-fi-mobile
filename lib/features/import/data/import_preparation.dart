import 'package:intl/intl.dart';
import 'package:moneko/core/recurring/recurring_transaction_inference.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import '../domain/import_models.dart';
import 'import_dedupe.dart';
import 'import_parser.dart';

String? resolveImportAccountIdForCurrency({
  required String? accountId,
  required String? accountCurrency,
  required String transactionCurrency,
}) {
  final normalizedAccountId = accountId?.trim();
  final normalizedAccountCurrency = accountCurrency?.trim().toUpperCase();
  final normalizedTransactionCurrency =
      transactionCurrency.trim().toUpperCase();
  if (normalizedAccountId == null ||
      normalizedAccountId.isEmpty ||
      normalizedAccountCurrency == null ||
      normalizedAccountCurrency.isEmpty ||
      normalizedTransactionCurrency.isEmpty ||
      normalizedAccountCurrency != normalizedTransactionCurrency) {
    return null;
  }
  return normalizedAccountId;
}

({List<Map<String, dynamic>> transactions, int invalid})
    prepareImportTransactions(List<ImportParsedRow> rows,
        {required bool skipDuplicates,
        required String defaultCurrency,
        String? selectedAccountId,
        String? selectedAccountCurrency,
        DateTime Function(DateTime)? timestampForDate}) {
  // 1. Filter importable rows, counting invalid ones upfront.
  final importableRows = <ImportParsedRow>[];
  int preFilterFailed = 0;

  for (final row in rows) {
    if (!row.isValid) {
      preFilterFailed += 1;
      continue;
    }
    if (skipDuplicates && row.isDuplicate) {
      continue;
    }
    if (row.isRecurring &&
        row.recurringSeriesKey != null &&
        !row.isRecurringSeriesAnchor) {
      continue;
    }
    importableRows.add(row);
  }

  // 2. Convert rows to transaction maps for the batch endpoint.
  final transactions = importableRows.map((row) {
    final currency = row.currency ?? defaultCurrency;
    final accountId = resolveImportAccountIdForCurrency(
      accountId: selectedAccountId,
      accountCurrency: selectedAccountCurrency,
      transactionCurrency: currency,
    );
    final amount = (row.amountCents ?? 0) / 100.0;
    final dateOnly = DateFormat('yyyy-MM-dd').format(row.date!);
    final safeTimestamp =
        DateTime(row.date!.year, row.date!.month, row.date!.day, 12);
    final description =
        row.description == null ? null : sanitizeUtf16(row.description!).trim();
    final merchant =
        row.merchant == null ? null : sanitizeUtf16(row.merchant!).trim();
    final merchantLabel = (merchant ?? description)?.trim();
    final hasValidMerchantLabel = merchantLabel != null &&
        merchantLabel.isNotEmpty &&
        merchantLabel.length <= 255;

    return <String, dynamic>{
      'type': row.type ?? 'expense',
      'amount': amount,
      'category': row.category ?? 'uncategorized',
      'currency': currency,
      'date': dateOnly,
      'accountId': accountId,
      'clientCreatedAt':
          (timestampForDate?.call(row.date!) ?? safeTimestamp.toUtc())
              .toIso8601String(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (hasValidMerchantLabel) 'merchant': merchantLabel,
      if (row.merchantAutoResolutionBlocked)
        'merchantAutoResolutionBlocked': true,
      'isRecurring': row.isRecurring,
      if (row.recurrenceRule != null) 'recurrence_rule': row.recurrenceRule,
    };
  }).toList(growable: false);

  return (transactions: transactions, invalid: preFilterFailed);
}

ImportTable analyzedItemsToImportTable(List<dynamic> items) {
  final filtered = _filterAnalyzedItems(items);
  final blockedRowIndices = <int>{};
  final normalized = filtered.asMap().entries.map((entry) {
    final rawItem = entry.value;
    final item = rawItem is Map
        ? Map<String, dynamic>.from(rawItem)
        : <String, dynamic>{};
    if (item['merchant_auto_resolution_blocked'] == true) {
      blockedRowIndices.add(entry.key);
    }
    final rawAmount = item['amount'];
    final amountText = rawAmount == null ? '' : rawAmount.toString();
    final dateText = item['date']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final merchant = item['merchant']?.toString() ?? '';
    final currency = item['currency']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';

    return <String>[
      dateText,
      amountText,
      category,
      description,
      merchant,
      currency,
      type,
    ];
  }).toList(growable: false);

  return ImportTable(
    headers: const [
      'date',
      'amount',
      'category',
      'description',
      'merchant',
      'currency',
      'type',
    ],
    rows: normalized,
    merchantAutoResolutionBlockedRowIndices:
        Set<int>.unmodifiable(blockedRowIndices),
  );
}

List<dynamic> _filterAnalyzedItems(List<dynamic> items) {
  if (items.length <= 1) return items;

  bool isTotalLike(dynamic it) {
    final desc = (it is Map && it['description'] is String)
        ? (it['description'] as String)
        : '';
    return RegExp(
      r'(sub\s*total|subtotal|grand\s*total|total)',
      caseSensitive: false,
    ).hasMatch(desc);
  }

  final withoutTotals = items.where((it) => !isTotalLike(it)).toList();
  final base = withoutTotals.isNotEmpty ? withoutTotals : items;

  double amt(dynamic it) {
    if (it is Map && it['amount'] != null) {
      final a = it['amount'];
      if (a is num) return a.toDouble();
      return double.tryParse(a.toString()) ?? 0.0;
    }
    return 0.0;
  }

  final filtered = base.where((it) {
    // Only apply sum-of-others removal to total-like rows.
    if (!isTotalLike(it)) return true;
    final others = base.where((x) => !identical(x, it)).toList();
    final sumOthers = others.fold<double>(0.0, (s, x) => s + amt(x));
    return (amt(it) - sumOthers).abs() > 1e-6;
  }).toList(growable: false);

  return filtered.isNotEmpty ? filtered : base;
}

List<ImportParsedRow> parseImportRows(ImportTable table, ImportMapping mapping,
    {required String defaultCurrency,
    required List<ExpenseEntry> existing,
    String? targetAccountId,
    Set<int> deletedRowIndices = const {},
    Set<int> nonRecurringRowIndices = const {}}) {
  final rows = <ImportParsedRow>[];
  final dateOrderHint = inferDateOrderHint(
    table.rows,
    mapping.fieldToColumnIndex[ImportField.date],
  );
  for (var i = 0; i < table.rows.length; i++) {
    final parsed = applyImportDefaults(
      parseRow(
        table.rows[i],
        mapping,
        index: i,
        dateOrderHint: dateOrderHint,
      ).copyWith(
        merchantAutoResolutionBlocked:
            table.merchantAutoResolutionBlockedRowIndices.contains(i),
      ),
      defaultCurrency,
    );
    if (_isSummaryFooterRow(parsed)) {
      continue;
    }
    rows.add(parsed);
  }

  final effectiveDeletedRowIndices = deletedRowIndices;

  final filteredRows = effectiveDeletedRowIndices.isEmpty
      ? rows
      : rows
          .where((row) => !effectiveDeletedRowIndices.contains(row.index))
          .toList(growable: false);

  return inferAndDedupeImportRows(
    filteredRows,
    existing,
    targetAccountId: targetAccountId,
    nonRecurringRowIndices: nonRecurringRowIndices,
  );
}

List<ImportParsedRow> inferAndDedupeImportRows(
  List<ImportParsedRow> rows,
  List<ExpenseEntry> existingExpenses, {
  String? targetAccountId,
  Set<int> nonRecurringRowIndices = const {},
}) {
  final effectiveNonRecurringRowIndices = nonRecurringRowIndices;
  final inferred = inferRecurringTransactions([
    ...existingExpenses
        .where((expense) => expense.isRecurring || expense.amountCents > 0)
        .map(
          (expense) => RecurringInferenceInput(
            id: 'existing:${expense.id}',
            date: expense.date,
            amountCents: expense.amountCents,
            currency: expense.currency,
            type: expense.type,
            accountId: targetAccountId ?? expense.walletId,
            merchant: expense.merchant,
            description: expense.rawText,
            isRecurring: expense.isRecurring,
          ),
        ),
    ...rows
        .where(
          (row) => !effectiveNonRecurringRowIndices.contains(row.index),
        )
        .map(
          (row) => RecurringInferenceInput(
            id: 'import:${row.index}',
            date: row.date,
            amountCents: row.amountCents,
            currency: row.currency,
            type: row.type,
            accountId: targetAccountId,
            merchant: row.merchant,
            description: row.description,
            isRecurring: row.isRecurring,
            recurrenceRule: row.recurrenceRule,
          ),
        ),
  ]);

  final seriesWithExistingRecurringTemplate = <String>{};
  for (final expense
      in existingExpenses.where((expense) => expense.isRecurring)) {
    final result = inferred['existing:${expense.id}'];
    final seriesKey = result?.seriesKey;
    if (seriesKey != null && seriesKey.isNotEmpty) {
      seriesWithExistingRecurringTemplate.add(seriesKey);
    }
  }

  final firstImportIdBySeries = <String, String>{};
  final recurringImportRows = rows.where((row) {
    final result = inferred['import:${row.index}'];
    final seriesKey = result?.seriesKey;
    return result?.isRecurring == true &&
        seriesKey != null &&
        seriesKey.isNotEmpty &&
        !seriesWithExistingRecurringTemplate.contains(seriesKey);
  }).toList(growable: false)
    ..sort((a, b) => a.date!.compareTo(b.date!));

  for (final row in recurringImportRows) {
    final seriesKey = inferred['import:${row.index}']!.seriesKey!;
    firstImportIdBySeries.putIfAbsent(seriesKey, () => 'import:${row.index}');
  }

  final recurrenceAwareRows = rows.map((row) {
    if (effectiveNonRecurringRowIndices.contains(row.index)) {
      return row.copyWith(
        isRecurring: false,
        recurrenceRule: null,
        recurringSeriesKey: null,
        isRecurringSeriesAnchor: false,
      );
    }
    final importId = 'import:${row.index}';
    final result = inferred['import:${row.index}'];
    if (result == null || !result.isRecurring) {
      return row.copyWith(
        isRecurring: false,
        recurrenceRule: null,
        recurringSeriesKey: null,
        isRecurringSeriesAnchor: false,
      );
    }
    final seriesKey = result.seriesKey;
    final isImportAnchor =
        seriesKey == null || firstImportIdBySeries[seriesKey] == importId;
    return row.copyWith(
      isRecurring: true,
      recurrenceRule: result.recurrenceRule,
      recurringSeriesKey: seriesKey,
      isRecurringSeriesAnchor: isImportAnchor,
    );
  }).toList(growable: false);

  return markDuplicates(
    recurrenceAwareRows,
    existingExpenses,
    targetAccountId: targetAccountId,
  );
}

ImportParsedRow validateImportRow(ImportParsedRow row) {
  final errors = <String>[];
  final issues = <RowIssue>[];
  if (row.date == null) {
    errors.add('invalid_date');
    issues.add(RowIssue.invalidDate);
  }
  final amountCents = row.amountCents;
  if (amountCents == null || amountCents <= 0) {
    errors.add('invalid_amount');
    issues.add(RowIssue.invalidAmount);
  }
  if (!isBatchSaveCategorySafe(row.category ?? 'uncategorized')) {
    errors.add('invalid_category');
    issues.add(RowIssue.invalidCategory);
  }
  if (row.currency == null || row.currency!.trim().isEmpty) {
    issues.add(RowIssue.missingCurrency);
  }
  final normalizedType = row.type?.trim().toLowerCase();
  if (normalizedType != 'expense' && normalizedType != 'income') {
    errors.add('unknown_type');
    issues.add(RowIssue.unknownType);
  }
  return row.copyWith(errors: errors, issues: issues);
}

ImportParsedRow applyImportDefaults(
    ImportParsedRow row, String fallbackCurrency) {
  final normalizedCurrency = row.currency?.trim().toUpperCase();
  final effectiveCurrency =
      normalizedCurrency != null && normalizedCurrency.isNotEmpty
          ? normalizedCurrency
          : fallbackCurrency;
  return validateImportRow(row.copyWith(currency: effectiveCurrency));
}

bool _isSummaryFooterRow(ImportParsedRow row) {
  if (row.date != null) return false;

  final totalLikePattern = RegExp(
    r'^(?:sub\s*total|subtotal|grand\s*total|total)\b',
    caseSensitive: false,
  );

  for (final rawValue in row.rawValues ?? const <String>[]) {
    final normalized = rawValue.trim().replaceAll(':', '');
    if (normalized.isEmpty) continue;
    if (totalLikePattern.hasMatch(normalized)) {
      return true;
    }
  }

  return false;
}
