import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/services/sse_service.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/import/data/import_dedupe.dart';
import 'package:moneko/features/import/data/import_local_parser.dart';
import 'package:moneko/features/import/data/import_mapping.dart';
import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

final importWizardProvider =
    StateNotifierProvider<ImportWizardNotifier, ImportWizardState>((ref) {
  return ImportWizardNotifier(ref);
});

class ImportWizardNotifier extends StateNotifier<ImportWizardState> {
  ImportWizardNotifier(this._ref) : super(const ImportWizardState()) {
    _initializeTargetAccount();
  }

  final Ref _ref;
  static const int _maxPdfImportBytes = 20 * 1024 * 1024;

  void _initializeTargetAccount() {
    final scope = _ref.read(householdScopeProvider);
    state = state.copyWith(
      targetHouseholdId: scope.activeAccountHouseholdId,
      targetIsPortfolio: scope.activeAccountType == ActiveAccountType.portfolio,
      clearTargetHouseholdId: scope.activeAccountHouseholdId == null ||
          scope.activeAccountHouseholdId!.isEmpty,
    );
  }

  Future<void> pickFile() async {
    state = state.copyWith(
      clearErrorMessage: true,
      clearParsingStatusMessage: true,
    );
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'pdf', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      state = state.copyWith(
        isParsing: true,
        parsingStatusMessage: 'Preparing file...',
      );

      final file = result.files.single;
      final extension = file.extension?.toLowerCase();
      final bytes = file.bytes;
      if (bytes == null) {
        state = state.copyWith(
          isParsing: false,
          clearParsingStatusMessage: true,
          errorMessage: 'Failed to read file',
        );
        return;
      }

      ImportTable table;
      if (extension == 'pdf') {
        if (bytes.length > _maxPdfImportBytes) {
          throw Exception(
            'PDF is too large to import. Keep it under 20MB or split into smaller files.',
          );
        }
        table = await _analyzePdfToImportTable(
          bytes: bytes,
          filename: file.name,
        );
      } else {
        table = await parseLocalImportTable(
          LocalImportParseRequest(bytes: bytes, extension: extension),
        );
      }

      final mapping = autoMapFields(table.headers);
      final parsedRows = _parseAndDedupe(table, mapping);

      state = state.copyWith(
        isParsing: false,
        clearParsingStatusMessage: true,
        fileName: file.name,
        table: table,
        mapping: mapping,
        parsedRows: parsedRows,
        step: ImportStep.mapColumns,
      );
    } catch (e) {
      state = state.copyWith(
        isParsing: false,
        clearParsingStatusMessage: true,
        errorMessage: _toImportErrorMessage(e),
      );
    }
  }

  String _toImportErrorMessage(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('unauthorized') || lower.contains('401')) {
      return 'Your session has expired. Please sign in again and retry the import.';
    }

    if (lower.contains('server configuration error') ||
        lower.contains('gemini_api_key')) {
      return 'Import service is temporarily unavailable. Please try again shortly.';
    }

    if (lower.contains('504') ||
        lower.contains('gateway timeout') ||
        lower.contains('timed out')) {
      return 'This file is taking too long to process. Please split large PDFs into smaller parts (for example 1-5 pages each) and try again.';
    }

    if (lower.contains('payload too large') ||
        lower.contains('http 413') ||
        lower.contains('too large')) {
      return 'File is too large to import. Please reduce the file size and try again.';
    }

    if ((lower.contains('pdf') && lower.contains('5 page')) ||
        lower.contains('maximum number of pages') ||
        lower.contains('document exceeds page limit')) {
      return 'This PDF is too long for one pass. Please split it into smaller files (1-5 pages each) and import again.';
    }

    if (lower.contains('unsupported or unreadable attachment format') ||
        lower.contains('no items extracted') ||
        lower.contains('failed to analyze pdf') ||
        lower.contains('failed to analyze expense') ||
        lower.contains('could not extract valid transactions') ||
        lower.contains('no valid tool call found')) {
      return 'We could not extract transactions from this file. For PDF imports, use a digital statement or a clearer scan.';
    }

    if (lower.contains('formatexception') ||
        lower.contains('unexpected extension byte') ||
        lower.contains('malformed')) {
      return 'Unable to read file text encoding. Please export your CSV as UTF-8 and try again.';
    }

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  Future<ImportTable> _analyzePdfToImportTable({
    required Uint8List bytes,
    required String filename,
  }) async {
    final authUser = _ref.read(authProvider);
    if (authUser.isEmpty || authUser.uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final session = supabase.auth.currentSession;
    if (session == null) {
      throw Exception('No auth session');
    }

    final now = DateTime.now();
    final dateOnly = DateFormat('yyyy-MM-dd').format(now);
    final base64Data = base64Encode(bytes);

    final filterState = _ref.read(homeFilterProvider);
    final selectedCurrency = filterState.selectedCurrency;

    final language = _resolveLanguageTag();

    final body = <String, dynamic>{
      'userId': authUser.uid,
      'date': dateOnly,
      'typeHint': 'mixed',
      'language': language,
      'attachments': [
        {
          'filename': filename,
          'contentType': 'application/pdf',
          'data': base64Data,
        },
      ],
      if (selectedCurrency != null && selectedCurrency.isNotEmpty)
        'currency': selectedCurrency.toUpperCase(),
    };

    Map<String, dynamic>? responseData;

    final supabaseUrl = Constants.supabaseUrl;
    if (supabaseUrl.isNotEmpty) {
      var streamReportedBackendError = false;
      try {
        final sseUrl =
            Uri.parse('$supabaseUrl/functions/v1/analyze-expense?stream=true');
        state = state.copyWith(parsingStatusMessage: 'Analyzing PDF...');
        await for (final event in SSEService.streamRequest(
          url: sseUrl,
          body: body,
          headers: <String, String>{
            'Authorization': 'Bearer ${session.accessToken}',
          },
          timeout: const Duration(minutes: 4),
        )) {
          if (event.event == 'progress' && event.data is Map<String, dynamic>) {
            final progress = AnalysisProgressEvent.fromJson(
              event.data as Map<String, dynamic>,
            );
            state = state.copyWith(
              parsingStatusMessage: progress.displayMessage,
            );
          }

          if (event.event == 'complete' && event.data is Map<String, dynamic>) {
            responseData = event.data as Map<String, dynamic>;
          } else if (event.event == 'error') {
            streamReportedBackendError = true;
            final err = (event.data is Map<String, dynamic>)
                ? (event.data['error']?.toString() ?? 'Failed to analyze PDF')
                : event.data.toString();
            throw Exception(err);
          }
        }
      } catch (_) {
        if (streamReportedBackendError) {
          rethrow;
        }
        responseData = null;
      }
    }

    if (responseData == null) {
      state = state.copyWith(
        parsingStatusMessage: 'Finalizing PDF analysis...',
      );
      final response = await supabase.functions.invoke(
        'analyze-expense',
        body: body,
        headers: <String, String>{
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected response from analyze-expense');
      }
      responseData = data;
    }

    if (responseData['success'] != true) {
      throw Exception(responseData['error'] ?? 'Failed to analyze PDF');
    }

    final resultData = responseData['data'];
    final items = resultData is Map ? resultData['items'] : null;
    if (items is! List) {
      throw Exception('No items extracted');
    }

    final filtered = _filterAnalyzedItems(items);
    final normalized = filtered.map((rawItem) {
      final item = rawItem is Map
          ? Map<String, dynamic>.from(rawItem)
          : <String, dynamic>{};
      final rawAmount = item['amount'];
      final amountText = rawAmount == null ? '' : rawAmount.toString();
      final dateText = item['date']?.toString() ?? '';
      final category = item['category']?.toString() ?? '';
      final description = item['description']?.toString() ?? '';
      final currency = item['currency']?.toString() ?? '';
      final type = item['type']?.toString() ?? '';

      return <String>[
        dateText,
        amountText,
        category,
        description,
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
        'currency',
        'type',
      ],
      rows: normalized,
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

  String _resolveLanguageTag() {
    final selected = _ref.read(localeProvider);
    final locale =
        selected ?? WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = locale.languageCode;
    final country = (locale.countryCode ?? '').trim();
    if (country.isEmpty) return languageCode;
    return '$languageCode-${country.toUpperCase()}';
  }

  void setStep(ImportStep step) {
    state = state.copyWith(step: step);
  }

  void updateMapping(ImportField field, int? columnIndex) {
    final current = state.mapping;
    final table = state.table;
    if (current == null || table == null) return;

    final updated = Map<ImportField, int>.from(current.fieldToColumnIndex);
    if (columnIndex == null) {
      updated.remove(field);
    } else {
      updated[field] = columnIndex;
    }

    final newMapping = ImportMapping(
      fieldToColumnIndex: updated,
      hasHeader: current.hasHeader,
    );
    final parsedRows = _parseAndDedupe(table, newMapping);
    state = state.copyWith(mapping: newMapping, parsedRows: parsedRows);
  }

  void setSkipDuplicates(bool value) {
    state = state.copyWith(skipDuplicates: value);
  }

  void setTargetAccount({String? householdId, required bool isPortfolio}) {
    final trimmed = householdId?.trim();
    final normalized = trimmed != null && trimmed.isNotEmpty ? trimmed : null;
    final updatedRows = markDuplicates(
      state.parsedRows,
      _existingExpensesForTarget(normalized),
    );
    state = state.copyWith(
      targetHouseholdId: normalized,
      targetIsPortfolio: normalized == null ? false : isPortfolio,
      clearTargetHouseholdId: normalized == null,
      parsedRows: updatedRows,
    );
  }

  void resetAfterImport() {
    final targetHouseholdId = state.targetHouseholdId;
    final targetIsPortfolio = state.targetIsPortfolio;
    state = ImportWizardState(
      step: ImportStep.selectFile,
      targetHouseholdId: targetHouseholdId,
      targetIsPortfolio: targetIsPortfolio,
    );
  }

  void updateParsedRow(ImportParsedRow updated) {
    final rows = [...state.parsedRows];
    if (updated.index < 0 || updated.index >= rows.length) return;
    rows[updated.index] = _validateRow(updated);
    final deduped = markDuplicates(
        rows, _existingExpensesForTarget(state.targetHouseholdId));
    state = state.copyWith(parsedRows: deduped);
  }

  void deleteParsedRow(int index) {
    final rows = [...state.parsedRows];
    // Validate existence
    if (!rows.any((r) => r.index == index)) {
      throw Exception('Row not found');
    }

    // Let's just remove it from the list. The 'index' field on ImportParsedRow is used for identification.
    final updatedRows = rows.where((r) => r.index != index).toList();

    // We might want to re-dedupe?
    // If we remove a transaction that was a duplicate of another, the other one remains.
    // If we remove a transaction that was the *original* that caused others to be duplicates...
    // The current dedupe logic compares against *existing* DB expenses and *other rows in the list*.

    final deduped = markDuplicates(
        updatedRows, _existingExpensesForTarget(state.targetHouseholdId));

    state = state.copyWith(parsedRows: deduped);
  }

  Future<void> importRows() async {
    final table = state.table;
    final mapping = state.mapping;
    if (table == null || mapping == null) return;

    final authUser = _ref.read(authProvider);
    if (authUser.isEmpty || authUser.uid.isEmpty) {
      state = state.copyWith(errorMessage: 'User not authenticated');
      return;
    }

    state = state.copyWith(
      isImporting: true,
      importedCount: 0,
      failedCount: 0,
      clearErrorMessage: true,
    );
    final filterState = _ref.read(homeFilterProvider);
    final analytics = _ref.read(analyticsProvider);
    final defaultCurrency =
        filterState.selectedCurrency ?? analytics.preferredCurrency ?? 'USD';
    final targetHouseholdId = state.targetHouseholdId;
    final targetIsPortfolio = state.targetIsPortfolio;

    int success = 0;
    int failed = 0;

    for (final row in state.parsedRows) {
      if (!row.isValid) {
        failed += 1;
        continue;
      }
      if (state.skipDuplicates && row.isDuplicate) {
        continue;
      }

      final currency = row.currency ?? defaultCurrency;
      final amount = (row.amountCents ?? 0) / 100.0;
      final endpoint = row.type == 'income' ? 'save-income' : 'save-expense';

      final dateOnly = DateFormat('yyyy-MM-dd').format(row.date!);
      final safeTimestamp =
          DateTime(row.date!.year, row.date!.month, row.date!.day, 12);
      final body = {
        'userId': authUser.uid,
        'amount': amount,
        'category': row.category ?? 'uncategorized',
        'currency': currency,
        'date': dateOnly,
        'clientCreatedAt': safeTimestamp.toUtc().toIso8601String(),
        'type': row.type ?? 'expense',
        if (targetHouseholdId != null && targetHouseholdId.isNotEmpty)
          'householdId': targetHouseholdId,
        if (targetHouseholdId != null && targetHouseholdId.isNotEmpty)
          'isPortfolio': targetIsPortfolio,
        if (row.description != null) 'description': row.description,
      };

      try {
        final response = await supabase.functions.invoke(endpoint, body: body);
        if (response.data == null || response.data['success'] != true) {
          failed += 1;
        } else {
          success += 1;
        }
      } catch (_) {
        failed += 1;
      }
    }

    if (authUser.uid.isNotEmpty &&
        (targetHouseholdId == null || targetHouseholdId.isEmpty)) {
      await _ref.read(analyticsProvider.notifier).loadData(authUser.uid);
    }

    state = state.copyWith(
      isImporting: false,
      importedCount: success,
      failedCount: failed,
      step: ImportStep.preview,
    );
  }

  List<ImportParsedRow> _parseAndDedupe(
    ImportTable table,
    ImportMapping mapping,
  ) {
    final rows = <ImportParsedRow>[];
    for (var i = 0; i < table.rows.length; i++) {
      rows.add(parseRow(table.rows[i], mapping, index: i));
    }

    return markDuplicates(
        rows, _existingExpensesForTarget(state.targetHouseholdId));
  }

  List<ExpenseEntry> _existingExpensesForTarget(String? householdId) {
    final allExpenses = _ref.read(analyticsProvider).allExpenses;
    if (householdId == null || householdId.isEmpty) {
      return allExpenses
          .where(
            (expense) =>
                expense.householdId == null ||
                (expense.householdId?.isEmpty ?? false),
          )
          .toList();
    }
    return allExpenses
        .where((expense) => expense.householdId == householdId)
        .toList();
  }

  ImportParsedRow _validateRow(ImportParsedRow row) {
    final errors = <String>[];
    if (row.date == null) errors.add('invalid_date');
    if (row.amountCents == null) errors.add('invalid_amount');
    return row.copyWith(errors: errors);
  }
}
