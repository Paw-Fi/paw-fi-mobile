import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/utils/currency.dart';

final RegExp _opaqueImportIdPattern = RegExp(
  r'^(?:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|[A-Z0-9_-]{10,})$',
  caseSensitive: false,
);

String? _normalizeUserFacingImportNote(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
    return null;
  }
  if (_opaqueImportIdPattern.hasMatch(trimmed) && !trimmed.contains(' ')) {
    return null;
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(trimmed) &&
      RegExp(r'\d{6,}').hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

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
  final sanitized = _normalizeImportCsvContent(content);
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
  final headerLikely = hasHeader &&
      usableRows.isNotEmpty &&
      _looksLikeHeaderRow(usableRows.first);
  if (headerLikely) {
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

String _normalizeImportCsvContent(String content) {
  final normalized = content
      .replaceAll('\uFEFF', '')
      .replaceAll('\x00', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  final buffer = StringBuffer();
  final pendingWhitespace = StringBuffer();
  var inQuotes = false;

  void flushPendingWhitespace() {
    if (pendingWhitespace.isEmpty) return;
    buffer.write(pendingWhitespace.toString());
    pendingWhitespace.clear();
  }

  for (var i = 0; i < normalized.length; i++) {
    final char = normalized[i];

    if (char == '"') {
      if (inQuotes && i + 1 < normalized.length && normalized[i + 1] == '"') {
        flushPendingWhitespace();
        buffer.write('""');
        i += 1;
        continue;
      }

      flushPendingWhitespace();
      inQuotes = !inQuotes;
      buffer.write(char);
      continue;
    }

    if (!inQuotes && (char == ' ' || char == '\t')) {
      pendingWhitespace.write(char);
      continue;
    }

    if (!inQuotes &&
        (char == ',' || char == ';' || char == '|' || char == '\n')) {
      pendingWhitespace.clear();
      buffer.write(char);
      continue;
    }

    flushPendingWhitespace();
    buffer.write(char);
  }

  flushPendingWhitespace();
  return buffer.toString().trim();
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

const Set<String> _knownImportHeaderTokens = {
  'item',
  'date',
  'time',
  'datetime',
  'timestamp',
  'description',
  'details',
  'memo',
  'note',
  'notes',
  'amount',
  'expenses',
  'expense',
  'income',
  'debit',
  'credit',
  'category',
  'currency',
  'type',
  'balance',
  'reference',
  'payee',
  'gross',
  'fee',
  'net',
};

bool _looksLikeHeaderRow(List<String> row) {
  final nonEmpty =
      row.map((cell) => cell.trim()).where((cell) => cell.isNotEmpty).toList();
  if (nonEmpty.isEmpty) return false;

  final normalized = nonEmpty
      .map((cell) => cell.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .toList();
  final matchedHeaderCells = normalized.where((cell) {
    return _knownImportHeaderTokens.any(
      (token) => cell == token || (token.length >= 5 && cell.contains(token)),
    );
  }).length;
  if (matchedHeaderCells > 0) return true;

  final dataLikeCells =
      nonEmpty.where(_looksLikeDataCellForHeaderDetection).length;
  if (dataLikeCells >= (nonEmpty.length / 2).ceil()) {
    return false;
  }

  final shortTextCells = nonEmpty.where((cell) {
    return RegExp(r'[A-Za-z]').hasMatch(cell) &&
        !RegExp(r'\d').hasMatch(cell) &&
        cell.split(RegExp(r'\s+')).length <= 3;
  }).length;
  return shortTextCells >= (nonEmpty.length / 2).ceil();
}

bool _looksLikeDataCellForHeaderDetection(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;

  if (parseDateValue(trimmed) != null) return true;
  if (parseAmountCents(trimmed) != null) return true;
  if (_normalizeCurrencyCode(trimmed) != null) return true;

  const typeTokens = {
    'income',
    'expense',
    'debit',
    'credit',
    'dr',
    'cr',
    'inflow',
    'outflow',
    'deposit',
    'withdrawal',
    'received',
    'paid',
  };
  return typeTokens.contains(trimmed.toLowerCase());
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

enum ImportDateOrderHint {
  auto,
  monthDayYear,
  dayMonthYear,
}

ImportParsedRow parseRow(
  List<String> row,
  ImportMapping mapping, {
  int index = 0,
  ImportDateOrderHint dateOrderHint = ImportDateOrderHint.auto,
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
  final balanceValue = valueFor(ImportField.balance);
  final amountValue = valueFor(ImportField.amount);
  final debitValue = valueFor(ImportField.debit);
  final creditValue = valueFor(ImportField.credit);

  final parsedDate = parseDateValue(
    dateValue,
    orderHint: dateOrderHint,
  );
  if (parsedDate == null) {
    errors.add('invalid_date');
  }

  // Amount resolution: support both single-column and split debit/credit.
  int? parsedAmount;
  if (mapping.hasSplitDebitCredit) {
    parsedAmount = _resolveDebitCreditAmount(debitValue, creditValue);
  } else if (amountValue != null && amountValue.isNotEmpty) {
    parsedAmount = parseAmountCents(amountValue);
  } else if ((debitValue?.isNotEmpty ?? false) ||
      (creditValue?.isNotEmpty ?? false)) {
    parsedAmount = _resolveSingleDirectionalAmount(
      debit: debitValue,
      credit: creditValue,
    );
  } else {
    parsedAmount = null;
  }

  if (parsedAmount == null) {
    errors.add('invalid_amount');
  }

  final finalDescription = _normalizeUserFacingImportNote(descriptionValue) ??
      _normalizeUserFacingImportNote(referenceValue);
  final normalizedCategory = _resolveCategory(
    rawCategory: categoryValue,
    fallbackDescription: finalDescription,
    resolvedType: _resolveType(typeValue, parsedAmount),
  );
  final normalizedCurrency = _normalizeCurrencyCode(currencyValue) ??
      _inferCurrencyCodeFromCandidates([
        amountValue,
        debitValue,
        creditValue,
        balanceValue,
      ]);
  final normalizedType = _resolveType(typeValue, parsedAmount);

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

String? _normalizeCurrencyCode(String? value) {
  if (value == null) return null;
  final trimmed = value.trim().replaceAll(RegExp("[\"']"), '');
  if (trimmed.isEmpty) return null;
  return extractCanonicalCurrencyCode(trimmed);
}

String? _inferCurrencyCodeFromCandidates(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final normalized = _normalizeCurrencyCode(candidate);
    if (normalized != null) return normalized;
  }
  return null;
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

int? _resolveSingleDirectionalAmount({
  String? debit,
  String? credit,
}) {
  final debitCents =
      debit != null && debit.isNotEmpty ? parseAmountCents(debit) : null;
  final creditCents =
      credit != null && credit.isNotEmpty ? parseAmountCents(credit) : null;

  if (debitCents == null && creditCents == null) return null;
  if (debitCents != null && debitCents != 0) {
    return -debitCents.abs();
  }
  if (creditCents != null && creditCents != 0) {
    return creditCents.abs();
  }
  return 0;
}

String _resolveCategory({
  required String? rawCategory,
  required String? fallbackDescription,
  required String resolvedType,
}) {
  if (rawCategory != null && rawCategory.trim().isNotEmpty) {
    return rawCategory.trim();
  }

  final inferred = _inferCategoryFromDescription(
    fallbackDescription,
    type: resolvedType,
  );
  return inferred ?? 'uncategorized';
}

String? _inferCategoryFromDescription(
  String? description, {
  required String type,
}) {
  if (type == 'income') return null;

  final normalized = description?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;

  const vendorCategoryMap = <String, String>{
    'twilio': 'software tools',
    'resend': 'software tools',
    'windsurf': 'software tools',
    'github': 'software tools',
    'gitlab': 'software tools',
    'vercel': 'software tools',
    'netlify': 'software tools',
    'cloudflare': 'software tools',
    'digitalocean': 'software tools',
    'notion': 'software tools',
    'slack': 'software tools',
    'zoom': 'software tools',
    'figma': 'software tools',
    'openai': 'software tools',
    'anthropic': 'software tools',
    'chatgpt': 'software tools',
    'claude': 'software tools',
    'cursor': 'software tools',
    'apple developer': 'licensing & fees',
    'developer program': 'licensing & fees',
  };

  for (final entry in vendorCategoryMap.entries) {
    if (normalized.contains(entry.key)) {
      return entry.value;
    }
  }

  if (RegExp(
    r'\b(software|saas|subscription|developer|license|licensing)\b',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return normalized.contains('license') || normalized.contains('licensing')
        ? 'licensing & fees'
        : 'software tools';
  }

  return null;
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
  'MM/dd/yyyy h:mm a',
  'dd/MM/yyyy HH:mm:ss',
  'dd/MM/yyyy h:mm a',
  'dd.MM.yyyy HH:mm:ss',
  'dd.MM.yyyy h:mm a',
  'MMM dd, yyyy h:mm a',
  'MMM d, yyyy h:mm a',
  'MMMM dd, yyyy h:mm a',
  'MMMM d, yyyy h:mm a',
  'dd MMM yyyy h:mm a',
  'd MMM yyyy h:mm a',
  'dd MMMM yyyy h:mm a',
  'd MMMM yyyy h:mm a',
  'MMM dd, yyyy HH:mm',
  'MMM d, yyyy HH:mm',
  'MMMM dd, yyyy HH:mm',
  'MMMM d, yyyy HH:mm',
];

DateTime? parseDateValue(
  String? value, {
  ImportDateOrderHint orderHint = ImportDateOrderHint.auto,
}) {
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

  // Try each date format, preferring an inferred slash-date order when we have
  // reliable evidence from the file (for example an "Expenses" export using
  // dd/MM/yyyy throughout).
  for (final format in _orderedDateFormats(orderHint)) {
    for (final locale in [null, 'en_US']) {
      try {
        final parsed = locale == null
            ? DateFormat(format).parseStrict(stripped)
            : DateFormat(format, locale).parseStrict(stripped);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {}
    }
  }
  return null;
}

List<String> _orderedDateFormats(ImportDateOrderHint orderHint) {
  if (orderHint == ImportDateOrderHint.auto) {
    return _kDateFormats;
  }

  const monthDayFormats = <String>{
    'MM/dd/yyyy',
    'M/d/yyyy',
    'MM/dd/yy',
    'M/d/yy',
    'MM-dd-yyyy',
    'MM-dd-yy',
    'MM/dd/yyyy HH:mm:ss',
    'MM/dd/yyyy h:mm a',
  };
  const dayMonthFormats = <String>{
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
    'dd/MM/yyyy HH:mm:ss',
    'dd/MM/yyyy h:mm a',
    'dd.MM.yyyy HH:mm:ss',
    'dd.MM.yyyy h:mm a',
  };

  final preferred = orderHint == ImportDateOrderHint.dayMonthYear
      ? dayMonthFormats
      : monthDayFormats;
  final secondary = orderHint == ImportDateOrderHint.dayMonthYear
      ? monthDayFormats
      : dayMonthFormats;

  final ordered = <String>[];
  for (final format in _kDateFormats) {
    if (preferred.contains(format)) {
      ordered.add(format);
    }
  }
  for (final format in _kDateFormats) {
    if (!preferred.contains(format) && !secondary.contains(format)) {
      ordered.add(format);
    }
  }
  for (final format in _kDateFormats) {
    if (secondary.contains(format)) {
      ordered.add(format);
    }
  }
  return ordered;
}

ImportDateOrderHint inferDateOrderHint(
  List<List<String>> rows,
  int? dateColumnIndex,
) {
  if (dateColumnIndex == null || dateColumnIndex < 0) {
    return ImportDateOrderHint.auto;
  }

  var dayFirstSignals = 0;
  var monthFirstSignals = 0;

  final slashDatePattern = RegExp(
    r'^\s*(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})',
  );

  for (final row in rows) {
    if (dateColumnIndex >= row.length) continue;
    final match = slashDatePattern.firstMatch(row[dateColumnIndex].trim());
    if (match == null) continue;

    final first = int.tryParse(match.group(1) ?? '');
    final second = int.tryParse(match.group(2) ?? '');
    if (first == null || second == null) continue;

    if (first > 12 && second <= 12) {
      dayFirstSignals++;
    } else if (second > 12 && first <= 12) {
      monthFirstSignals++;
    }
  }

  if (dayFirstSignals > 0 && monthFirstSignals == 0) {
    return ImportDateOrderHint.dayMonthYear;
  }
  if (monthFirstSignals > 0 && dayFirstSignals == 0) {
    return ImportDateOrderHint.monthDayYear;
  }
  return ImportDateOrderHint.auto;
}

// ---------------------------------------------------------------------------
// Amount parsing
// ---------------------------------------------------------------------------

int? parseAmountCents(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var cleaned = value.trim();

  // Strip surrounding quotes.
  cleaned = cleaned.replaceAll(RegExp("[\"']"), '');
  cleaned = cleaned.replaceAll(RegExp(r'[−–—]'), '-');

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
      .replaceAll(RegExp(r'^[A-Z]{3}\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*[A-Z]{3}$', caseSensitive: false), '')
      .trim();

  // Detect leading minus after symbol stripping.
  if (cleaned.startsWith('-')) {
    negative = true;
    cleaned = cleaned.substring(1).trim();
  } else if (cleaned.startsWith('+')) {
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

  final normalizedGrouping = value.replaceAll(
    RegExp(r"(?<=\d)[\s\u00A0\u202F'’](?=\d)"),
    '',
  );
  value = normalizedGrouping;

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
