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
  final List<ImportParsedRow> parsedRows;
  final bool skipDuplicates;
  final bool isParsing;
  final bool isImporting;
  final String? errorMessage;
  final int importedCount;
  final int failedCount;

  const ImportWizardState({
    this.step = ImportStep.selectFile,
    this.fileName,
    this.table,
    this.mapping,
    this.parsedRows = const [],
    this.skipDuplicates = true,
    this.isParsing = false,
    this.isImporting = false,
    this.errorMessage,
    this.importedCount = 0,
    this.failedCount = 0,
  });

  ImportWizardState copyWith({
    ImportStep? step,
    String? fileName,
    ImportTable? table,
    ImportMapping? mapping,
    List<ImportParsedRow>? parsedRows,
    bool? skipDuplicates,
    bool? isParsing,
    bool? isImporting,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? importedCount,
    int? failedCount,
  }) {
    return ImportWizardState(
      step: step ?? this.step,
      fileName: fileName ?? this.fileName,
      table: table ?? this.table,
      mapping: mapping ?? this.mapping,
      parsedRows: parsedRows ?? this.parsedRows,
      skipDuplicates: skipDuplicates ?? this.skipDuplicates,
      isParsing: isParsing ?? this.isParsing,
      isImporting: isImporting ?? this.isImporting,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      importedCount: importedCount ?? this.importedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }

  int get totalRows => parsedRows.length;
  int get errorRows => parsedRows.where((row) => row.errors.isNotEmpty).length;
  int get duplicateRows => parsedRows.where((row) => row.isDuplicate).length;
  int get validRows => parsedRows.where((row) => row.isValid).length;
}
