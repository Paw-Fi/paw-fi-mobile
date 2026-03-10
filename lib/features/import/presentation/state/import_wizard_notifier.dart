import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
import 'package:moneko/features/import/data/import_excel_parser.dart';
import 'package:moneko/features/import/data/import_local_parser.dart';
import 'package:moneko/features/import/data/import_mapping.dart';
import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
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
  static const int _batchSize = 500;

  void _initializeTargetAccount() {
    final scope = _ref.read(householdScopeProvider);
    state = state.copyWith(
      targetHouseholdId: scope.activeAccountHouseholdId,
      targetIsPortfolio: scope.activeAccountType == ActiveAccountType.portfolio,
      clearTargetHouseholdId: scope.activeAccountHouseholdId == null ||
          scope.activeAccountHouseholdId!.isEmpty,
    );
  }

  Future<void> pickFile({List<String>? allowedExtensions}) async {
    if (state.isParsing || state.isImporting) return;

    state = state.copyWith(
      clearErrorMessage: true,
      clearParsingStatusMessage: true,
    );
    try {
      final normalizedAllowedExtensions =
          (allowedExtensions != null && allowedExtensions.isNotEmpty)
              ? allowedExtensions
              : supportedImportExtensions;

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: normalizedAllowedExtensions,
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
      List<ImportSheetResult> availableSheets = const [];
      int selectedSheetIndex = -1;

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
      } else if (extension == 'xlsx' || extension == 'xls') {
        // Parse all sheets; let the user pick if there are multiple.
        availableSheets = await compute(
          _parseExcelSheetsSync,
          bytes,
        );
        if (availableSheets.isEmpty) {
          state = state.copyWith(
            isParsing: false,
            clearParsingStatusMessage: true,
            errorMessage: 'No data found in Excel file.',
          );
          return;
        }
        // Default: sheet with the most rows.
        availableSheets.sort(
          (a, b) => b.table.rows.length.compareTo(a.table.rows.length),
        );
        selectedSheetIndex = 0;
        table = availableSheets[selectedSheetIndex].table;
      } else {
        table = await parseLocalImportTable(
          LocalImportParseRequest(bytes: bytes, extension: extension),
        );
      }

      final sampleRows =
          table.rows.length > 10 ? table.rows.sublist(0, 10) : table.rows;
      final mappingResult = autoMapFieldsWithConfidence(
        table.headers,
        sampleRows: sampleRows,
      );
      final parsedRows = _parseAndDedupe(
        table,
        mappingResult.mapping,
        deletedRowIndices: const {},
      );

      // High confidence AND most sample rows parsed → skip mapping step.
      // Without the sampleValidRate check, confident header matches on
      // bad data would skip mapping and show garbage in the preview.
      final sampleValid = mappingResult.sampleValidRate ?? 0.0;
      final autoSkip = mappingResult.confidence == MappingConfidence.high &&
          sampleValid >= 0.7;
      final nextStep = autoSkip ? ImportStep.preview : ImportStep.mapColumns;

      state = state.copyWith(
        isParsing: false,
        clearParsingStatusMessage: true,
        fileName: file.name,
        table: table,
        mapping: mappingResult.mapping,
        mappingResult: mappingResult,
        parsedRows: parsedRows,
        step: nextStep,
        didAutoSkipMapping: autoSkip,
        availableSheets: availableSheets,
        selectedSheetIndex: selectedSheetIndex,
        clearDeletedRowIndices: true,
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
    if (error is _ImportBackendException) {
      final code = error.code?.toUpperCase();
      if (code == 'UNAUTHORIZED' ||
          error.status == 401 ||
          error.status == 403) {
        return 'Your session has expired. Please sign in again and retry the import.';
      }
      if (code == 'FILE_TOO_LARGE' || error.status == 413) {
        return 'File is too large to import. Please reduce the file size and try again.';
      }
      if (code == 'PDF_PAGE_LIMIT') {
        return 'This PDF is too long for one pass. Please split it into smaller files (1-5 pages each) and import again.';
      }
      if (code == 'PDF_TEXT_EXTRACTION_EMPTY' ||
          code == 'PDF_PARSE_FAILED' ||
          code == 'NO_TRANSACTIONS_FOUND' ||
          code == 'VALIDATION_ERROR') {
        return 'We could not extract transactions from this file. For PDF imports, use a digital statement or a clearer scan.';
      }
      if (code == 'SERVER_ERROR') {
        return 'Import service is temporarily unavailable. Please try again shortly.';
      }
      return error.message;
    }

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
            if (event.data is Map<String, dynamic>) {
              final data = event.data as Map<String, dynamic>;
              throw _ImportBackendException(
                data['error']?.toString() ?? 'Failed to analyze PDF',
                code: data['code']?.toString(),
                status: (data['status'] as num?)?.toInt(),
              );
            }
            throw _ImportBackendException(event.data.toString());
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
      throw _ImportBackendException(
        responseData['error']?.toString() ?? 'Failed to analyze PDF',
        code: responseData['code']?.toString(),
        status: (responseData['status'] as num?)?.toInt(),
      );
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

  /// Navigate back to the map-columns step. Used when the mapping step was
  /// auto-skipped and the user wants to review/adjust column assignments.
  void goBackToMapColumns() {
    state = state.copyWith(
      step: ImportStep.mapColumns,
      didAutoSkipMapping: false,
    );
  }

  void updateMapping(ImportField field, int? columnIndex) {
    final current = state.mapping;
    final table = state.table;
    if (current == null || table == null) return;

    final newMapping = current.copyWithField(field, columnIndex);
    final parsedRows = _parseAndDedupe(table, newMapping);
    state = state.copyWith(mapping: newMapping, parsedRows: parsedRows);
  }

  void toggleSplitDebitCredit(bool value) {
    final current = state.mapping;
    final table = state.table;
    if (current == null || table == null) return;

    final newMapping = current.copyWithSplitDebitCredit(value);
    final parsedRows = _parseAndDedupe(table, newMapping);
    state = state.copyWith(mapping: newMapping, parsedRows: parsedRows);
  }

  /// Switch to a different sheet in a multi-sheet Excel file.
  void selectSheet(int sheetIndex) {
    final sheets = state.availableSheets;
    if (sheetIndex < 0 || sheetIndex >= sheets.length) return;

    final table = sheets[sheetIndex].table;
    final sampleRows =
        table.rows.length > 10 ? table.rows.sublist(0, 10) : table.rows;
    final mappingResult = autoMapFieldsWithConfidence(
      table.headers,
      sampleRows: sampleRows,
    );
    final parsedRows = _parseAndDedupe(
      table,
      mappingResult.mapping,
      deletedRowIndices: const {},
    );

    state = state.copyWith(
      selectedSheetIndex: sheetIndex,
      table: table,
      mapping: mappingResult.mapping,
      mappingResult: mappingResult,
      parsedRows: parsedRows,
      clearDeletedRowIndices: true,
    );
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
    final pos = rows.indexWhere((r) => r.index == updated.index);
    if (pos < 0) return;
    rows[pos] = _validateRow(updated);
    final deduped = markDuplicates(
        rows, _existingExpensesForTarget(state.targetHouseholdId));
    state = state.copyWith(parsedRows: deduped);
  }

  void deleteParsedRow(int index) {
    final rows = [...state.parsedRows];
    if (!rows.any((r) => r.index == index)) return;
    final updatedRows = rows.where((r) => r.index != index).toList();
    final deduped = markDuplicates(
        updatedRows, _existingExpensesForTarget(state.targetHouseholdId));

    final deleted = {...state.deletedRowIndices, index};
    state = state.copyWith(parsedRows: deduped, deletedRowIndices: deleted);
  }

  Future<void> importRows() async {
    final table = state.table;
    final mapping = state.mapping;
    if (table == null || mapping == null) return;
    if (state.isImporting) return;

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

    // 1. Filter importable rows, counting invalid ones upfront.
    final importableRows = <ImportParsedRow>[];
    int preFilterFailed = 0;

    for (final row in state.parsedRows) {
      if (!row.isValid) {
        preFilterFailed += 1;
        continue;
      }
      if (state.skipDuplicates && row.isDuplicate) {
        continue;
      }
      importableRows.add(row);
    }

    if (importableRows.isEmpty) {
      state = state.copyWith(
        isImporting: false,
        importedCount: 0,
        failedCount: preFilterFailed,
        step: ImportStep.preview,
      );
      return;
    }

    // 2. Convert rows to transaction maps for the batch endpoint.
    final transactions = importableRows.map((row) {
      final currency = row.currency ?? defaultCurrency;
      final amount = (row.amountCents ?? 0) / 100.0;
      final dateOnly = DateFormat('yyyy-MM-dd').format(row.date!);
      final safeTimestamp =
          DateTime(row.date!.year, row.date!.month, row.date!.day, 12);

      return <String, dynamic>{
        'type': row.type ?? 'expense',
        'amount': amount,
        'category': row.category ?? 'uncategorized',
        'currency': currency,
        'date': dateOnly,
        'clientCreatedAt': safeTimestamp.toUtc().toIso8601String(),
        if (row.description != null) 'description': row.description,
      };
    }).toList(growable: false);

    // 3. Chunk into batches of ≤500 and call save-transactions-batch.
    int totalSucceeded = 0;
    int totalFailed = preFilterFailed;

    for (var offset = 0; offset < transactions.length; offset += _batchSize) {
      final end = (offset + _batchSize > transactions.length)
          ? transactions.length
          : offset + _batchSize;
      final chunk = transactions.sublist(offset, end);

      final body = <String, dynamic>{
        'userId': authUser.uid,
        'transactions': chunk,
        if (targetHouseholdId != null && targetHouseholdId.isNotEmpty)
          'householdId': targetHouseholdId,
        if (targetHouseholdId != null && targetHouseholdId.isNotEmpty)
          'isPortfolio': targetIsPortfolio,
      };

      try {
        final response = await supabase.functions.invoke(
          'save-transactions-batch',
          body: body,
        );

        final data = response.data;
        if (data is Map<String, dynamic>) {
          // Always read summary regardless of `success` flag — backend sets
          // success=false when ANY item fails, even if most succeeded.
          final summary = data['summary'];
          if (summary is Map<String, dynamic>) {
            totalSucceeded += (summary['succeeded'] as num?)?.toInt() ?? 0;
            totalFailed += (summary['failed'] as num?)?.toInt() ?? 0;
          } else if (data['success'] == true) {
            // Fallback: no summary but success — assume entire chunk succeeded.
            totalSucceeded += chunk.length;
          } else {
            totalFailed += chunk.length;
          }
        } else {
          totalFailed += chunk.length;
        }
      } catch (_) {
        totalFailed += chunk.length;
      }

      // Update progress after each batch for real-time UI feedback.
      state = state.copyWith(
        importedCount: totalSucceeded,
        failedCount: totalFailed,
      );
    }

    // 4. Refresh analytics after import.
    if (authUser.uid.isNotEmpty &&
        (targetHouseholdId == null || targetHouseholdId.isEmpty)) {
      await _ref.read(analyticsProvider.notifier).loadData(authUser.uid);
    }

    state = state.copyWith(
      isImporting: false,
      importedCount: totalSucceeded,
      failedCount: totalFailed,
      step: ImportStep.preview,
    );
  }

  List<ImportParsedRow> _parseAndDedupe(
      ImportTable table, ImportMapping mapping,
      {Set<int>? deletedRowIndices}) {
    final rows = <ImportParsedRow>[];
    for (var i = 0; i < table.rows.length; i++) {
      rows.add(parseRow(table.rows[i], mapping, index: i));
    }

    final effectiveDeletedRowIndices =
        deletedRowIndices ?? state.deletedRowIndices;

    final filteredRows = effectiveDeletedRowIndices.isEmpty
        ? rows
        : rows
            .where((row) => !effectiveDeletedRowIndices.contains(row.index))
            .toList(growable: false);

    return markDuplicates(
        filteredRows, _existingExpensesForTarget(state.targetHouseholdId));
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
    final issues = <RowIssue>[];
    if (row.date == null) {
      errors.add('invalid_date');
      issues.add(RowIssue.invalidDate);
    }
    if (row.amountCents == null) {
      errors.add('invalid_amount');
      issues.add(RowIssue.invalidAmount);
    }
    if (row.currency == null || row.currency!.trim().isEmpty) {
      issues.add(RowIssue.missingCurrency);
    }
    if (row.type == null || row.type!.trim().isEmpty) {
      issues.add(RowIssue.unknownType);
    }
    return row.copyWith(errors: errors, issues: issues);
  }
}

class _ImportBackendException implements Exception {
  const _ImportBackendException(
    this.message, {
    this.code,
    this.status,
  });

  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

/// Top-level function so [compute] can dispatch it to an isolate.
List<ImportSheetResult> _parseExcelSheetsSync(Uint8List bytes) {
  return parseImportExcelSheets(bytes);
}
