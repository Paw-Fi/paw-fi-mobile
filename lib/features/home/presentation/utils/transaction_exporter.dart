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

  // Renaissance default sheet to 'Transactions'
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null) {
    excel.rename(defaultSheet, 'Transactions');
  }

  final Sheet sheet = excel['Transactions'];

  // Add Headers
  final headers = [
    'Date',
    'Account / User',
    'Description (Payee)',
    'Category',
    'Amount',
    'Currency',
    'Type',
    'Notes',
    'ID',
  ];

  // Adding header row
  // cellStyle is optional
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  // Make header bold if possible - Excel package support for styles is limited/version dependent
  // We'll skip complex styling to avoid breaking changes, content is key.

  final dateFormat = DateFormat('yyyy-MM-dd');

  for (final expense in expenses) {
    final date = dateFormat.format(expense.date);

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

    // Amount formatting - ensure it's a number for Excel
    final double amountVal = expense.amount;

    final currency = expense.currency ?? 'USD';
    final type = expense.type ?? 'expense';

    // Notes - we don't have a separate notes field, leaving empty or using extra data
    const notes = '';

    final row = [
      TextCellValue(date),
      TextCellValue(accountInfo),
      TextCellValue(description),
      TextCellValue(category),
      DoubleCellValue(amountVal),
      TextCellValue(currency),
      TextCellValue(type),
      TextCellValue(notes),
      TextCellValue(expense.id),
    ];

    sheet.appendRow(row);
  }

  return excel.encode();
}
