import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:moneko/features/import/domain/import_models.dart';

// ---------------------------------------------------------------------------
// Encoding detection & text decoding
// ---------------------------------------------------------------------------

String decodeImportTextFromBytes(Uint8List bytes) {
  if (bytes.isEmpty) return '';

  bool hasPrefix(List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  // UTF-8 BOM
  if (hasPrefix(const [0xEF, 0xBB, 0xBF])) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }

  String decodeUtf16({required bool littleEndian, int offset = 0}) {
    final codeUnits = <int>[];
    for (var i = offset; i + 1 < bytes.length; i += 2) {
      final first = bytes[i];
      final second = bytes[i + 1];
      final value =
          littleEndian ? (first | (second << 8)) : ((first << 8) | second);
      codeUnits.add(value);
    }
    return String.fromCharCodes(codeUnits);
  }

  // UTF-16 LE BOM
  if (hasPrefix(const [0xFF, 0xFE])) {
    return decodeUtf16(littleEndian: true, offset: 2);
  }

  // UTF-16 BE BOM
  if (hasPrefix(const [0xFE, 0xFF])) {
    return decodeUtf16(littleEndian: false, offset: 2);
  }

  // Try UTF-8 first, fall back to latin1.
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

// ---------------------------------------------------------------------------
// Delimiter detection
// ---------------------------------------------------------------------------

/// Detect the most likely field delimiter by counting occurrences *outside
/// of quoted regions* so that quoted commas in semicolon-delimited files
/// don't skew the count.
String detectDelimiter(String text) {
  // Sample up to the first 4 non-empty lines for better confidence.
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .take(4)
      .toList();

  final candidates = [',', ';', '\t', '|'];
  final scores = <String, int>{for (final c in candidates) c: 0};

  for (final line in lines) {
    for (final c in candidates) {
      scores[c] = (scores[c] ?? 0) + _countOutsideQuotes(line, c);
    }
  }

  // Tabs are unambiguous — prefer them slightly.
  if ((scores['\t'] ?? 0) > 0) {
    return '\t';
  }

  String best = ',';
  int bestScore = -1;
  for (final entry in scores.entries) {
    if (entry.value > bestScore) {
      bestScore = entry.value;
      best = entry.key;
    }
  }
  return best;
}

int _countOutsideQuotes(String line, String needle) {
  int count = 0;
  bool inQuote = false;
  final ch = needle.isNotEmpty ? needle[0] : '';
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuote = !inQuote;
    } else if (!inQuote && c == ch) {
      count++;
    }
  }
  return count;
}

// ---------------------------------------------------------------------------
// CSV table parsing
// ---------------------------------------------------------------------------

ImportTable parseImportTable(String content, {bool hasHeader = true}) {
  final sanitized =
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (sanitized.isEmpty) {
    return const ImportTable(headers: [], rows: []);
  }

  final delimiter = detectDelimiter(sanitized);
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
    return ImportTable(
        headers: const [], rows: const [], detectedDelimiter: delimiter);
  }

  // Skip leading rows that look like metadata (e.g., bank statement headers
  // that have only 1 non-empty cell when the rest of the file has many columns).
  final int expectedColumns = _detectHeaderRowIndex(rows);
  final usableRows =
      expectedColumns > 0 ? rows.skip(expectedColumns).toList() : rows;

  List<String> headers;
  List<List<String>> dataRows;
  if (hasHeader && usableRows.isNotEmpty) {
    headers = usableRows.first;
    dataRows = usableRows.skip(1).toList();
  } else {
    final colCount = usableRows.isNotEmpty ? usableRows.first.length : 0;
    headers = List.generate(colCount, (i) => 'Column ${i + 1}');
    dataRows = usableRows;
  }

  final formatHint = _detectFormatHint(headers);

  return ImportTable(
    headers: headers,
    rows: dataRows,
    detectedDelimiter: delimiter,
    formatHint: formatHint,
  );
}

