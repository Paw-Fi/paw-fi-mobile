import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'package:moneko/features/import/domain/import_models.dart';

/// Parses all sheets from an Excel file and returns one [ImportSheetResult]
/// per sheet that contains at least one non-empty row.
List<ImportSheetResult> parseImportExcelSheets(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final results = <ImportSheetResult>[];

  for (final name in excel.tables.keys) {
    final sheet = excel.tables[name];
    if (sheet == null) continue;

    final table = _sheetToTable(sheet);
    if (table.headers.isEmpty && table.rows.isEmpty) continue;

    results.add(ImportSheetResult(sheetName: name, table: table));
  }

  return results;
}

/// Convenience: parse a single table from the first non-empty sheet.
/// Falls back to an empty table if no sheets are found.
ImportTable parseImportExcelTable(Uint8List bytes) {
  final sheets = parseImportExcelSheets(bytes);
  if (sheets.isEmpty) return const ImportTable(headers: [], rows: []);
  // Prefer a sheet with the most rows (most likely the data sheet).
  sheets.sort((a, b) => b.table.rows.length.compareTo(a.table.rows.length));
  return sheets.first.table;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

ImportTable _sheetToTable(Sheet sheet) {
  // Collect all non-completely-empty rows.
  final rawRows = <List<String>>[];
  for (final row in sheet.rows) {
    final cells =
        row.map((cell) => _cellToString(cell)).toList(growable: false);
    if (cells.any((v) => v.isNotEmpty)) {
      rawRows.add(cells);
    }
  }

  if (rawRows.isEmpty) return const ImportTable(headers: [], rows: []);

  // Detect the header row — skip leading metadata/title rows that don't look
  // like column headers (e.g. "Account: Checking", "Downloaded: 2024-01-01").
  final headerIndex = _detectHeaderRowIndex(rawRows);

  final headerRow = rawRows[headerIndex];
  final dataRows = rawRows
      .skip(headerIndex + 1)
      .where((row) => row.any((v) => v.isNotEmpty))
      .toList(growable: false);

  // Trim trailing empty columns using the header as the column count guide.
  final columnCount = _effectiveColumnCount(headerRow);
  final headers =
      headerRow.take(columnCount).map((h) => h.trim()).toList(growable: false);

  final trimmedRows = dataRows.map((row) {
    final padded = List<String>.filled(columnCount, '');
    for (var i = 0; i < columnCount && i < row.length; i++) {
      padded[i] = row[i];
    }
    return padded;
  }).toList(growable: false);

  return ImportTable(headers: headers, rows: trimmedRows);
}

String _cellToString(Data? cell) {
  if (cell == null) return '';
  final value = cell.value;
  if (value == null) return '';
  if (value is DateTimeCellValue) {
    // Return ISO date string for date cells so downstream parsers can handle.
    return value.asDateTimeLocal().toIso8601String();
  }
  return value.toString().trim();
}

/// Detect which row is actually the column-header row.
/// Skips leading rows that look like metadata (≤2 non-empty cells, or
/// contain known metadata keywords like "account", "downloaded", "period").
int _detectHeaderRowIndex(List<List<String>> rows) {
  const metadataKeywords = {
    'account',
    'downloaded',
    'period',
    'from',
    'to',
    'bank',
    'statement',
    'balance',
    'opening',
    'closing',
    'customer',
    'iban',
    'bic',
    'sort code',
    'account number',
  };

  for (var i = 0; i < rows.length && i < 10; i++) {
    final row = rows[i];
    final nonEmpty = row.where((v) => v.isNotEmpty).toList();
    if (nonEmpty.isEmpty) continue;

    // If the row has only 1–2 cells, it's likely a title/metadata row.
    if (nonEmpty.length <= 2) continue;

    // If every non-empty cell contains a metadata keyword → skip.
    final allMetadata = nonEmpty.every((cell) {
      final lower = cell.toLowerCase();
      return metadataKeywords.any((kw) => lower.contains(kw));
    });
    if (allMetadata) continue;

    return i;
  }
  // Default: first row.
  return 0;
}

/// Returns the number of columns we should keep — trailing empty header cells
/// are ignored.
int _effectiveColumnCount(List<String> headerRow) {
  var last = 0;
  for (var i = 0; i < headerRow.length; i++) {
    if (headerRow[i].trim().isNotEmpty) last = i + 1;
  }
  return last == 0 ? headerRow.length : last;
}
