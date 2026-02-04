import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

Future<void> exportTransactionsAsExcelSheet(
  BuildContext context,
  List<ExpenseEntry> expenses, {
  String fileNamePrefix = 'transactions',
}) async {
  if (expenses.isEmpty) {
    AppToast.info(context, context.l10n.noTransactionsFound);
    return;
  }

  // Pre-calculate share origin before async gap
  final shareOrigin = _resolveShareOrigin(context);

  debugPrint(
      '[exportTransactionsAsExcelSheet] count=${expenses.length} web=$kIsWeb');

  try {
    final excelBytes = await _buildExcel(expenses);

    if (!context.mounted) return;

    if (excelBytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    await _shareExcelBytes(
      context,
      excelBytes,
      shareOrigin: shareOrigin,
      fileNamePrefix: fileNamePrefix,
      logPrefix: '[exportTransactionsAsExcelSheet]',
    );
  } catch (e, stack) {
    debugPrint(
      '[exportTransactionsAsExcelSheet] failed: $e\n$stack',
    );
    if (context.mounted) {
      AppToast.error(
        context,
        '${context.l10n.anUnexpectedErrorOccurred} (${e.toString()})',
      );
    }
  }
}

Future<void> exportAllTransactionsAsExcelSheet(
  BuildContext context,
  List<ExpenseEntry> expenses, {
  required String personalLabel,
  Map<String, String> householdNames = const {},
  String fileNamePrefix = 'moneko_full_export',
  VoidCallback? onBeforeShare,
}) async {
  if (expenses.isEmpty) {
    AppToast.info(context, context.l10n.noTransactionsFound);
    return;
  }

  final shareOrigin = _resolveShareOrigin(context);

  debugPrint(
      '[exportAllTransactionsAsExcelSheet] count=${expenses.length} web=$kIsWeb');

  try {
    // NOTE: Receipt image downloads are temporarily disabled for export.
    // final receiptBundle = await _downloadReceiptImages(expenses);
    final excelBytes = await _buildFullExportExcel(
      expenses,
      personalLabel: personalLabel,
      householdNames: householdNames,
      receiptFileNamesById: const {},
    );

    if (!context.mounted) return;

    if (excelBytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    // NOTE: Receipt zipping is temporarily disabled for export.
    // if (receiptBundle.files.isNotEmpty) {
    //   final zipBytes = _buildReceiptsZip(
    //     excelBytes,
    //     receiptBundle.files,
    //     fileNamePrefix: fileNamePrefix,
    //   );
    //   await _shareZipBytes(
    //     context,
    //     zipBytes,
    //     shareOrigin: shareOrigin,
    //     fileNamePrefix: fileNamePrefix,
    //     logPrefix: '[exportAllTransactionsAsExcelSheet]',
    //   );
    // } else {
    onBeforeShare?.call();
    await _shareExcelBytes(
      context,
      excelBytes,
      shareOrigin: shareOrigin,
      fileNamePrefix: fileNamePrefix,
      logPrefix: '[exportAllTransactionsAsExcelSheet]',
    );
    // }
  } catch (e, stack) {
    debugPrint(
      '[exportAllTransactionsAsExcelSheet] failed: $e\n$stack',
    );
    if (context.mounted) {
      AppToast.error(
        context,
        '${context.l10n.anUnexpectedErrorOccurred} (${e.toString()})',
      );
    }
  }
}

Future<void> exportAllReceiptsAsZip(
  BuildContext context,
  List<ExpenseEntry> expenses, {
  String fileNamePrefix = 'moneko_receipts_export',
  VoidCallback? onBeforeShare,
}) async {
  if (expenses.isEmpty) {
    AppToast.info(context, context.l10n.noTransactionsFound);
    return;
  }

  final shareOrigin = _resolveShareOrigin(context);

  debugPrint('[exportAllReceiptsAsZip] count=${expenses.length} web=$kIsWeb');

  try {
    final receiptBundle = await _downloadReceiptImages(expenses);

    if (!context.mounted) return;

    if (receiptBundle.files.isEmpty) {
      AppToast.info(context, context.l10n.noReceiptsFound);
      return;
    }

    final zipBytes = _buildReceiptsOnlyZip(receiptBundle.files);
    if (zipBytes.isEmpty) {
      throw Exception('Failed to create receipts zip');
    }
    onBeforeShare?.call();
    await _shareZipBytes(
      context,
      zipBytes,
      shareOrigin: shareOrigin,
      fileNamePrefix: fileNamePrefix,
      logPrefix: '[exportAllReceiptsAsZip]',
    );
  } catch (e, stack) {
    debugPrint('[exportAllReceiptsAsZip] failed: $e\n$stack');
    if (context.mounted) {
      AppToast.error(
        context,
        '${context.l10n.anUnexpectedErrorOccurred} (${e.toString()})',
      );
    }
  }
}

Rect? _resolveShareOrigin(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final offset = renderObject.localToGlobal(Offset.zero);
    if (renderObject.size.width > 0 && renderObject.size.height > 0) {
      return offset & renderObject.size;
    }
  }
  return null;
}

Future<void> _shareExcelBytes(
  BuildContext context,
  List<int> excelBytes, {
  required Rect? shareOrigin,
  required String fileNamePrefix,
  required String logPrefix,
}) async {
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = '${fileNamePrefix}_$timestamp.xlsx';
  final bytes = Uint8List.fromList(excelBytes);

  if (kIsWeb) {
    debugPrint('$logPrefix sharing in web: $fileName');
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: fileName,
        ),
      ],
      subject: fileName,
      sharePositionOrigin: shareOrigin,
    );
    return;
  }

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  debugPrint('$logPrefix temp file: ${file.path}');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('$logPrefix share file');

  await Share.shareXFiles(
    [
      XFile(file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    ],
    subject: fileName,
    sharePositionOrigin: shareOrigin,
  );
}

