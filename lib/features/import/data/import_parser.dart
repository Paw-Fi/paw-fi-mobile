import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/core/utils/money_parser.dart';

final RegExp _opaqueImportIdPattern = RegExp(
  r'^(?:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|[A-Z0-9_-]{10,})$',
  caseSensitive: false,
);

String? _normalizeUserFacingImportNote(String? value) {
  final trimmed = value == null ? null : sanitizeUtf16(value).trim();
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

String normalizeImportTextForMatching(String value) {
  return _normalizeImportNumberGlyphs(sanitizeUtf16(value))
      .toLowerCase()
      .trim();
}

String normalizeImportHeaderToken(String value) {
  return normalizeImportTextForMatching(value).replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
}

String _normalizeImportNumberGlyphs(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final digit = _unicodeDecimalDigitValue(rune);
    if (digit != null) {
      buffer.write(digit);
      continue;
    }

    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
      continue;
    }

    switch (rune) {
      case 0x2212: // minus sign
      case 0x2012: // figure dash
      case 0x2013: // en dash
      case 0x2014: // em dash
      case 0xFE63: // small hyphen-minus
        buffer.write('-');
        break;
      case 0xFE62: // small plus sign
        buffer.write('+');
        break;
      case 0x066B: // Arabic decimal separator
        buffer.write('.');
        break;
      case 0x066C: // Arabic thousands separator
      case 0x060C: // Arabic comma
      case 0x3001: // ideographic comma
        buffer.write(',');
        break;
      case 0x00A0:
      case 0x202F:
        buffer.write(' ');
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

int? _unicodeDecimalDigitValue(int rune) {
  const ranges = <int>[
    0x0030, // ASCII
    0x0660, // Arabic-Indic
    0x06F0, // Extended Arabic-Indic
    0x0966, // Devanagari
    0x09E6, // Bengali
    0x0A66, // Gurmukhi
    0x0AE6, // Gujarati
    0x0B66, // Oriya
    0x0BE6, // Tamil
    0x0C66, // Telugu
    0x0CE6, // Kannada
    0x0D66, // Malayalam
    0x0E50, // Thai
    0x0ED0, // Lao
    0x1040, // Myanmar
    0x17E0, // Khmer
    0x1810, // Mongolian
    0xFF10, // Fullwidth
  ];

  for (final start in ranges) {
    final value = rune - start;
    if (value >= 0 && value <= 9) return value;
  }
  return null;
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
  'merchant',
  'merchantname',
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

final Set<String> _knownImportHeaderTokensForMatching =
    _buildKnownImportHeaderTokensForMatching();

Set<String> _buildKnownImportHeaderTokensForMatching() {
  final tokens = <String>{
    for (final token in _knownImportHeaderTokens)
      normalizeImportHeaderToken(token),
  };

  void add(String value) {
    final normalized = normalizeImportHeaderToken(value);
    if (normalized.isNotEmpty) tokens.add(normalized);
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    add(l10n.date);
    add(l10n.amount);
    add(l10n.category);
    add(l10n.notes);
    add(l10n.description);
    add(l10n.currency);
    add(l10n.type);
    add(l10n.account);
    add(l10n.merchant);
    add(l10n.income);
    add(l10n.expense);
  }

  tokens.removeWhere((token) => token.isEmpty);
  return Set<String>.unmodifiable(tokens);
}

bool _looksLikeHeaderRow(List<String> row) {
  final nonEmpty =
      row.map((cell) => cell.trim()).where((cell) => cell.isNotEmpty).toList();
  if (nonEmpty.isEmpty) return false;

  final normalized = nonEmpty.map(normalizeImportHeaderToken).toList();
  final matchedHeaderCells = normalized.where((cell) {
    return _knownImportHeaderTokensForMatching.any(
      (token) => _headerTokenMatches(cell, token),
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

bool _headerTokenMatches(String cell, String token) {
  if (cell.isEmpty || token.isEmpty) return false;
  if (cell == token) return true;
  if (!_canUseHeaderSubstring(token)) return false;
  return cell.contains(token);
}

bool _canUseHeaderSubstring(String token) {
  final isAscii = RegExp(r'^[a-z0-9]+$').hasMatch(token);
  if (!isAscii) return token.runes.length >= 2;
  return token.length >= 4;
}

bool _looksLikeDataCellForHeaderDetection(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;

  if (parseDateValue(trimmed) != null) return true;
  if (parseAmountCents(trimmed) != null) return true;
  if (_normalizeCurrencyCode(trimmed) != null) return true;
  return resolveImportTypeValue(trimmed) != null;
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
  final merchantValue = valueFor(ImportField.merchant);
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

  if (parsedAmount == null || parsedAmount == 0) {
    errors.add('invalid_amount');
  }

  final finalDescription = _normalizeUserFacingImportNote(descriptionValue) ??
      _normalizeUserFacingImportNote(referenceValue);
  final finalMerchant = _normalizeUserFacingImportNote(merchantValue);
  final normalizedCategory = _resolveCategory(
    rawCategory: categoryValue,
    fallbackDescription: finalMerchant ?? finalDescription,
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
  if (!isBatchSaveCategorySafe(normalizedCategory)) {
    errors.add('invalid_category');
  }

  return ImportParsedRow(
    index: index,
    date: parsedDate,
    amountCents: parsedAmount?.abs(),
    category: normalizedCategory,
    description: finalDescription,
    merchant: finalMerchant,
    currency: normalizedCurrency,
    type: normalizedType,
    errors: errors,
    rawValues: row,
  );
}

bool isBatchSaveCategorySafe(String? value) {
  if (value == null) return false;
  final normalized = value
      .toString()
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  if (normalized.isEmpty) return false;
  if (normalized.length > 96) return false;
  if (normalized.contains('`')) return false;
  if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalized)) return false;
  return true;
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
    final trimmed = rawCategory.trim();
    return resolveBuiltinCategoryKeyAcrossLocales(trimmed) ?? trimmed;
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
  var trimmed = _normalizeImportNumberGlyphs(value.trim())
      .replaceAll(RegExp("[\"'＂＇]"), '')
      .trim();

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

  final yearFirst = _parseYearFirstNumericDate(stripped);
  if (yearFirst != null) return yearFirst;

  final localizedMonthDate = _parseLocalizedMonthDate(stripped);
  if (localizedMonthDate != null) return localizedMonthDate;

  // Try each date format, preferring an inferred slash-date order when we have
  // reliable evidence from the file (for example an "Expenses" export using
  // dd/MM/yyyy throughout).
  for (final format in _orderedDateFormats(orderHint)) {
    for (final locale in _dateParseLocales) {
      try {
        final parsed = locale == null
            ? DateFormat(format).parseStrict(stripped)
            : DateFormat(format, locale).parseStrict(stripped);
        return DateTime(
            _normalizeCalendarYear(parsed.year), parsed.month, parsed.day);
      } catch (_) {}
    }
  }
  return null;
}

final List<String?> _dateParseLocales = <String?>{
  null,
  'en_US',
  ...AppLocalizations.supportedLocales.expand((locale) sync* {
    final localeName = locale.toString();
    yield localeName;
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      yield locale.languageCode;
    }
  }),
}.toList(growable: false);

DateTime? _parseYearFirstNumericDate(String value) {
  final match = RegExp(
    r'^\s*(\d{4})\D+(\d{1,2})\D+(\d{1,2})(?:\D|$)',
  ).firstMatch(value);
  if (match == null) return null;

  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final day = int.tryParse(match.group(3) ?? '');
  if (year == null || month == null || day == null) return null;
  return _validDate(year, month, day);
}

DateTime? _validDate(int year, int month, int day) {
  year = _normalizeCalendarYear(year);
  if (year < 1000 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

int _normalizeCalendarYear(int year) {
  if (year >= 2400 && year <= 2800) return year - 543;
  return year;
}

DateTime? _parseLocalizedMonthDate(String value) {
  final dayMonthYear = RegExp(
    r'^\s*(\d{1,2})[\s./\-]+([^\d]+?)[\s,./\-]+(\d{2,4})(?:\D|$)',
    unicode: true,
  ).firstMatch(value);
  if (dayMonthYear != null) {
    final day = int.tryParse(dayMonthYear.group(1) ?? '');
    final month = _monthNumberFromLocalizedName(dayMonthYear.group(2));
    final year = int.tryParse(dayMonthYear.group(3) ?? '');
    if (day != null && month != null && year != null) {
      return _validDate(_expandTwoDigitYear(year), month, day);
    }
  }

  final monthDayYear = RegExp(
    r'^\s*([^\d]+?)[\s./\-]+(\d{1,2}),?[\s./\-]+(\d{2,4})(?:\D|$)',
    unicode: true,
  ).firstMatch(value);
  if (monthDayYear != null) {
    final month = _monthNumberFromLocalizedName(monthDayYear.group(1));
    final day = int.tryParse(monthDayYear.group(2) ?? '');
    final year = int.tryParse(monthDayYear.group(3) ?? '');
    if (month != null && day != null && year != null) {
      return _validDate(_expandTwoDigitYear(year), month, day);
    }
  }

  final vietnamese = RegExp(
    r'(?:ngày\s*)?(\d{1,2})\s*tháng\s*(\d{1,2})\s*(?:năm\s*)?(\d{2,4})',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(normalizeImportTextForMatching(value));
  if (vietnamese != null) {
    final day = int.tryParse(vietnamese.group(1) ?? '');
    final month = int.tryParse(vietnamese.group(2) ?? '');
    final year = int.tryParse(vietnamese.group(3) ?? '');
    if (day != null && month != null && year != null) {
      return _validDate(_expandTwoDigitYear(year), month, day);
    }
  }

  return null;
}

int _expandTwoDigitYear(int year) {
  if (year >= 100) return year;
  return year >= 70 ? 1900 + year : 2000 + year;
}

int? _monthNumberFromLocalizedName(String? rawValue) {
  if (rawValue == null) return null;
  final key = normalizeImportHeaderToken(rawValue);
  if (key.isEmpty) return null;
  return _localizedMonthLookup[key];
}

final Map<String, int> _localizedMonthLookup = _buildLocalizedMonthLookup();

Map<String, int> _buildLocalizedMonthLookup() {
  const aliases = <int, List<String>>{
    1: [
      'jan',
      'january',
      'januar',
      'enero',
      'janvier',
      'gennaio',
      'januari',
      'январь',
      'января',
      'янв',
      'січень',
      'січня',
      'січ',
      'جنوری',
      'มกราคม',
      'ม.ค.',
    ],
    2: [
      'feb',
      'february',
      'februar',
      'febrero',
      'février',
      'fevrier',
      'févr',
      'fevr',
      'febbraio',
      'februari',
      'февраль',
      'февраля',
      'фев',
      'лютий',
      'лютого',
      'лют',
      'فروری',
      'กุมภาพันธ์',
      'ก.พ.',
    ],
    3: [
      'mar',
      'march',
      'märz',
      'maerz',
      'marzo',
      'mars',
      'maart',
      'март',
      'марта',
      'мар',
      'березень',
      'березня',
      'бер',
      'مارچ',
      'มีนาคม',
      'มี.ค.',
    ],
    4: [
      'apr',
      'april',
      'abril',
      'avr',
      'avril',
      'aprile',
      'апрель',
      'апреля',
      'апр',
      'квітень',
      'квітня',
      'кві',
      'квіт',
      'اپریل',
      'เมษายน',
      'เม.ย.',
    ],
    5: [
      'may',
      'mai',
      'mayo',
      'maggio',
      'mag',
      'mei',
      'май',
      'мая',
      'травень',
      'травня',
      'тра',
      'трав',
      'مئی',
      'พฤษภาคม',
      'พ.ค.',
    ],
    6: [
      'jun',
      'june',
      'juni',
      'junio',
      'juin',
      'giugno',
      'giu',
      'июнь',
      'июня',
      'июн',
      'червень',
      'червня',
      'чер',
      'جون',
      'มิถุนายน',
      'มิ.ย.',
    ],
    7: [
      'jul',
      'july',
      'juli',
      'julio',
      'juil',
      'juillet',
      'luglio',
      'lug',
      'июль',
      'июля',
      'июл',
      'липень',
      'липня',
      'лип',
      'جولائی',
      'กรกฎาคม',
      'ก.ค.',
    ],
    8: [
      'aug',
      'august',
      'agosto',
      'août',
      'aout',
      'augustus',
      'август',
      'августа',
      'авг',
      'серпень',
      'серпня',
      'сер',
      'اگست',
      'สิงหาคม',
      'ส.ค.',
    ],
    9: [
      'sep',
      'sept',
      'september',
      'septiembre',
      'septembre',
      'settembre',
      'set',
      'сентябрь',
      'сентября',
      'сен',
      'сент',
      'вересень',
      'вересня',
      'вер',
      'ستمبر',
      'กันยายน',
      'ก.ย.',
    ],
    10: [
      'oct',
      'october',
      'okt',
      'oktober',
      'octubre',
      'octobre',
      'ottobre',
      'ott',
      'октябрь',
      'октября',
      'окт',
      'жовтень',
      'жовтня',
      'жов',
      'اکتوبر',
      'ตุลาคม',
      'ต.ค.',
    ],
    11: [
      'nov',
      'november',
      'noviembre',
      'novembre',
      'ноябрь',
      'ноября',
      'ноя',
      'нояб',
      'листопад',
      'листопада',
      'лис',
      'лист',
      'نومبر',
      'พฤศจิกายน',
      'พ.ย.',
    ],
    12: [
      'dec',
      'december',
      'dez',
      'dezember',
      'diciembre',
      'dic',
      'déc',
      'décembre',
      'decembre',
      'dicembre',
      'декабрь',
      'декабря',
      'дек',
      'грудень',
      'грудня',
      'гру',
      'груд',
      'دسمبر',
      'ธันวาคม',
      'ธ.ค.',
    ],
  };

  final lookup = <String, int>{};
  for (final entry in aliases.entries) {
    for (final alias in entry.value) {
      final key = normalizeImportHeaderToken(alias);
      if (key.isNotEmpty) lookup[key] = entry.key;
    }
  }
  return Map<String, int>.unmodifiable(lookup);
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
  var cleaned = _normalizeImportNumberGlyphs(value.trim());

  // Strip surrounding quotes.
  cleaned = cleaned.replaceAll(RegExp("[\"'＂＇]"), '');
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
  cleaned = cleaned.replaceAll(RegExp(r'\p{Sc}', unicode: true), '').trim();
  cleaned = _stripIsoCurrencyCodeFromAmountText(cleaned);

  if (_containsNonCurrencyAmountText(cleaned)) return null;

  cleaned = _extractPotentialAmountNumberText(cleaned);

  // Detect leading minus after symbol stripping.
  if (cleaned.startsWith('-')) {
    negative = true;
    cleaned = cleaned.substring(1).trim();
  } else if (cleaned.startsWith('+')) {
    cleaned = cleaned.substring(1).trim();
  }

  if (cleaned.endsWith('-')) {
    negative = true;
    cleaned = cleaned.substring(0, cleaned.length - 1).trim();
  } else if (cleaned.endsWith('+')) {
    cleaned = cleaned.substring(0, cleaned.length - 1).trim();
  }

  if (cleaned.isEmpty) return null;

  // Determine number format: EU (1.234,56) vs US/standard (1,234.56).
  final parsed = _parseNumericString(cleaned);
  if (parsed == null) return null;

  final cents = (parsed * 100).round();
  return negative ? -cents : cents;
}

String _stripIsoCurrencyCodeFromAmountText(String value) {
  var result = value.trim();
  result = result
      .replaceFirst(
        RegExp(r'^[A-Z]{3}(?=\s|[+\-]?\d)', caseSensitive: false),
        '',
      )
      .trim();

  final trailing = RegExp(
    r'^(.*\d)\s*[A-Z]{3}$',
    caseSensitive: false,
  ).firstMatch(result);
  if (trailing != null) {
    result = (trailing.group(1) ?? '').trim();
  }

  return result;
}

bool _containsNonCurrencyAmountText(String value) {
  final lettersOnly = value.replaceAll(
    RegExp(r'[^\p{L}]', unicode: true),
    '',
  );
  if (lettersOnly.isEmpty) return false;
  if (extractCanonicalCurrencyCode(value) != null) return false;

  // Short letter clusters cover common currency markers that are not unique
  // ISO symbols, such as "kr", "Rp", "Rs", or regional abbreviated units.
  return normalizeImportHeaderToken(lettersOnly).runes.length > 3;
}

String _extractPotentialAmountNumberText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if ((rune >= 0x30 && rune <= 0x39) ||
        char == '.' ||
        char == ',' ||
        char == '+' ||
        char == '-' ||
        char == '(' ||
        char == ')' ||
        char == '\'' ||
        char == '’') {
      buffer.write(char);
    } else if (RegExp(r'\s').hasMatch(char)) {
      buffer.write(' ');
    }
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r'^[\s.,]+'), '')
      .replaceAll(RegExp(r'[\s.,]+$'), '')
      .trim();
}

/// Parses a numeric string that may use either:
///   - US format: thousands separator = comma, decimal = period  → "1,234.56"
///   - EU format: thousands separator = period, decimal = comma  → "1.234,56"
///   - Plain: no separators                                      → "1234.56"
double? _parseNumericString(String value) {
  final cents = tryParseMoneyToCents(value);
  return cents != null ? centsToAmount(cents) : null;
}

// ---------------------------------------------------------------------------
// Type resolution
// ---------------------------------------------------------------------------

final Set<String> _incomeTypeTokens = _buildImportTypeTokens(isIncome: true);
final Set<String> _expenseTypeTokens = _buildImportTypeTokens(isIncome: false);

Set<String> _buildImportTypeTokens({required bool isIncome}) {
  final tokens = <String>{
    if (isIncome) ...[
      'income',
      'credit',
      'inflow',
      'deposit',
      'dep',
      'cr',
      'c',
      'received',
      'refund',
      'salary',
      'payment received',
      'money in',
      'moneyin',
    ] else ...[
      'expense',
      'debit',
      'db',
      'd',
      'outflow',
      'withdrawal',
      'wd',
      'dr',
      'paid',
      'purchase',
      'payment sent',
      'transfer out',
      'money out',
      'moneyout',
    ],
  };

  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);
    tokens.add(isIncome ? l10n.income : l10n.expense);
    if (isIncome) {
      tokens.add(l10n.categoryIncome);
      tokens.add(l10n.categoryRefunds);
    }
  }

  final normalized = tokens
      .map(_normalizeImportDirectionToken)
      .where((token) => token.isNotEmpty)
      .toSet();
  return Set<String>.unmodifiable(normalized);
}

String? resolveImportTypeValue(String? rawType) {
  if (rawType == null || rawType.trim().isEmpty) return null;

  final normalized = _normalizeImportDirectionToken(rawType);
  if (normalized.isEmpty) return null;

  final compact = _compactImportDirectionToken(normalized);
  final matchesIncome =
      _matchesImportDirection(normalized, compact, _incomeTypeTokens);
  final matchesExpense =
      _matchesImportDirection(normalized, compact, _expenseTypeTokens);

  if (matchesIncome && !matchesExpense) return 'income';
  if (matchesExpense && !matchesIncome) return 'expense';

  final hasPlus = RegExp(r'(^|[^0-9])\+([^0-9]|$)').hasMatch(normalized);
  final hasMinus = RegExp(r'(^|[^0-9])-([^0-9]|$)').hasMatch(normalized);
  if (hasPlus && !hasMinus) return 'income';
  if (hasMinus && !hasPlus) return 'expense';

  return null;
}

String _normalizeImportDirectionToken(String value) {
  return normalizeImportTextForMatching(value)
      .replaceAll(RegExp(r'[\p{Z}\s]+', unicode: true), ' ')
      .trim();
}

String _compactImportDirectionToken(String value) {
  return value.replaceAll(
    RegExp(r'[^\p{L}\p{N}+\-]', unicode: true),
    '',
  );
}

bool _matchesImportDirection(
  String normalized,
  String compact,
  Set<String> candidates,
) {
  final words = normalized
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toSet();

  for (final candidate in candidates) {
    if (candidate.isEmpty) continue;

    final candidateCompact = _compactImportDirectionToken(candidate);
    if (normalized == candidate || compact == candidateCompact) return true;

    final isAsciiCandidate = RegExp(r'^[a-z0-9 ]+$').hasMatch(candidate);
    if (isAsciiCandidate) {
      if (candidate.contains(' ')) {
        if (normalized.contains(candidate) ||
            compact.contains(candidateCompact)) {
          return true;
        }
        continue;
      }

      if (candidate.length <= 2) {
        if (words.contains(candidate)) return true;
        continue;
      }

      if (words.contains(candidate) || compact.contains(candidateCompact)) {
        return true;
      }
      continue;
    }

    if (candidateCompact.runes.length >= 2 &&
        compact.contains(candidateCompact)) {
      return true;
    }
  }

  return false;
}

String _resolveType(String? rawType, int? amountCents) {
  final explicitType = resolveImportTypeValue(rawType);
  if (explicitType != null) return explicitType;

  // Fall back to sign of amount: negative = expense, positive = income.
  if (amountCents != null && amountCents > 0) return 'income';
  return 'expense';
}
