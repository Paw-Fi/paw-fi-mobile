import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';

// ---------------------------------------------------------------------------
// Auto-mapping: header → ImportField (with confidence scoring)
// ---------------------------------------------------------------------------

/// Backward-compatible entry point. Returns a plain [ImportMapping] using
/// header-only matching. Call [autoMapFieldsWithConfidence] for the full
/// scored result with value-aware mapping.
ImportMapping autoMapFields(List<String> headers) {
  final result = autoMapFieldsWithConfidence(headers);
  return result.mapping;
}

/// Value-aware auto-mapping that returns a [MappingResult] with per-field
/// confidence scores and an overall confidence level.
///
/// [headers] — the column headers from the parsed table.
/// [sampleRows] — optional sample data rows (first 5–10) used to validate
///   mappings by checking if values look like dates, amounts, currencies, etc.
MappingResult autoMapFieldsWithConfidence(
  List<String> headers, {
  List<List<String>> sampleRows = const [],
}) {
  final normalized = headers.map(_normalizeHeader).toList();
  final fieldScores = <ImportField, FieldMappingScore>{};
  final warnings = <String>[];

  // Track which column indices are already claimed and by which field.
  final columnClaims = <int, _ColumnClaim>{};

  // ── Score each field against every column ─────────────────────────────

  for (final entry in _synonyms.entries) {
    final field = entry.key;
    final candidates = entry.value;
    final best = _scoreBestColumn(
      field,
      candidates,
      normalized,
      headers,
      sampleRows,
    );
    fieldScores[field] = best;
  }

  // ── Collision resolution ──────────────────────────────────────────────
  // When two fields map to the same column, the higher score wins.

  final assignedFields = fieldScores.entries
      .where((e) => e.value.columnIndex != null)
      .toList()
    ..sort((a, b) => b.value.score.compareTo(a.value.score));

  for (final entry in assignedFields) {
    final colIdx = entry.value.columnIndex!;
    final existing = columnClaims[colIdx];
    if (existing != null) {
      // Collision: keep the one with the higher score.
      if (entry.value.score > existing.score.score) {
        // Evict the previous claimant.
        fieldScores[existing.field] = FieldMappingScore(
          field: existing.field,
          columnIndex: null,
          confidence: FieldConfidence.none,
          score: 0.0,
          reason: 'evicted by ${entry.key.name} (higher score)',
        );
        warnings.add(
          '${existing.field.name} and ${entry.key.name} both matched '
          'column ${colIdx + 1} "${headers[colIdx]}"; '
          'assigned to ${entry.key.name} (score ${entry.value.score.toStringAsFixed(2)} '
          'vs ${existing.score.score.toStringAsFixed(2)})',
        );
        columnClaims[colIdx] = _ColumnClaim(entry.key, entry.value);
      } else {
        // Current entry loses the collision.
        fieldScores[entry.key] = FieldMappingScore(
          field: entry.key,
          columnIndex: null,
          confidence: FieldConfidence.none,
          score: 0.0,
          reason: 'evicted by ${existing.field.name} (higher score)',
        );
        warnings.add(
          '${entry.key.name} and ${existing.field.name} both matched '
          'column ${colIdx + 1} "${headers[colIdx]}"; '
          'assigned to ${existing.field.name}',
        );
      }
    } else {
      columnClaims[colIdx] = _ColumnClaim(entry.key, entry.value);
    }
  }

  // ── Build final mapping from surviving claims ─────────────────────────

  final mapping = <ImportField, int>{};
  for (final entry in fieldScores.entries) {
    if (entry.value.columnIndex != null &&
        columnClaims[entry.value.columnIndex]?.field == entry.key) {
      mapping[entry.key] = entry.value.columnIndex!;
    }
  }

  // ── Detect split debit/credit mode ────────────────────────────────────

  final hasSplit = mapping.containsKey(ImportField.debit) &&
      mapping.containsKey(ImportField.credit);

  if (hasSplit) {
    mapping.remove(ImportField.amount);
  }

  // ── Compute overall confidence ────────────────────────────────────────

  final confidence = _computeOverallConfidence(
    fieldScores,
    mapping,
    hasSplit,
    sampleRows,
  );

  // ── Optionally validate mapping against sample rows ───────────────────

  double? sampleValidRate;
  if (sampleRows.isNotEmpty && mapping.isNotEmpty) {
    final testMapping = ImportMapping(
      fieldToColumnIndex: mapping,
      hasSplitDebitCredit: hasSplit,
      confidence: confidence,
    );
    int valid = 0;
    final samplesToTest =
        sampleRows.length > 10 ? sampleRows.sublist(0, 10) : sampleRows;
    for (final row in samplesToTest) {
      final parsed = parseRow(row, testMapping);
      if (parsed.isValid) valid++;
    }
    sampleValidRate =
        samplesToTest.isEmpty ? null : valid / samplesToTest.length;
  }

  return MappingResult(
    mapping: ImportMapping(
      fieldToColumnIndex: mapping,
      hasSplitDebitCredit: hasSplit,
      confidence: confidence,
    ),
    confidence: confidence,
    fieldScores: fieldScores,
    warnings: warnings,
    sampleValidRate: sampleValidRate,
  );
}