Future<void> _shareZipBytes(
  BuildContext context,
  List<int> zipBytes, {
  required Rect? shareOrigin,
  required String fileNamePrefix,
  required String logPrefix,
}) async {
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = '${fileNamePrefix}_$timestamp.zip';
  final bytes = Uint8List.fromList(zipBytes);

  if (kIsWeb) {
    debugPrint('$logPrefix sharing in web: $fileName');
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/zip',
          name: fileName,
        ),
      ],
      subject: fileName,
      sharePositionOrigin: shareOrigin,
    );
    return;
  }

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  debugPrint('$logPrefix temp file: ${file.path}');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('$logPrefix share file');

  await Share.shareXFiles(
    [
      XFile(file.path, mimeType: 'application/zip'),
    ],
    subject: fileName,
    sharePositionOrigin: shareOrigin,
  );
}

Future<List<int>?> _buildExcel(List<ExpenseEntry> expenses) async {
  final excel = Excel.createExcel();

  // Rename default sheet to 'Transactions'
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null) {
    excel.rename(defaultSheet, 'Transactions');
  }

  final Sheet sheet = excel['Transactions'];

  // Add Headers (Removed ID and Currency)
  final headers = [
    'Date',
    'Account / User',
    'Description (Payee)',
    'Category',
    'Amount',
    'Type',
    'Notes',
    'Receipt Image',
  ];

  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  final dateFormat = DateFormat('yyyy-MM-dd');
  final categoryMap = <String, double>{};

  double totalIncome = 0.0;
  double totalExpense = 0.0;
  DateTime? minDate;
  DateTime? maxDate;

  for (final expense in expenses) {
    final date = dateFormat.format(expense.date);

    // Track date range
    if (minDate == null || expense.date.isBefore(minDate)) {
      minDate = expense.date;
    }
    if (maxDate == null || expense.date.isAfter(maxDate)) {
      maxDate = expense.date;
    }

    // Determine Account/User info
    String accountInfo = 'Personal';
    if (expense.householdId != null) {
      accountInfo = 'Household';
      if (expense.userName != null) {
        accountInfo += ' (${expense.userName})';
      }
    }

    final description = expense.rawText ?? '';
    final category = expense.category ?? 'Uncategorized';
    final amountVal =
        expense.amount; // Should we strictly use absolute for math?
    // Usually expense amount is positive in DB but typed as 'expense'.
    // We'll trust the Type field for classification.

    final type = expense.type ?? 'expense';

    // Calculation Logic
    final isIncome = type.toLowerCase() == 'income';
    final amountAbs = amountVal.abs();
    if (isIncome) {
      totalIncome += amountAbs;
    } else {
      totalExpense += amountAbs;
      // Track category for expenses only
      final currentCatTotal = categoryMap[category] ?? 0.0;
      categoryMap[category] = currentCatTotal + amountAbs;
    }

    const notes = '';

    final row = [
      TextCellValue(date),
      TextCellValue(accountInfo),
      TextCellValue(description),
      TextCellValue(category),
      DoubleCellValue(amountVal),
      TextCellValue(type),
      TextCellValue(notes),
      TextCellValue(''),
    ];

    sheet.appendRow(row);
  }

  // --- Summary Calculation ---

  // Top Category
  String topCategory = '-';
  double topCategoryAmount = 0.0;
  if (categoryMap.isNotEmpty) {
    final sortedEntries = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sortedEntries.isNotEmpty) {
      topCategory = sortedEntries.first.key;
      topCategoryAmount = sortedEntries.first.value;
    }
  }

  // Net Cash Flow
  final netCashFlow = totalIncome - totalExpense;

  // Savings Rate
  double savingsRate = 0.0;
  if (totalIncome > 0) {
    savingsRate = ((totalIncome - totalExpense) / totalIncome) * 100;
  }

  // Days and Daily Avg
  int daysCount = 0;
  double dailyAvgSpend = 0.0;
  if (minDate != null && maxDate != null) {
    daysCount = maxDate.difference(minDate).inDays + 1;
    if (daysCount > 0) {
      dailyAvgSpend = totalExpense / daysCount;
    }
  }

  // Date Range formatted
  String rangeStr = '-';
  if (minDate != null && maxDate != null) {
    rangeStr = '${dateFormat.format(minDate)} to ${dateFormat.format(maxDate)}';
  }

  // --- Append Summary Section ---

  // Add some spacing
  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([TextCellValue('')]);

  // Section Header
  sheet.appendRow([TextCellValue('Summary Report')]);
  sheet.appendRow([TextCellValue('')]);

  // Summary Rows
  void addSummaryRow(String label, dynamic value) {
    CellValue val;
    if (value is double) {
      val = DoubleCellValue(value);
    } else {
      val = TextCellValue(value.toString());
    }
    sheet.appendRow([TextCellValue(label), val]);
  }

  addSummaryRow('Period', rangeStr);
  addSummaryRow('Total Days', daysCount);
  addSummaryRow('Total Income', totalIncome);
  addSummaryRow('Total Expenses', totalExpense);
  addSummaryRow('Net Cash Flow', netCashFlow);
  addSummaryRow('Savings Rate (%)',
      double.parse(savingsRate.toStringAsFixed(2))); // formatted
  addSummaryRow('Daily Average Spend', dailyAvgSpend);
  addSummaryRow('Top Expense Category', topCategory);
  addSummaryRow('Top Category Amount', topCategoryAmount);

  return excel.encode();
}

