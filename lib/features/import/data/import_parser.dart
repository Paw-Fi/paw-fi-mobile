import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:moneko/features/import/domain/import_models.dart';

String detectDelimiter(String line) {
  final candidates = [',', ';', '\t', '|'];
  String selected = ',';
  int bestCount = 0;
  for (final candidate in candidates) {
    final count = _countOccurrences(line, candidate);
    if (count > bestCount) {
      bestCount = count;
      selected = candidate;
    }
  }
  return selected;
}

ImportTable parseImportTable(String content, {bool hasHeader = true}) {
  final sanitized = content.replaceAll('\r\n', '\n').trim();
  if (sanitized.isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }

  final firstLine = sanitized.split('\n').first;
  final delimiter = detectDelimiter(firstLine);
  final converter = CsvToListConverter(
    fieldDelimiter: delimiter,
    eol: '\n',
    shouldParseNumbers: false,
  );

  final rawRows = converter.convert(sanitized);
  final rows = rawRows
      .where((row) =>
          row.any((value) => (value?.toString() ?? '').trim().isNotEmpty))
      .map((row) => row.map((value) => value?.toString() ?? '').toList())
      .toList();

  if (rows.isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }

  List<String> headers;
  List<List<String>> dataRows;
  if (hasHeader) {
    headers = rows.first;
    dataRows = rows.skip(1).toList();
  } else {
    headers = List.generate(rows.first.length, (i) => 'Column ${i + 1}');
    dataRows = rows;
  }

  return ImportTable(headers: headers, rows: dataRows);
}

ImportParsedRow parseRow(
  List<String> row,
  ImportMapping mapping, {
  int index = 0,
}) {
  final errors = <String>[];

  String? valueFor(ImportField field) {
    final columnIndex = mapping.fieldToColumnIndex[field];
    if (columnIndex == null || columnIndex < 0 || columnIndex >= row.length) {
      return null;
    }
    return row[columnIndex].trim();
  }

  final dateValue = valueFor(ImportField.date);
  final amountValue = valueFor(ImportField.amount);
  final categoryValue = valueFor(ImportField.category);
  final descriptionValue = valueFor(ImportField.description);
  final currencyValue = valueFor(ImportField.currency);
  final typeValue = valueFor(ImportField.type);

  final parsedDate = parseDateValue(dateValue);
  if (parsedDate == null) {
    errors.add('invalid_date');
  }

  final parsedAmount = parseAmountCents(amountValue);
  if (parsedAmount == null) {
    errors.add('invalid_amount');
  }

  final normalizedCategory =
      categoryValue?.isNotEmpty == true ? categoryValue : 'uncategorized';
  final normalizedCurrency =
      currencyValue?.isNotEmpty == true ? currencyValue!.toUpperCase() : null;
  final normalizedType = _resolveType(
    typeValue,
    parsedAmount,
  );

  return ImportParsedRow(
    index: index,
    date: parsedDate,
    amountCents: parsedAmount?.abs(),
    category: normalizedCategory,
    description: descriptionValue?.isNotEmpty == true ? descriptionValue : null,
    currency: normalizedCurrency,
    type: normalizedType,
    errors: errors,
    rawValues: row,
  );
}

int _countOccurrences(String value, String needle) {
  if (needle.isEmpty) return 0;
  int count = 0;
  int index = 0;
  while (true) {
    final found = value.indexOf(needle, index);
    if (found == -1) return count;
    count++;
    index = found + needle.length;
  }
}

DateTime? parseDateValue(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  final formats = [
    'MM/dd/yyyy',
    'M/d/yyyy',
    'dd/MM/yyyy',
    'd/M/yyyy',
    'yyyy/MM/dd',
    'MM-dd-yyyy',
    'dd-MM-yyyy',
  ];
  for (final format in formats) {
    try {
      final parsed = DateFormat(format).parseStrict(trimmed);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {}
  }
  return null;
}

int? parseAmountCents(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var cleaned = value.trim();
  var negative = false;

  if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
    negative = true;
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }

  cleaned = cleaned.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.startsWith('-')) {
    negative = true;
    cleaned = cleaned.substring(1);
  }

  final parsed = double.tryParse(cleaned);
  if (parsed == null) return null;
  final cents = (parsed * 100).round();
  return negative ? -cents : cents;
}

String _resolveType(String? rawType, int? amountCents) {
  if (rawType != null && rawType.trim().isNotEmpty) {
    final normalized = rawType.trim().toLowerCase();
    if (['income', 'credit', 'inflow'].contains(normalized)) return 'income';
    if (['expense', 'debit', 'outflow'].contains(normalized)) return 'expense';
  }

  if (amountCents != null && amountCents < 0) {
    return 'expense';
  }
  return 'expense';
}
