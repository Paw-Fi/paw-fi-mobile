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

  const ImportMapping({
    required this.fieldToColumnIndex,
    this.hasHeader = true,
    this.hasSplitDebitCredit = false,
  });

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
    );
  }

  ImportMapping copyWithSplitDebitCredit(bool value) {
    return ImportMapping(
      fieldToColumnIndex: fieldToColumnIndex,
      hasHeader: hasHeader,
      hasSplitDebitCredit: value,
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
  final List<String> errors;
  final bool isDuplicate;
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
    this.isDuplicate = false,
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
    bool? isDuplicate,
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
      isDuplicate: isDuplicate ?? this.isDuplicate,
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
