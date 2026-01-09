import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

Future<void> exportTransactionsAsCsvSheet(
  BuildContext context,
  List<ExpenseEntry> expenses, {
  String fileNamePrefix = 'transactions',
}) async {
  if (expenses.isEmpty) {
    AppToast.info(context, context.l10n.noTransactionsFound);
    return;
  }

  debugPrint(
      '[exportTransactionsAsCsvSheet] count=${expenses.length} web=$kIsWeb');

  try {
    final csv = _buildCsv(expenses);
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = '${fileNamePrefix}_$timestamp.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final shareOrigin = _resolveShareOrigin(context);

    if (kIsWeb) {
      debugPrint('[exportTransactionsAsCsvSheet] sharing in web: $fileName');
      await Share.shareXFiles(
        [
          XFile.fromData(bytes, mimeType: 'text/csv', name: fileName),
        ],
        subject: fileName,
        sharePositionOrigin: shareOrigin,
      );
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    debugPrint('[exportTransactionsAsCsvSheet] temp file: ${file.path}');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[exportTransactionsAsCsvSheet] share file');
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: fileName,
      sharePositionOrigin: shareOrigin,
    );
  } catch (e, stack) {
    debugPrint(
      '[exportTransactionsAsCsvSheet] failed: $e\n$stack',
    );
    AppToast.error(
      context,
      '${context.l10n.anUnexpectedErrorOccurred} (${e.toString()})',
    );
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

String _buildCsv(List<ExpenseEntry> expenses) {
  final buffer = StringBuffer();
  buffer.writeln('Date,Category,Description,Amount,Currency,Type');
  final dateFormat = DateFormat('yyyy-MM-dd');

  for (final expense in expenses) {
    final date = dateFormat.format(expense.date);
    final category = expense.category ?? '';
    final description = expense.rawText ?? '';
    final amount = expense.amount.toStringAsFixed(2);
    final currency = expense.currency ?? '';
    final type = expense.type ?? 'expense';

    buffer.writeln([
      _escapeCsv(date),
      _escapeCsv(category),
      _escapeCsv(description),
      _escapeCsv(amount),
      _escapeCsv(currency),
      _escapeCsv(type),
    ].join(','));
  }

  return buffer.toString();
}

String _escapeCsv(String value) {
  final needsQuotes = value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuotes) return value;
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