// ---------------------------------------------------------------------------
// Synonym tables
// ---------------------------------------------------------------------------

/// Normalized header synonyms for each target field.
///
/// IMPORTANT: 'type' was intentionally removed from category synonyms to
/// prevent collision with ImportField.type. The old mapping would greedily
/// assign a "Type" column to category, even when it contained transaction
/// direction values like "debit"/"credit".
const _synonyms = <ImportField, List<String>>{
  ImportField.date: [
    'date',
    'transactiondate',
    'txdate',
    'txndate',
    'posteddate',
    'postingdate',
    'settlementdate',
    'valuedate',
    'bookingdate',
    'bookdate',
    'statementdate',
    'completeddate',
    'datestarted',
    'datecompleted',
    'processingdate',
    'entrydate',
    'tradedate',
    'effectivedate',
    'time',
    'datetime',
    'timestamp',
  ],
  ImportField.amount: [
    'amount',
    'amt',
    'value',
    'total',
    'sum',
    'price',
    'transactionamount',
    'txamount',
    'txnamt',
    'netamount',
    'paymentamount',
    'chargeamount',
    'purchaseamount',
    'net',
    'gross',
  ],
  ImportField.debit: [
    'debit',
    'expense',
    'expenses',
    'debitamount',
    'withdrawal',
    'withdrawals',
    'debiteur',
    'charge',
    'out',
    'outflow',
    'paid',
    'dr',
    'moneyout',
  ],
  ImportField.credit: [
    'credit',
    'income',
    'incomes',
    'creditamount',
    'deposit',
    'deposits',
    'crediteur',
    'payment',
    'in',
    'inflow',
    'received',
    'cr',
    'moneyin',
  ],
  ImportField.balance: [
    'balance',
    'runningbal',
    'runningbalance',
    'closingbalance',
    'availablebalance',
    'ledgerbalance',
    'accountbalance',
  ],
  ImportField.category: [
    'category', 'cat', 'subcategory', 'transactioncategory',
    'merchantcategory', 'spendingcategory',
    // 'type' intentionally excluded — see comment above.
  ],
  ImportField.description: [
    'description',
    'memo',
    'note',
    'notes',
    'narrative',
    'merchant',
    'merchantname',
    'payee',
    'payeename',
    'name',
    'counterparty',
    'beneficiary',
    'vendor',
    'details',
    'particulars',
    'narration',
    'remarks',
    'information',
    'label',
    'title',
    'productname',
  ],
  ImportField.currency: [
    'currency', 'curr', 'ccy', 'currencycode',
    'transactioncurrency', 'accountcurrency',
    // Removed 'code' and 'iso' — too generic, causes false positives.
  ],
  ImportField.type: [
    'type',
    'transactiontype',
    'txtype',
    'txntype',
    'kind',
    'direction',
    'drcr',
    'creditdebit',
  ],
  ImportField.reference: [
    'reference',
    'ref',
    'refno',
    'referencenumber',
    'transactionid',
    'txid',
    'txnid',
    'id',
    'paymentreference',
    'checkno',
    'checknumber',
  ],
};

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _ColumnClaim {
  final ImportField field;
  final FieldMappingScore score;
  const _ColumnClaim(this.field, this.score);
}

