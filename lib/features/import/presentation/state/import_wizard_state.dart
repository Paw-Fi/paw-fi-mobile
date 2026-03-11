import 'package:moneko/features/import/domain/import_models.dart';

enum ImportStep {
  selectFile,
  mapColumns,
  preview,
}

class ImportWizardState {
  final ImportStep step;
  final String? fileName;
  final ImportTable? table;
  final ImportMapping? mapping;

  /// Full mapping result with confidence scores. Null before auto-mapping runs.
  final MappingResult? mappingResult;

  final List<ImportParsedRow> parsedRows;
  final bool skipDuplicates;
  final bool isParsing;
  final String? parsingStatusMessage;
  final bool isImporting;
  final String? errorMessage;
  final int importedCount;
  final int failedCount;
  final String? targetHouseholdId;
  final bool targetIsPortfolio;
  final Set<int> deletedRowIndices;

  /// True when the map step was auto-skipped due to high confidence.
  final bool didAutoSkipMapping;

  /// All sheets detected from an Excel file. Empty for CSV files.
  final List<ImportSheetResult> availableSheets;

  /// The index into [availableSheets] currently selected. -1 means no sheet.
  final int selectedSheetIndex;

  const ImportWizardState({
    this.step = ImportStep.selectFile,
    this.fileName,
    this.table,
    this.mapping,
    this.mappingResult,
    this.parsedRows = const [],
    this.skipDuplicates = true,
    this.isParsing = false,
    this.parsingStatusMessage,
    this.isImporting = false,
    this.errorMessage,
    this.importedCount = 0,
    this.failedCount = 0,
    this.targetHouseholdId,
    this.targetIsPortfolio = false,
    this.deletedRowIndices = const {},
    this.didAutoSkipMapping = false,
    this.availableSheets = const [],
    this.selectedSheetIndex = -1,
  });

  ImportWizardState copyWith({
    ImportStep? step,
    String? fileName,
    ImportTable? table,
    ImportMapping? mapping,
    MappingResult? mappingResult,
    bool clearMappingResult = false,
    List<ImportParsedRow>? parsedRows,
    bool? skipDuplicates,
    bool? isParsing,
    String? parsingStatusMessage,
    bool clearParsingStatusMessage = false,
    bool? isImporting,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? importedCount,
    int? failedCount,
    String? targetHouseholdId,
    bool? targetIsPortfolio,
    Set<int>? deletedRowIndices,
    bool clearTargetHouseholdId = false,
    bool clearDeletedRowIndices = false,
    bool? didAutoSkipMapping,
    List<ImportSheetResult>? availableSheets,
    int? selectedSheetIndex,
  }) {
    return ImportWizardState(
      step: step ?? this.step,
      fileName: fileName ?? this.fileName,
      table: table ?? this.table,
      mapping: mapping ?? this.mapping,
      mappingResult:
          clearMappingResult ? null : (mappingResult ?? this.mappingResult),
      parsedRows: parsedRows ?? this.parsedRows,
      skipDuplicates: skipDuplicates ?? this.skipDuplicates,
      isParsing: isParsing ?? this.isParsing,
      parsingStatusMessage: clearParsingStatusMessage
          ? null
          : (parsingStatusMessage ?? this.parsingStatusMessage),
      isImporting: isImporting ?? this.isImporting,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      importedCount: importedCount ?? this.importedCount,
      failedCount: failedCount ?? this.failedCount,
      targetHouseholdId: clearTargetHouseholdId
          ? null
          : (targetHouseholdId ?? this.targetHouseholdId),
      targetIsPortfolio: targetIsPortfolio ?? this.targetIsPortfolio,
      deletedRowIndices: clearDeletedRowIndices
          ? const {}
          : (deletedRowIndices ?? this.deletedRowIndices),
      didAutoSkipMapping: didAutoSkipMapping ?? this.didAutoSkipMapping,
      availableSheets: availableSheets ?? this.availableSheets,
      selectedSheetIndex: selectedSheetIndex ?? this.selectedSheetIndex,
    );
  }

  bool get hasMultipleSheets => availableSheets.length > 1;

  int get totalRows => parsedRows.length;
  int get errorRows => parsedRows.where((row) => row.errors.isNotEmpty).length;
  int get duplicateRows => parsedRows.where((row) => row.isDuplicate).length;
  int get validRows => parsedRows.where((row) => row.isValid).length;
}
