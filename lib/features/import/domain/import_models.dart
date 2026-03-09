/// Fields that can be mapped from CSV columns to import data.
enum ImportField {
  date,
  amount,
  debit,
  credit,
  category,
  description,
  currency,
  type,
  balance,
  reference,
}

// ---------------------------------------------------------------------------
// Row-level issue tracking
// ---------------------------------------------------------------------------

/// Structured reason why a parsed row has a problem.
/// Replaces raw error strings for UI-friendly display and programmatic checks.
enum RowIssue {
  /// Date could not be parsed from the raw value.
  invalidDate,

  /// Amount could not be parsed from the raw value.
  invalidAmount,

  /// Currency value is missing or unrecognized.
  missingCurrency,

  /// Transaction type (expense/income) could not be determined.
  unknownType,

  /// The row matched a duplicate key in the same file.
  duplicateInFile,

  /// The row matched a duplicate key against existing database records.
  duplicateInDb,

  /// Mapping confidence for one or more required fields was low.
  lowConfidenceMapping,
}

/// Why a row was flagged as a duplicate.
enum DuplicateReason {
  /// Not a duplicate.
  none,

  /// Matches another row within the same import file.
  inFile,

  /// Matches an existing transaction in the database.
  inDb,
}

// ---------------------------------------------------------------------------
// Mapping confidence
// ---------------------------------------------------------------------------

/// Confidence level for a single field mapping.
enum FieldConfidence {
  /// Exact header match against a known synonym.
  exact,

  /// Substring or partial match.
  partial,

  /// Inferred from sampled row values (e.g. column contains date-like strings).
  valueBased,

  /// No match found; field is unmapped.
  none,
}

/// Per-field mapping score used to compute overall confidence.
class FieldMappingScore {
  final ImportField field;
  final int? columnIndex;
  final FieldConfidence confidence;

  /// 0.0 to 1.0 score combining header and value signals.
  final double score;

  /// Human-readable reason for this score (e.g. "exact header match: 'Date'").
  final String? reason;

  const FieldMappingScore({
    required this.field,
    required this.columnIndex,
    required this.confidence,
    required this.score,
    this.reason,
  });
}

/// Overall mapping confidence level.
enum MappingConfidence {
  /// All required fields mapped with high scores. Safe to skip map step.
  high,

  /// Required fields mapped but some with low scores. Show map step but
  /// pre-fill with best guesses.
  medium,

  /// Required fields missing or very low scores. Must show map step.
  low,
}

/// Result of auto-mapping: wraps an [ImportMapping] with confidence metadata.
class MappingResult {
  final ImportMapping mapping;
  final MappingConfidence confidence;
  final Map<ImportField, FieldMappingScore> fieldScores;

  /// Warnings about the mapping (e.g. collision between fields).
  final List<String> warnings;

  /// Fraction of sampled rows that parsed successfully with this mapping
  /// (0.0 to 1.0). null if no row validation was performed.
  final double? sampleValidRate;

  const MappingResult({
    required this.mapping,
    required this.confidence,
    required this.fieldScores,
    this.warnings = const [],
    this.sampleValidRate,
  });
}

/// Detected bank/app format hint, used to show the user what format was found.
enum CsvFormatHint {
  unknown,
  generic,
  chase,
  bankOfAmerica,
  wellsFargo,
  revolutEur,
  n26,
  wise,
  paypal,
  splitDebitCredit,
}

extension CsvFormatHintLabel on CsvFormatHint {
  String get displayName {
    switch (this) {
      case CsvFormatHint.unknown:
        return 'Unknown';
      case CsvFormatHint.generic:
        return 'Generic CSV';
      case CsvFormatHint.chase:
        return 'Chase';
      case CsvFormatHint.bankOfAmerica:
        return 'Bank of America';
      case CsvFormatHint.wellsFargo:
        return 'Wells Fargo';
      case CsvFormatHint.revolutEur:
        return 'Revolut';
      case CsvFormatHint.n26:
        return 'N26';
      case CsvFormatHint.wise:
        return 'Wise';
      case CsvFormatHint.paypal:
        return 'PayPal';
      case CsvFormatHint.splitDebitCredit:
        return 'Debit/Credit Split';
    }
  }
}