/// Finds the best column for a given field, returning a [FieldMappingScore].
FieldMappingScore _scoreBestColumn(
  ImportField field,
  List<String> synonyms,
  List<String> normalizedHeaders,
  List<String> rawHeaders,
  List<List<String>> sampleRows,
) {
  int? bestCol;
  double bestScore = 0.0;
  FieldConfidence bestConfidence = FieldConfidence.none;
  String? bestReason;

  for (var i = 0; i < normalizedHeaders.length; i++) {
    final h = normalizedHeaders[i];
    double score = 0.0;
    FieldConfidence confidence = FieldConfidence.none;
    String? reason;

    // ── Header exact match ───────────────────────────────────────────
    if (synonyms.contains(h)) {
      score = 1.0;
      confidence = FieldConfidence.exact;
      reason = "exact header match: '${rawHeaders[i]}'";
    }
    // ── Header substring match ───────────────────────────────────────
    else if (synonyms.any((s) => h.contains(s))) {
      final matched = synonyms.firstWhere((s) => h.contains(s));
      score = 0.7;
      confidence = FieldConfidence.partial;
      reason = "substring match '$matched' in '${rawHeaders[i]}'";
    }

    // ── Value-based boost ────────────────────────────────────────────
    // Only apply if we have sample rows and no strong header match yet,
    // or to confirm a header match.
    if (sampleRows.isNotEmpty) {
      final valueScore = _scoreColumnValues(field, i, sampleRows);
      if (valueScore > 0.0) {
        if (score == 0.0) {
          // No header match: use value-based inference only.
          score = valueScore * 0.5; // cap at 0.5 for value-only.
          confidence = FieldConfidence.valueBased;
          reason =
              'inferred from values (${(valueScore * 100).toInt()}% match)';
        } else {
          // Header match exists: value signals boost confidence.
          score = score * 0.7 + valueScore * 0.3;
          reason = '${reason!} + values confirm';
        }
      }
    }

    if (score > bestScore) {
      bestScore = score;
      bestCol = i;
      bestConfidence = confidence;
      bestReason = reason;
    }
  }

  return FieldMappingScore(
    field: field,
    columnIndex: bestScore > 0.0 ? bestCol : null,
    confidence: bestConfidence,
    score: bestScore,
    reason: bestReason,
  );
}

/// Scores how well a column's sample values match the expected field type.
/// Returns 0.0 to 1.0 based on fraction of matching samples.
double _scoreColumnValues(
  ImportField field,
  int columnIndex,
  List<List<String>> sampleRows,
) {
  if (sampleRows.isEmpty) return 0.0;

  int matches = 0;
  int total = 0;

  final samplesToCheck =
      sampleRows.length > 8 ? sampleRows.sublist(0, 8) : sampleRows;

  for (final row in samplesToCheck) {
    if (columnIndex >= row.length) continue;
    final value = row[columnIndex].trim();
    if (value.isEmpty) continue;
    total++;

    switch (field) {
      case ImportField.date:
        if (_looksLikeDate(value)) matches++;
        break;
      case ImportField.amount:
      case ImportField.debit:
      case ImportField.credit:
      case ImportField.balance:
        if (_looksLikeAmount(value)) matches++;
        break;
      case ImportField.currency:
        if (_looksLikeCurrency(value)) matches++;
        break;
      case ImportField.type:
        if (_looksLikeType(value)) matches++;
        break;
      case ImportField.description:
      case ImportField.category:
      case ImportField.reference:
        // These are free-text; hard to validate from values alone.
        // Description columns tend to be longer strings.
        if (field == ImportField.description && value.length > 5) {
          matches++;
        }
        break;
    }
  }

  return total == 0 ? 0.0 : matches / total;
}