/// Returns the index of the first "real" header row. Some bank exports prepend
/// 1–3 metadata rows before the actual column headers. We detect the row with
/// the most non-empty cells as the likely header.
int _detectHeaderRowIndex(List<List<String>> rows) {
  if (rows.length < 2) return 0;

  int bestIndex = 0;
  int bestCount = 0;
  for (var i = 0; i < rows.length.clamp(0, 6); i++) {
    final count = rows[i].where((c) => c.trim().isNotEmpty).length;
    if (count > bestCount) {
      bestCount = count;
      bestIndex = i;
    }
  }
  return bestIndex;
}

// ---------------------------------------------------------------------------
// Bank / app format detection
// ---------------------------------------------------------------------------

CsvFormatHint _detectFormatHint(List<String> headers) {
  final normalized = headers.map((h) => h.trim().toLowerCase()).toSet();

  // PayPal
  if (normalized.containsAll(['date', 'time', 'name', 'gross', 'fee', 'net'])) {
    return CsvFormatHint.paypal;
  }
  // Revolut
  if (normalized.any((h) => h.contains('started (utc)')) ||
      normalized.any((h) => h.contains('completed (utc)'))) {
    return CsvFormatHint.revolutEur;
  }
  // N26
  if (normalized.containsAll(
      ['date', 'payee', 'transaction type', 'payment reference'])) {
    return CsvFormatHint.n26;
  }
  // Wise / TransferWise
  if (normalized.any((h) => h.contains('transferwise')) ||
      normalized.any((h) => h.contains('transfer id'))) {
    return CsvFormatHint.wise;
  }
  // Chase
  if (normalized
      .containsAll(['date', 'description', 'amount', 'type', 'balance'])) {
    return CsvFormatHint.chase;
  }
  // Bank of America
  if (normalized.any((h) => h.contains('running bal'))) {
    return CsvFormatHint.bankOfAmerica;
  }
  // Wells Fargo — typically has no header row at all, but if it does:
  if (normalized.containsAll(['date', 'amount', 'asterisk', 'check number'])) {
    return CsvFormatHint.wellsFargo;
  }
  // Split debit/credit columns
  if ((normalized.contains('debit') ||
          normalized.contains('debit amount') ||
          normalized.contains('withdrawals')) &&
      (normalized.contains('credit') ||
          normalized.contains('credit amount') ||
          normalized.contains('deposits'))) {
    return CsvFormatHint.splitDebitCredit;
  }

  return CsvFormatHint.generic;
}

// ---------------------------------------------------------------------------
// Row parsing
// ---------------------------------------------------------------------------

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
  final categoryValue = valueFor(ImportField.category);
  final descriptionValue = valueFor(ImportField.description);
  final currencyValue = valueFor(ImportField.currency);
  final typeValue = valueFor(ImportField.type);
  final referenceValue = valueFor(ImportField.reference);

  final parsedDate = parseDateValue(dateValue);
  if (parsedDate == null) {
    errors.add('invalid_date');
  }

  // Amount resolution: support both single-column and split debit/credit.
  int? parsedAmount;
  if (mapping.hasSplitDebitCredit) {
    final debitValue = valueFor(ImportField.debit);
    final creditValue = valueFor(ImportField.credit);
    parsedAmount = _resolveDebitCreditAmount(debitValue, creditValue);
  } else {
    final amountValue = valueFor(ImportField.amount);
    parsedAmount = parseAmountCents(amountValue);
  }

  if (parsedAmount == null) {
    errors.add('invalid_amount');
  }

  final normalizedCategory =
      categoryValue?.isNotEmpty == true ? categoryValue : 'uncategorized';
  final normalizedCurrency =
      currencyValue?.isNotEmpty == true ? currencyValue!.toUpperCase() : null;
  final normalizedType = _resolveType(typeValue, parsedAmount);

  // Compose description: prefer explicit description, fall back to reference.
  String? finalDescription = descriptionValue?.isNotEmpty == true
      ? descriptionValue
      : referenceValue?.isNotEmpty == true
          ? referenceValue
          : null;

  return ImportParsedRow(
    index: index,
    date: parsedDate,
    amountCents: parsedAmount?.abs(),
    category: normalizedCategory,
    description: finalDescription,
    currency: normalizedCurrency,
    type: normalizedType,
    errors: errors,
    rawValues: row,
  );
}

