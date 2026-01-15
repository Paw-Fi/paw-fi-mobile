import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = '${fileNamePrefix}_$timestamp.xlsx';
    final bytes = Uint8List.fromList(excelBytes);

    if (kIsWeb) {
      debugPrint('[exportTransactionsAsExcelSheet] sharing in web: $fileName');
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
    debugPrint('[exportTransactionsAsExcelSheet] temp file: ${file.path}');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[exportTransactionsAsExcelSheet] share file');

    await Share.shareXFiles(
      [
        XFile(file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ],
      subject: fileName,
      sharePositionOrigin: shareOrigin,
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
    if (isIncome) {
      totalIncome += amountVal;
    } else {
      totalExpense += amountVal;
      // Track category for expenses only
      final currentCatTotal = categoryMap[category] ?? 0.0;
      categoryMap[category] = currentCatTotal + amountVal;
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
