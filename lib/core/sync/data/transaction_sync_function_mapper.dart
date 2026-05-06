class TransactionSyncFunctionRequest {
  const TransactionSyncFunctionRequest({
    required this.functionName,
    required this.body,
  });

  final String functionName;
  final Map<String, dynamic> body;
}

TransactionSyncFunctionRequest mapTransactionCreateSyncRequest(
  Map<String, dynamic> payload,
) {
  final type = payload['type']?.toString().trim().toLowerCase();
  if (type != 'expense' && type != 'income') {
    throw ArgumentError.value(type, 'type', 'must be expense or income');
  }

  final amountCents = _readInt(payload['amountCents']);
  final amount = amountCents / 100;
  final currency = payload['currency']?.toString().trim().toUpperCase();
  final date = payload['dateYmd']?.toString().trim();

  if (amountCents <= 0) {
    throw ArgumentError.value(amountCents, 'amountCents', 'must be positive');
  }
  if (currency == null || currency.length != 3) {
    throw ArgumentError.value(currency, 'currency', 'must be an ISO code');
  }
  if (date == null || date.isEmpty) {
    throw ArgumentError.value(date, 'dateYmd', 'must not be empty');
  }

  final category = payload['category']?.toString().trim();
  final body = <String, dynamic>{
    'userId': _requiredString(payload, 'userId'),
    'amount': amount,
    'category':
        category == null || category.isEmpty ? 'uncategorized' : category,
    'currency': currency,
    'date': date,
    'clientCreatedAt': _requiredString(payload, 'createdAt'),
    'clientMutationId': _requiredString(payload, 'clientMutationId'),
  };

  if (type == 'expense') {
    body['type'] = 'expense';
  }

  _putIfPresent(body, 'description', payload['description']);
  _putIfPresent(body, 'merchant', payload['merchant']);
  _putIfPresent(body, 'householdId', payload['householdId']);
  _putIfPresent(body, 'accountId', payload['walletId']);
  _putIfPresent(body, 'receiptImageUrl', payload['receiptImageUrl']);
  _putIfPresent(body, 'payerUserId', payload['payerUserId']);

  if (payload.containsKey('isPortfolio')) {
    body['isPortfolio'] = payload['isPortfolio'] == true;
  }
  if (payload['isRecurring'] == true) {
    body['isRecurring'] = true;
  }
  final recurrenceRule = payload['recurrenceRule'];
  if (recurrenceRule is Map && recurrenceRule.isNotEmpty) {
    body['recurrence_rule'] = Map<String, dynamic>.from(recurrenceRule);
  }
  final breakdown = payload['breakdown'];
  if (breakdown is List && breakdown.isNotEmpty) {
    body['breakdown'] = breakdown;
  }
  final customSplits = payload['customSplits'];
  if (customSplits is Map && customSplits.isNotEmpty) {
    body['customSplits'] = Map<String, dynamic>.from(customSplits);
  }

  return TransactionSyncFunctionRequest(
    functionName: type == 'income' ? 'save-income' : 'save-expense',
    body: body,
  );
}

String _requiredString(Map<String, dynamic> payload, String key) {
  final value = payload[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw ArgumentError.value(value, key, 'must not be empty');
  }
  return value;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    return num.tryParse(value)?.round() ?? 0;
  }
  return 0;
}

void _putIfPresent(
  Map<String, dynamic> body,
  String key,
  Object? value,
) {
  if (value == null) return;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    body[key] = trimmed;
    return;
  }
  body[key] = value;
}