/// Quick heuristic: does this string look like a date?
bool _looksLikeDate(String value) {
  // Contains digit-separator-digit patterns typical of dates.
  if (RegExp(r'\d{1,4}[/\-\.]\d{1,2}[/\-\.]\d{1,4}').hasMatch(value)) {
    return true;
  }
  // Named month pattern: "Jan 15, 2024" or "15 Jan 2024"
  if (RegExp(
    r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',
    caseSensitive: false,
  ).hasMatch(value)) {
    return true;
  }
  // ISO date at start: "2024-01-15T..."
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) return true;
  return false;
}

/// Quick heuristic: does this string look like a monetary amount?
bool _looksLikeAmount(String value) {
  // Strip currency symbols and whitespace, check if remainder is numeric.
  final stripped = value
      .replaceAll(
        RegExp(r'[\$\€\£\¥\₩\₹\₺\₽\₪\฿\₫\₦\s]'),
        '',
      )
      .trim();
  if (stripped.isEmpty) return false;

  // Accounting negative: "(1,234.56)"
  final test = stripped.startsWith('(') && stripped.endsWith(')')
      ? stripped.substring(1, stripped.length - 1)
      : stripped;

  // Remove leading minus/plus.
  final noSign = test.replaceFirst(RegExp(r'^[+\-]'), '');

  // Should be digits with optional separators.
  return RegExp(r'^\d[\d,.\s]*\d$|^\d$').hasMatch(noSign);
}

/// Quick heuristic: does this string look like a currency code?
bool _looksLikeCurrency(String value) {
  // 3-letter uppercase ISO 4217 codes.
  if (RegExp(r'^[A-Z]{3}$').hasMatch(value.trim().toUpperCase())) return true;
  // Common symbols.
  if (RegExp(r'^[\$\€\£\¥\₩\₹]$').hasMatch(value.trim())) return true;
  return false;
}

/// Quick heuristic: does this string look like a transaction type/direction?
bool _looksLikeType(String value) {
  const typeKeywords = {
    'expense',
    'income',
    'debit',
    'credit',
    'dr',
    'cr',
    'inflow',
    'outflow',
    'deposit',
    'withdrawal',
    'payment',
    'purchase',
    'refund',
    'transfer',
  };
  return typeKeywords.contains(value.trim().toLowerCase());
}

// ---------------------------------------------------------------------------
// Overall confidence computation
// ---------------------------------------------------------------------------

MappingConfidence _computeOverallConfidence(
  Map<ImportField, FieldMappingScore> fieldScores,
  Map<ImportField, int> mapping,
  bool hasSplit,
  List<List<String>> sampleRows,
) {
  // Required fields: date and (amount OR debit+credit).
  final hasDate = mapping.containsKey(ImportField.date);
  final hasAmount = mapping.containsKey(ImportField.amount);
  final hasBothSplit = mapping.containsKey(ImportField.debit) &&
      mapping.containsKey(ImportField.credit);
  final hasAmountOrSplit = hasAmount || hasBothSplit;

  if (!hasDate || !hasAmountOrSplit) return MappingConfidence.low;

  // Check scores of required fields.
  final dateScore = fieldScores[ImportField.date]?.score ?? 0.0;
  final amountScore = hasSplit
      ? [
          fieldScores[ImportField.debit]?.score ?? 0.0,
          fieldScores[ImportField.credit]?.score ?? 0.0,
        ].reduce((a, b) => a < b ? a : b)
      : fieldScores[ImportField.amount]?.score ?? 0.0;

  // High confidence: both required fields scored > 0.8.
  if (dateScore >= 0.8 && amountScore >= 0.8) {
    return MappingConfidence.high;
  }

  // Medium confidence: both required fields scored > 0.5.
  if (dateScore >= 0.5 && amountScore >= 0.5) {
    return MappingConfidence.medium;
  }

  return MappingConfidence.low;
}

// ---------------------------------------------------------------------------
// Header normalization
// ---------------------------------------------------------------------------

/// Normalizes a header string for comparison: lower-case, strips all
/// non-alphanumeric characters (spaces, dashes, parentheses, etc.).
String _normalizeHeader(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
