import 'package:moneko/features/import/domain/import_models.dart';

ImportMapping autoMapFields(List<String> headers) {
  final normalized = headers.map(_normalizeHeader).toList();
  final mapping = <ImportField, int>{};

  final synonyms = <ImportField, List<String>>{
    ImportField.date: ['date', 'transactiondate', 'posteddate'],
    ImportField.amount: ['amount', 'amt', 'value', 'debit', 'credit'],
    ImportField.category: ['category', 'cat'],
    ImportField.description: ['description', 'memo', 'note', 'merchant'],
    ImportField.currency: ['currency', 'curr', 'code'],
    ImportField.type: ['type', 'transactiontype'],
  };

  for (final entry in synonyms.entries) {
    final field = entry.key;
    final candidates = entry.value;
    for (var i = 0; i < normalized.length; i++) {
      if (candidates.contains(normalized[i])) {
        mapping[field] = i;
        break;
      }
    }
  }

  return ImportMapping(fieldToColumnIndex: mapping);
}

String _normalizeHeader(String value) {
  final lowered = value.trim().toLowerCase();
  return lowered.replaceAll(RegExp(r'[^a-z0-9]'), '');
}