Future<List<int>?> _buildFullExportExcel(
  List<ExpenseEntry> expenses, {
  required String personalLabel,
  required Map<String, String> householdNames,
  Map<String, String> receiptFileNamesById = const {},
}) async {
  final excel = Excel.createExcel();
  final existingNames = <String>{};

  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null) {
    excel.rename(defaultSheet, 'Overview');
    existingNames.add('Overview');
  }

  _buildOverviewSheet(
    excel['Overview'],
    expenses,
    personalLabel: personalLabel,
    householdNames: householdNames,
  );

  final allSheetName = _uniqueSheetName(existingNames, 'All Transactions');
  _appendTransactionsSheet(
    excel[allSheetName],
    expenses,
    personalLabel: personalLabel,
    householdNames: householdNames,
    receiptFileNamesById: receiptFileNamesById,
  );
  existingNames.add(allSheetName);

  final grouped = _groupExpensesByAccount(expenses);
  for (final entry in grouped.entries) {
    final sheetName = _uniqueSheetName(
      existingNames,
      _resolveAccountSheetName(
        entry.key,
        householdNames: householdNames,
      ),
    );
    _appendTransactionsSheet(
      excel[sheetName],
      entry.value,
      personalLabel: personalLabel,
      householdNames: householdNames,
      receiptFileNamesById: receiptFileNamesById,
    );
    existingNames.add(sheetName);
  }

  return excel.encode();
}

