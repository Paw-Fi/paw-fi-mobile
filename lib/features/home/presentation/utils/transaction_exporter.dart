import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/transaction_export_data_source.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

Future<void> exportTransactionsAsExcelSheet(
  BuildContext context,
  List<ExpenseEntry> expenses, {
  required SupabaseClient client,
  String fileNamePrefix = 'transactions',
  String? preferredTimezone,
  Map<String, String> householdNames = const {},
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
    final dataSource = TransactionExportDataSource(client);
    final exportExpenses = await dataSource.enrichExportExpenses(expenses);
    final resolvedHouseholdNames =
        await dataSource.fetchExportHouseholdNames(exportExpenses);
    final excelBytes = await buildTransactionExportWorkbook(
      exportExpenses,
      householdNames: {...householdNames, ...resolvedHouseholdNames},
      preferredTimezone: preferredTimezone,
      includeSpaceSheets: false,
    );

    if (!context.mounted) return;

    if (excelBytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    final shareResult = await _shareExcelBytes(
      context,
      excelBytes,
      shareOrigin: shareOrigin,
      fileNamePrefix: fileNamePrefix,
      logPrefix: '[exportTransactionsAsExcelSheet]',
    );
    if (context.mounted) {
      _showShareResultToast(
        context,
        shareResult,
        logPrefix: '[exportTransactionsAsExcelSheet]',
      );
    }
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
  String? preferredTimezone,
  DateTimeRange? selectedDateRange,
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
    final excelBytes = await buildTransactionExportWorkbook(
      expenses,
      personalLabel: personalLabel,
      householdNames: householdNames,
      receiptFileNamesById: const {},
      selectedDateRange: selectedDateRange,
      preferredTimezone: preferredTimezone,
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
    final shareResult = await _shareExcelBytes(
      context,
      excelBytes,
      shareOrigin: shareOrigin,
      fileNamePrefix: fileNamePrefix,
      logPrefix: '[exportAllTransactionsAsExcelSheet]',
    );
    if (context.mounted) {
      _showShareResultToast(
        context,
        shareResult,
        logPrefix: '[exportAllTransactionsAsExcelSheet]',
      );
    }
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
    final shareResult = await _shareZipBytes(
      context,
      zipBytes,
      shareOrigin: shareOrigin,
      fileNamePrefix: fileNamePrefix,
      logPrefix: '[exportAllReceiptsAsZip]',
    );
    if (context.mounted) {
      _showShareResultToast(
        context,
        shareResult,
        logPrefix: '[exportAllReceiptsAsZip]',
      );
    }
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

Future<ShareResult> _shareExcelBytes(
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
    final result = await Share.shareXFiles(
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
    debugPrint('$logPrefix share result: $result');
    return result;
  }

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  debugPrint('$logPrefix temp file: ${file.path}');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('$logPrefix share file');

  final result = await Share.shareXFiles(
    [
      XFile(file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    ],
    subject: fileName,
    sharePositionOrigin: shareOrigin,
  );
  debugPrint('$logPrefix share result: $result');
  return result;
}

Future<ShareResult> _shareZipBytes(
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
    final result = await Share.shareXFiles(
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
    debugPrint('$logPrefix share result: $result');
    return result;
  }

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  debugPrint('$logPrefix temp file: ${file.path}');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('$logPrefix share file');

  final result = await Share.shareXFiles(
    [
      XFile(file.path, mimeType: 'application/zip'),
    ],
    subject: fileName,
    sharePositionOrigin: shareOrigin,
  );
  debugPrint('$logPrefix share result: $result');
  return result;
}

void _showShareResultToast(
  BuildContext context,
  ShareResult result, {
  required String logPrefix,
}) {
  debugPrint('$logPrefix handling share result status=${result.status}');
  switch (result.status) {
    case ShareResultStatus.success:
    case ShareResultStatus.unavailable:
      AppToast.success(context, context.l10n.completed);
      return;
    case ShareResultStatus.dismissed:
      AppToast.info(context, context.l10n.canceledStatus);
      return;
  }
}

Future<List<int>?> buildTransactionExportWorkbook(
  List<ExpenseEntry> expenses, {
  String personalLabel = '',
  Map<String, String> householdNames = const {},
  Map<String, String> receiptFileNamesById = const {},
  DateTimeRange? selectedDateRange,
  String? preferredTimezone,
  bool includeSpaceSheets = true,
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
    selectedDateRange: selectedDateRange,
  );

  final allSheetName = _uniqueSheetName(
      existingNames, includeSpaceSheets ? 'All Transactions' : 'Transactions');
  _appendTransactionsSheet(
    excel[allSheetName],
    expenses,
    personalLabel: personalLabel,
    householdNames: householdNames,
    receiptFileNamesById: receiptFileNamesById,
    preferredTimezone: preferredTimezone,
  );
  existingNames.add(allSheetName);

  if (!includeSpaceSheets) return excel.encode();

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
      preferredTimezone: preferredTimezone,
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
  DateTimeRange? selectedDateRange,
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

  final range = selectedDateRange != null
      ? '${dateFormat.format(selectedDateRange.start)} to ${dateFormat.format(selectedDateRange.end)}'
      : (minDate != null && maxDate != null)
          ? '${dateFormat.format(minDate)} to ${dateFormat.format(maxDate)}'
          : '-';

  sheet.appendRow([
    TextCellValue('Exported At'),
    TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
  ]);
  sheet.appendRow([TextCellValue('Date Range'), TextCellValue(range)]);
  sheet.appendRow([TextCellValue('')]);

  sheet.appendRow([
    TextCellValue('Space'),
    TextCellValue('Currency'),
    TextCellValue('Transactions'),
    TextCellValue('Total Income'),
    TextCellValue('Total Expenses'),
    TextCellValue('Net'),
    TextCellValue('Total Days'),
    TextCellValue('Savings Rate (%)'),
    TextCellValue('Daily Average Spend'),
    TextCellValue('Top Expense Category'),
    TextCellValue('Top Category Amount'),
  ]);

  final summaries = <String, _AccountSummary>{};
  for (final expense in expenses) {
    final accountLabel = _resolveAccountLabel(
      expense,
      personalLabel: personalLabel,
      householdNames: householdNames,
    );
    final currency = _exportCurrency(expense);
    final householdId = expense.householdId?.trim() ?? '';
    final key = '${householdId.isEmpty ? "personal" : householdId}::$currency';
    final summary = summaries.putIfAbsent(
      key,
      () => _AccountSummary(accountLabel: accountLabel, currency: currency),
    );
    summary.count += 1;
    final amountCents = expense.amountCents.abs();
    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    if (isIncome) {
      summary.totalIncomeCents += amountCents;
    } else {
      summary.totalExpenseCents += amountCents;
      final category = expense.category?.trim().isNotEmpty == true
          ? expense.category!
          : 'Uncategorized';
      summary.categoryTotals.update(category, (value) => value + amountCents,
          ifAbsent: () => amountCents);
    }
  }

  final sortedSummaries = summaries.values.toList()
    ..sort((a, b) {
      final account = a.accountLabel.compareTo(b.accountLabel);
      if (account != 0) return account;
      return a.currency.compareTo(b.currency);
    });

  for (final summary in sortedSummaries) {
    final start = selectedDateRange?.start ?? minDate;
    final end = selectedDateRange?.end ?? maxDate;
    final days = start == null || end == null
        ? 0
        : DateTime.utc(end.year, end.month, end.day)
                .difference(DateTime.utc(start.year, start.month, start.day))
                .inDays +
            1;
    final topCategories = summary.categoryTotals.entries.toList()
      ..sort((left, right) {
        final amountOrder = right.value.compareTo(left.value);
        return amountOrder != 0 ? amountOrder : left.key.compareTo(right.key);
      });
    final topCategory = topCategories.isEmpty ? null : topCategories.first;
    final net = summary.totalIncome - summary.totalExpense;
    sheet.appendRow([
      TextCellValue(summary.accountLabel),
      TextCellValue(summary.currency),
      IntCellValue(summary.count),
      DoubleCellValue(summary.totalIncome),
      DoubleCellValue(summary.totalExpense),
      DoubleCellValue(net),
      IntCellValue(days),
      DoubleCellValue(summary.totalIncome > 0
          ? double.parse((net / summary.totalIncome * 100).toStringAsFixed(2))
          : 0),
      DoubleCellValue(days > 0 ? summary.totalExpense / days : 0),
      TextCellValue(topCategory?.key ?? '-'),
      DoubleCellValue((topCategory?.value ?? 0) / 100),
    ]);
  }
}

void _appendTransactionsSheet(
  Sheet sheet,
  List<ExpenseEntry> expenses, {
  required String personalLabel,
  required Map<String, String> householdNames,
  Map<String, String> receiptFileNamesById = const {},
  String? preferredTimezone,
}) {
  const headers = [
    'Date',
    'Time',
    'Space',
    'Recorded By',
    'Wallet',
    'Description / Notes',
    'Merchant',
    'Category',
    'Amount',
    'Currency',
    'Type',
    'Financial Activity',
    'Bank Status',
    'Item Breakdown',
    'Recurring',
    'Scheduled Date',
    'Receipt Link',
  ];
  sheet.appendRow(headers.map(TextCellValue.new).toList());

  final dateFormat = DateFormat('yyyy-MM-dd');
  final timeFormat = DateFormat('HH:mm:ss');
  final rows = expenses.toList()
    ..sort((a, b) {
      final dateOrder = b.date.compareTo(a.date);
      if (dateOrder != 0) return dateOrder;
      final timeOrder = b.createdAt.compareTo(a.createdAt);
      return timeOrder != 0 ? timeOrder : b.id.compareTo(a.id);
    });

  for (final expense in rows) {
    final merchant = expense.merchantStructuredName?.trim();
    final receiptUrl = expense.receiptImageUrl?.trim() ?? '';
    final receiptUri = Uri.tryParse(receiptUrl);
    final receiptLink = receiptFileNamesById[expense.id] ??
        (receiptUri != null &&
                receiptUri.hasAuthority &&
                (receiptUri.scheme == 'https' || receiptUri.scheme == 'http')
            ? receiptUrl
            : '');
    final hasRecordedTime = expense.createdAt.millisecondsSinceEpoch != 0 &&
        !_isScheduledRecurring(expense);
    // Transfer wall time is an optional serialized row field. Older models
    // omit it, so this export does not require the separate wallet-time update.
    final transferTime = expense.id.startsWith('transfer:')
        ? (expense.toJson()['transfer_time'] as String?)?.trim() ?? ''
        : '';
    sheet.appendRow([
      TextCellValue(dateFormat.format(expense.date)),
      TextCellValue(transferTime.isNotEmpty
          ? transferTime
          : hasRecordedTime
              ? timeFormat.format(toEffectiveWallTime(
                  utcOrLocalInstant: expense.createdAt,
                  preferredTimezone: preferredTimezone,
                ))
              : ''),
      TextCellValue(_resolveAccountLabel(
        expense,
        personalLabel: personalLabel,
        householdNames: householdNames,
      )),
      TextCellValue(_resolveUserLabel(expense, personalLabel: personalLabel)),
      TextCellValue(expense.accountName?.trim() ?? ''),
      TextCellValue(expense.rawText ?? ''),
      TextCellValue(
          merchant?.isNotEmpty == true ? merchant! : expense.merchant ?? ''),
      TextCellValue(expense.category?.trim().isNotEmpty == true
          ? expense.category!
          : 'Uncategorized'),
      DoubleCellValue(expense.amount),
      TextCellValue(_exportCurrency(expense)),
      TextCellValue(expense.type ?? 'expense'),
      TextCellValue(_financialActivityLabel(expense)),
      TextCellValue(expense.bankAccountId?.trim().isNotEmpty == true
          ? (expense.isProviderPending ? 'Pending' : 'Posted')
          : ''),
      TextCellValue((expense.breakdown ?? const <String>[]).join('\n')),
      TextCellValue(_recurringLabel(expense)),
      TextCellValue(expense.scheduledOccurrenceDate == null
          ? ''
          : dateFormat.format(expense.scheduledOccurrenceDate!)),
      TextCellValue(receiptLink),
    ]);
  }
}

String _exportCurrency(ExpenseEntry expense) {
  final currency = expense.currency?.trim() ?? '';
  return currency.isEmpty ? 'UNKNOWN' : currency.toUpperCase();
}

String _financialActivityLabel(ExpenseEntry expense) {
  return switch (expense.analyticsClass) {
    'consumer_spend' => 'Spending',
    'income' => 'Income',
    'transfer_in' => 'Transfer in',
    'transfer_out' => 'Transfer out',
    'debt_payment' => 'Debt repayment',
    'loan_disbursement' => 'Loan received',
    'refund_or_reversal' => 'Refund / reversal',
    'bank_fee' => 'Bank fee',
    'cash_movement' => 'Cash movement',
    'unknown' => 'Unclassified',
    _ => expense.countsTowardIncome ? 'Income' : 'Spending',
  };
}

String _recurringLabel(ExpenseEntry expense) {
  if (_isScheduledRecurring(expense)) {
    return 'Scheduled';
  }
  if (expense.parentRecurringId?.isNotEmpty == true ||
      expense.scheduledOccurrenceDate != null ||
      expense.recurringConfirmedAt != null) {
    return 'Recorded payment';
  }
  return expense.providerRecurring ? 'Bank-detected recurring' : '';
}

bool _isScheduledRecurring(ExpenseEntry expense) =>
    expense.isRecurring ||
    extractRecurringTransactionIdFromProjectedExpenseId(expense.id) != null;

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

const _maximumLocalReceiptBytes = 15 * 1024 * 1024;
const _supportedReceiptExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
const _pendingAiInputDirectoryName = 'pending_ai_inputs';

@visibleForTesting
Future<Uint8List?> readLocalReceiptBytesForExport(
  String localPath, {
  Iterable<Directory>? allowedDirectories,
}) async {
  if (kIsWeb || localPath.trim().isEmpty) return null;

  try {
    final file = File(localPath);
    final filePath = await file.resolveSymbolicLinks();
    final directories = allowedDirectories ?? await _exportReceiptDirectories();
    final isWithinAllowedDirectory = await _isWithinAllowedDirectory(
      filePath,
      directories,
    );
    final extension = _resolveImageExtension(filePath);
    if (!isWithinAllowedDirectory ||
        !_supportedReceiptExtensions.contains(extension)) {
      return null;
    }

    final resolvedFile = File(filePath);
    final stat = await resolvedFile.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size > _maximumLocalReceiptBytes) {
      return null;
    }
    final bytes = await resolvedFile.readAsBytes();
    return bytes.length <= _maximumLocalReceiptBytes &&
            _hasSupportedImageSignature(bytes, extension)
        ? bytes
        : null;
  } catch (_) {
    return null;
  }
}

Future<List<Directory>> _exportReceiptDirectories() async {
  final documents = await getApplicationDocumentsDirectory();
  return [
    Directory('${documents.path}/$_pendingAiInputDirectoryName'),
  ];
}

Future<bool> _isWithinAllowedDirectory(
  String filePath,
  Iterable<Directory> directories,
) async {
  for (final directory in directories) {
    final rootPath = await directory.resolveSymbolicLinks();
    if (filePath.startsWith('$rootPath${Platform.pathSeparator}')) {
      return true;
    }
  }
  return false;
}

bool _hasSupportedImageSignature(Uint8List bytes, String extension) {
  switch (extension) {
    case '.jpg':
    case '.jpeg':
      return bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
    case '.png':
      return bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
    case '.webp':
      return bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50;
  }
  return false;
}

Future<_ReceiptBundle> _downloadReceiptImages(
  List<ExpenseEntry> expenses,
) async {
  final fileNamesByExpenseId = <String, String>{};
  final files = <_ReceiptFile>[];
  final usedNames = <String>{};

  for (final expense in expenses) {
    final localPath = expense.localReceiptImagePath?.trim() ?? '';
    final url = expense.receiptImageUrl?.trim() ?? '';
    Uint8List? bytes;
    var source = url;
    if (!kIsWeb && localPath.isNotEmpty) {
      bytes = await readLocalReceiptBytesForExport(localPath);
      if (bytes != null) source = localPath;
    }
    if (bytes == null && url.isNotEmpty) {
      bytes = await _downloadBytes(url);
    }
    if (bytes == null || bytes.isEmpty) continue;

    final fileName = _uniqueReceiptFileName(
      expenseId: expense.id,
      url: source,
      usedNames: usedNames,
    );

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
  int totalIncomeCents = 0;
  int totalExpenseCents = 0;
  final categoryTotals = <String, int>{};

  double get totalIncome => totalIncomeCents / 100;
  double get totalExpense => totalExpenseCents / 100;
}