/// Resolves a net amount from separate debit and credit columns.
/// Debit is treated as negative (expense), credit as positive (income).
/// Returns the net in cents, or null if both columns are empty.
int? _resolveDebitCreditAmount(String? debit, String? credit) {
  final debitCents =
      debit != null && debit.isNotEmpty ? parseAmountCents(debit) : null;
  final creditCents =
      credit != null && credit.isNotEmpty ? parseAmountCents(credit) : null;

  if (debitCents == null && creditCents == null) return null;

  final net = (creditCents?.abs() ?? 0) - (debitCents?.abs() ?? 0);
  return net;
}

// ---------------------------------------------------------------------------
// Date parsing
// ---------------------------------------------------------------------------

/// Supported date formats, ordered from most to least specific.
/// Adding formats here automatically makes them available everywhere.
final List<String> _kDateFormats = [
  // ISO 8601 variants
  'yyyy-MM-dd',
  'yyyy/MM/dd',
  'yyyy.MM.dd',
  // US formats
  'MM/dd/yyyy',
  'M/d/yyyy',
  'MM/dd/yy',
  'M/d/yy',
  'MM-dd-yyyy',
  'MM-dd-yy',
  // European formats (day first)
  'dd/MM/yyyy',
  'd/M/yyyy',
  'dd/MM/yy',
  'd/M/yy',
  'dd-MM-yyyy',
  'd-M-yyyy',
  'dd-MM-yy',
  'dd.MM.yyyy',
  'd.M.yyyy',
  'dd.MM.yy',
  // Named month formats
  'MMM dd, yyyy',
  'MMM d, yyyy',
  'MMMM dd, yyyy',
  'MMMM d, yyyy',
  'dd MMM yyyy',
  'd MMM yyyy',
  'dd MMMM yyyy',
  'd MMMM yyyy',
  // With time (strip time, keep date)
  "yyyy-MM-dd'T'HH:mm:ss",
  "yyyy-MM-dd HH:mm:ss",
  "yyyy-MM-dd HH:mm",
  'MM/dd/yyyy HH:mm:ss',
  'dd/MM/yyyy HH:mm:ss',
  'dd.MM.yyyy HH:mm:ss',
];

DateTime? parseDateValue(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  // Strip leading/trailing quotes that some exporters leave in.
  var trimmed = value.trim().replaceAll(RegExp("[\"']"), '');

  // Try DateTime.parse first (handles full ISO 8601 including timezone).
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  // Unix timestamp (seconds since epoch).
  final asInt = int.tryParse(trimmed);
  if (asInt != null && asInt > 315532800) {
    // After 1980-01-01
    final dt = DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true);
    return DateTime(dt.year, dt.month, dt.day);
  }

  // Strip trailing timezone abbreviations like "EST", "UTC", "+0100".
  final stripped = trimmed
      .replaceFirst(
        RegExp(r'\s+([A-Z]{2,5}|[+-]\d{2}:?\d{2})$'),
        '',
      )
      .trim();

  // Try each date format.
  for (final format in _kDateFormats) {
    try {
      final parsed = DateFormat(format).parseStrict(stripped);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {}
  }
  return null;
}

// ---------------------------------------------------------------------------
// Amount parsing
// ---------------------------------------------------------------------------

