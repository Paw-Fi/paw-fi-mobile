import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'package:moneko/features/import/domain/import_models.dart';

ImportTable parseImportExcelTable(Uint8List bytes, {bool hasHeader = true}) {
  final excel = Excel.decodeBytes(bytes);

  Sheet? sheet;
  for (final name in excel.tables.keys) {
    sheet = excel.tables[name];
    if (sheet != null) break;
  }
  if (sheet == null) {
    return const ImportTable(headers: [], rows: []);
  }

  final rawRows = <List<String>>[];
  for (final row in sheet.rows) {
    rawRows.add(
      row
          .map((cell) => (cell?.value?.toString() ?? '').trim())
          .toList(growable: false),
    );
  }

  final rows = rawRows
      .where((row) => row.any((value) => value.trim().isNotEmpty))
      .toList(growable: false);
  if (rows.isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }

  if (hasHeader) {
    final headers = rows.first;
    final dataRows = rows.skip(1).toList(growable: false);
    return ImportTable(headers: headers, rows: dataRows);
  }

  final headers = List.generate(rows.first.length, (i) => 'Column ${i + 1}');
  return ImportTable(headers: headers, rows: rows);
}
