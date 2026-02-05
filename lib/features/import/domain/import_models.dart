enum ImportField {
  date,
  amount,
  category,
  description,
  currency,
  type,
}

class ImportTable {
  final List<String> headers;
  final List<List<String>> rows;

  const ImportTable({required this.headers, required this.rows});
}

class ImportRow {
  final int index;
  final List<String> values;

  const ImportRow({required this.index, required this.values});
}

class ImportMapping {
  final Map<ImportField, int> fieldToColumnIndex;
  final bool hasHeader;

  const ImportMapping({
    required this.fieldToColumnIndex,
    this.hasHeader = true,
  });
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