void _buildOverviewSheet(
  Sheet sheet,
  List<ExpenseEntry> expenses, {
  required String personalLabel,
  required Map<String, String> householdNames,
}) {
  final dateFormat = DateFormat('yyyy-MM-dd');
  DateTime? minDate;
  DateTime? maxDate;

  for (final expense in expenses) {
    if (minDate == null || expense.date.isBefore(minDate)) {
      minDate = expense.date;
    }
    if (maxDate == null || expense.date.isAfter(maxDate)) {
      maxDate = expense.date;
    }
  }

  final range = (minDate != null && maxDate != null)
      ? '${dateFormat.format(minDate)} to ${dateFormat.format(maxDate)}'
      : '-';

  sheet.appendRow([
    TextCellValue('Exported At'),
    TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
  ]);
  sheet.appendRow([TextCellValue('Date Range'), TextCellValue(range)]);
  sheet.appendRow([TextCellValue('')]);

  sheet.appendRow([
    TextCellValue('Account'),
    TextCellValue('Currency'),
    TextCellValue('Transactions'),
    TextCellValue('Total Income'),
    TextCellValue('Total Expenses'),
    TextCellValue('Net'),
  ]);

  final summaries = <String, _AccountSummary>{};
  for (final expense in expenses) {
    final accountLabel = _resolveAccountLabel(
      expense,
      personalLabel: personalLabel,
      householdNames: householdNames,
    );
    final currency = (expense.currency ?? 'UNKNOWN').toUpperCase();
    final key = '$accountLabel::$currency';
    final summary = summaries.putIfAbsent(
      key,
      () => _AccountSummary(accountLabel: accountLabel, currency: currency),
    );
    summary.count += 1;
    final amount = expense.amount.abs();
    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    if (isIncome) {
      summary.totalIncome += amount;
    } else {
      summary.totalExpense += amount;
    }
  }

  final sortedSummaries = summaries.values.toList()
    ..sort((a, b) {
      final account = a.accountLabel.compareTo(b.accountLabel);
      if (account != 0) return account;
      return a.currency.compareTo(b.currency);
    });

  for (final summary in sortedSummaries) {
    sheet.appendRow([
      TextCellValue(summary.accountLabel),
      TextCellValue(summary.currency),
      IntCellValue(summary.count),
      DoubleCellValue(summary.totalIncome),
      DoubleCellValue(summary.totalExpense),
      DoubleCellValue(summary.totalIncome - summary.totalExpense),
    ]);
  }
}

void _appendTransactionsSheet(
  Sheet sheet,
  List<ExpenseEntry> expenses, {
  required String personalLabel,
  required Map<String, String> householdNames,
  Map<String, String> receiptFileNamesById = const {},
}) {
  final headers = [
    'Date',
    'Account',
    'User',
    'Description',
    'Category',
    'Amount',
    'Currency',
    'Type',
    'Notes',
    'Receipt Image',
  ];

  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  final dateFormat = DateFormat('yyyy-MM-dd');
  final rows = expenses.toList()..sort((a, b) => b.date.compareTo(a.date));

  for (final expense in rows) {
    final date = dateFormat.format(expense.date);
    final accountLabel = _resolveAccountLabel(
      expense,
      personalLabel: personalLabel,
      householdNames: householdNames,
    );
    final userLabel = _resolveUserLabel(
      expense,
      personalLabel: personalLabel,
    );
    final description = expense.rawText ?? '';
    final category = expense.category ?? 'Uncategorized';
    final amountVal = expense.amount;
    final currency = (expense.currency ?? 'UNKNOWN').toUpperCase();
    final type = expense.type ?? 'expense';
    final receiptFileName = receiptFileNamesById[expense.id] ?? '';

    sheet.appendRow([
      TextCellValue(date),
      TextCellValue(accountLabel),
      TextCellValue(userLabel),
      TextCellValue(description),
      TextCellValue(category),
      DoubleCellValue(amountVal),
      TextCellValue(currency),
      TextCellValue(type),
      TextCellValue(''),
      TextCellValue(receiptFileName),
    ]);
  }
}

class _ReceiptBundle {
  const _ReceiptBundle({
    required this.fileNamesByExpenseId,
    required this.files,
  });

  final Map<String, String> fileNamesByExpenseId;
  final List<_ReceiptFile> files;
}