class ImportTable {
  final List<String> headers;
  final List<List<String>> rows;
  final String? detectedDelimiter;
  final CsvFormatHint formatHint;

  const ImportTable({
    required this.headers,
    required this.rows,
    this.detectedDelimiter,
    this.formatHint = CsvFormatHint.unknown,
  });
}

class ImportRow {
  final int index;
  final List<String> values;

  const ImportRow({required this.index, required this.values});
}

class ImportMapping {
  final Map<ImportField, int> fieldToColumnIndex;
  final bool hasHeader;

  /// When true, amount = credit - debit using separate columns.
  final bool hasSplitDebitCredit;

  /// Overall confidence of this mapping. Null for manually-constructed mappings.
  final MappingConfidence? confidence;

  const ImportMapping({
    required this.fieldToColumnIndex,
    this.hasHeader = true,
    this.hasSplitDebitCredit = false,
    this.confidence,
  });

  /// Whether this mapping has enough required fields to attempt parsing.
  bool get hasRequiredFields {
    final hasDate = fieldToColumnIndex.containsKey(ImportField.date);
    final hasAmount = fieldToColumnIndex.containsKey(ImportField.amount) ||
        (fieldToColumnIndex.containsKey(ImportField.debit) &&
            fieldToColumnIndex.containsKey(ImportField.credit));
    return hasDate && hasAmount;
  }

  ImportMapping copyWithField(ImportField field, int? index) {
    final updated = Map<ImportField, int>.from(fieldToColumnIndex);
    if (index == null) {
      updated.remove(field);
    } else {
      updated[field] = index;
    }
    return ImportMapping(
      fieldToColumnIndex: updated,
      hasHeader: hasHeader,
      hasSplitDebitCredit: hasSplitDebitCredit,
      confidence: confidence,
    );
  }

  ImportMapping copyWithSplitDebitCredit(bool value) {
    return ImportMapping(
      fieldToColumnIndex: fieldToColumnIndex,
      hasHeader: hasHeader,
      hasSplitDebitCredit: value,
      confidence: confidence,
    );
  }
}

class ImportParsedRow {
  static const _unset = Object();

  final int index;
  final DateTime? date;
  final int? amountCents;
  final String? category;
  final String? description;
  final String? currency;
  final String? type;

  /// Legacy error strings for backward compatibility. Prefer [issues].
  final List<String> errors;

  /// Structured row-level issues for UI-friendly display.
  final List<RowIssue> issues;

  final bool isDuplicate;

  /// Why this row was flagged as duplicate. [DuplicateReason.none] when not.
  final DuplicateReason duplicateReason;

  final List<String>? rawValues;

  const ImportParsedRow({
    required this.index,
    required this.date,
    required this.amountCents,
    required this.category,
    required this.description,
    required this.currency,
    required this.type,
    required this.errors,
    this.issues = const [],
    this.isDuplicate = false,
    this.duplicateReason = DuplicateReason.none,
    this.rawValues,
  });

  bool get isValid => errors.isEmpty && date != null && amountCents != null;

  ImportParsedRow copyWith({
    DateTime? date,
    int? amountCents,
    Object? category = _unset,
    Object? description = _unset,
    Object? currency = _unset,
    Object? type = _unset,
    List<String>? errors,
    List<RowIssue>? issues,
    bool? isDuplicate,
    DuplicateReason? duplicateReason,
    List<String>? rawValues,
  }) {
    return ImportParsedRow(
      index: index,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      category: category == _unset ? this.category : category as String?,
      description:
          description == _unset ? this.description : description as String?,
      currency: currency == _unset ? this.currency : currency as String?,
      type: type == _unset ? this.type : type as String?,
      errors: errors ?? this.errors,
      issues: issues ?? this.issues,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateReason: duplicateReason ?? this.duplicateReason,
      rawValues: rawValues ?? this.rawValues,
    );
  }
}

/// Parsed result from a multi-sheet source (e.g. XLSX).
class ImportSheetResult {
  final String sheetName;
  final ImportTable table;

  const ImportSheetResult({required this.sheetName, required this.table});
}