int? parseAmountCents(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var cleaned = value.trim();

  // Strip surrounding quotes.
  cleaned = cleaned.replaceAll(RegExp("[\"']"), '');

  // Accounting-style negatives: "(1,234.56)" or "(1.234,56)"
  var negative = false;
  if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
    negative = true;
    cleaned = cleaned.substring(1, cleaned.length - 1).trim();
  }

  // Strip any Unicode currency symbol (Sc category) — covers ALL currencies
  // without maintaining a fixed list. Also strip 3-letter ISO currency codes
  // (e.g. "USD", "EUR") that appear as leading/trailing text.
  cleaned = cleaned
      .replaceAll(RegExp(r'\p{Sc}', unicode: true), '')
      .replaceAll(RegExp(r'^[A-Z]{3}\s*', caseSensitive: true), '')
      .replaceAll(RegExp(r'\s*[A-Z]{3}$', caseSensitive: true), '')
      .trim();

  // Detect leading minus after symbol stripping.
  if (cleaned.startsWith('-')) {
    negative = true;
    cleaned = cleaned.substring(1).trim();
  }

  if (cleaned.isEmpty) return null;

  // Determine number format: EU (1.234,56) vs US/standard (1,234.56).
  final parsed = _parseNumericString(cleaned);
  if (parsed == null) return null;

  final cents = (parsed * 100).round();
  return negative ? -cents : cents;
}

/// Parses a numeric string that may use either:
///   - US format: thousands separator = comma, decimal = period  → "1,234.56"
///   - EU format: thousands separator = period, decimal = comma  → "1.234,56"
///   - Plain: no separators                                      → "1234.56"
double? _parseNumericString(String value) {
  if (value.isEmpty) return null;

  final hasDot = value.contains('.');
  final hasComma = value.contains(',');

  if (hasDot && hasComma) {
    // Both present — whichever appears last is the decimal separator.
    final lastDot = value.lastIndexOf('.');
    final lastComma = value.lastIndexOf(',');
    if (lastComma > lastDot) {
      // EU format: "1.234,56"
      final normalized = value.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    } else {
      // US format: "1,234.56"
      final normalized = value.replaceAll(',', '');
      return double.tryParse(normalized);
    }
  }

  if (hasComma && !hasDot) {
    // Only commas — could be EU decimal ("1234,56") or US thousands ("1,234").
    final parts = value.split(',');
    if (parts.length == 2 && parts.last.length <= 2) {
      // Looks like EU decimal: "1234,56" or "12,5"
      return double.tryParse(value.replaceAll(',', '.'));
    }
    // Otherwise treat commas as thousands separators.
    return double.tryParse(value.replaceAll(',', ''));
  }

  if (hasDot && !hasComma) {
    // Only dots — could be EU thousands ("1.234") or US decimal ("1234.56").
    final parts = value.split('.');
    if (parts.length == 2 &&
        parts.last.length == 3 &&
        parts.first.length <= 3) {
      // Ambiguous: "1.234" — treat as EU thousands, result is 1234.
      final asInt = int.tryParse(value.replaceAll('.', ''));
      if (asInt != null) return asInt.toDouble();
    }
    return double.tryParse(value);
  }

  return double.tryParse(value);
}

// ---------------------------------------------------------------------------
// Type resolution
// ---------------------------------------------------------------------------

String _resolveType(String? rawType, int? amountCents) {
  if (rawType != null && rawType.trim().isNotEmpty) {
    final normalized = rawType.trim().toLowerCase();
    const incomeKeywords = [
      'income',
      'credit',
      'inflow',
      'deposit',
      'cr',
      'received',
      'refund',
      'salary',
      'payment received',
    ];
    const expenseKeywords = [
      'expense',
      'debit',
      'outflow',
      'withdrawal',
      'dr',
      'paid',
      'purchase',
      'payment sent',
      'transfer out',
    ];
    if (incomeKeywords.any((kw) => normalized.contains(kw))) return 'income';
    if (expenseKeywords.any((kw) => normalized.contains(kw))) return 'expense';
  }

  // Fall back to sign of amount: negative = expense, positive = income.
  if (amountCents != null && amountCents > 0) return 'income';
  return 'expense';
}