class _ReceiptFile {
  const _ReceiptFile({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

Future<_ReceiptBundle> _downloadReceiptImages(
  List<ExpenseEntry> expenses,
) async {
  final fileNamesByExpenseId = <String, String>{};
  final files = <_ReceiptFile>[];
  final usedNames = <String>{};

  for (final expense in expenses) {
    final url = expense.receiptImageUrl?.trim() ?? '';
    if (url.isEmpty) continue;

    final fileName = _uniqueReceiptFileName(
      expenseId: expense.id,
      url: url,
      usedNames: usedNames,
    );
    final bytes = await _downloadBytes(url);
    if (bytes == null || bytes.isEmpty) continue;

    fileNamesByExpenseId[expense.id] = 'receipts/$fileName';
    files.add(_ReceiptFile(fileName: fileName, bytes: bytes));
  }

  return _ReceiptBundle(
    fileNamesByExpenseId: fileNamesByExpenseId,
    files: files,
  );
}

String _uniqueReceiptFileName({
  required String expenseId,
  required String url,
  required Set<String> usedNames,
}) {
  final extension = _resolveImageExtension(url);
  final baseName = _sanitizeFileName('receipt_$expenseId');
  var candidate = '$baseName$extension';
  var index = 2;
  while (usedNames.contains(candidate)) {
    candidate = '${baseName}_$index$extension';
    index += 1;
  }
  usedNames.add(candidate);
  return candidate;
}

String _resolveImageExtension(String url) {
  try {
    final path = Uri.parse(url).path;
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < path.length - 1) {
      final ext = path.substring(dotIndex).toLowerCase();
      if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
        return ext;
      }
    }
  } catch (_) {}
  return '.jpg';
}

String _sanitizeFileName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  if (sanitized.isEmpty) return 'receipt';
  return sanitized.length > 80 ? sanitized.substring(0, 80) : sanitized;
}

Future<Uint8List?> _downloadBytes(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}

List<int> _buildReceiptsOnlyZip(
  List<_ReceiptFile> receipts,
) {
  final archive = Archive();

  for (final receipt in receipts) {
    archive.addFile(
      ArchiveFile(
        'receipts/${receipt.fileName}',
        receipt.bytes.length,
        receipt.bytes,
      ),
    );
  }

  if (archive.isEmpty) return <int>[];

  return ZipEncoder().encode(archive) ?? <int>[];
}

Map<String?, List<ExpenseEntry>> _groupExpensesByAccount(
    List<ExpenseEntry> expenses) {
  final grouped = <String?, List<ExpenseEntry>>{};
  for (final expense in expenses) {
    final key = (expense.householdId != null && expense.householdId!.isNotEmpty)
        ? expense.householdId
        : null;
    grouped.putIfAbsent(key, () => []).add(expense);
  }
  return grouped;
}

String _resolveAccountSheetName(
  String? householdId, {
  required Map<String, String> householdNames,
}) {
  if (householdId == null || householdId.isEmpty) {
    return 'Personal';
  }
  return householdNames[householdId] ?? 'Household';
}

String _resolveAccountLabel(
  ExpenseEntry expense, {
  required String personalLabel,
  required Map<String, String> householdNames,
}) {
  if (expense.householdId == null || expense.householdId!.isEmpty) {
    return personalLabel.isNotEmpty ? personalLabel : 'Personal';
  }
  return householdNames[expense.householdId] ?? 'Household';
}

String _resolveUserLabel(
  ExpenseEntry expense, {
  required String personalLabel,
}) {
  final trimmed = expense.userName?.trim() ?? '';
  if (trimmed.isNotEmpty) return trimmed;
  if (expense.householdId == null || expense.householdId!.isEmpty) {
    return personalLabel;
  }
  return '';
}

String _uniqueSheetName(Set<String> existingNames, String baseName) {
  final sanitized = _sanitizeSheetName(baseName);
  if (!existingNames.contains(sanitized)) {
    return sanitized;
  }

  var index = 2;
  while (true) {
    final suffix = ' ($index)';
    final maxLength = 31 - suffix.length;
    final safeLength =
        sanitized.length < maxLength ? sanitized.length : maxLength;
    final candidate =
        _sanitizeSheetName(sanitized.substring(0, safeLength)) + suffix;
    if (!existingNames.contains(candidate)) {
      return candidate;
    }
    index += 1;
  }
}

String _sanitizeSheetName(String value) {
  final sanitized = value.replaceAll(RegExp(r'[\\/\[\]\*\?:]'), '-').trim();
  if (sanitized.isEmpty) {
    return 'Sheet';
  }
  if (sanitized.length > 31) {
    return sanitized.substring(0, 31);
  }
  return sanitized;
}

class _AccountSummary {
  _AccountSummary({
    required this.accountLabel,
    required this.currency,
  });

  final String accountLabel;
  final String currency;
  int count = 0;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
}
