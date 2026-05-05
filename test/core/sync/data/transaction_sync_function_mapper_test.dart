import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/sync/data/transaction_sync_function_mapper.dart';

void main() {
  test('maps queued expense create payload to save-expense request', () {
    final request = mapTransactionCreateSyncRequest(
      jsonDecode('''
      {
        "localId": "local-tx-1",
        "clientMutationId": "mutation-1",
        "userId": "user-1",
        "householdId": "household-1",
        "walletId": "wallet-1",
        "type": "expense",
        "amountCents": 1299,
        "currency": "eur",
        "category": "dining",
        "merchant": "Cafe Nero",
        "description": "Lunch",
        "dateYmd": "2026-04-30",
        "isPortfolio": false,
        "payerUserId": "user-2",
        "createdAt": "2026-04-30T12:00:00.000Z"
      }
      ''') as Map<String, dynamic>,
    );

    expect(request.functionName, 'save-expense');
    expect(request.body, {
      'userId': 'user-1',
      'amount': 12.99,
      'category': 'dining',
      'currency': 'EUR',
      'date': '2026-04-30',
      'clientCreatedAt': '2026-04-30T12:00:00.000Z',
      'type': 'expense',
      'description': 'Lunch',
      'merchant': 'Cafe Nero',
      'householdId': 'household-1',
      'accountId': 'wallet-1',
      'isPortfolio': false,
      'payerUserId': 'user-2',
      'clientMutationId': 'mutation-1',
    });
  });

  test('maps queued income create payload to save-income request', () {
    final request = mapTransactionCreateSyncRequest(
      jsonDecode('''
      {
        "clientMutationId": "mutation-2",
        "userId": "user-1",
        "walletId": "wallet-2",
        "type": "income",
        "amountCents": 250000,
        "currency": "USD",
        "category": "income:salary",
        "description": "Payroll",
        "dateYmd": "2026-04-30",
        "createdAt": "2026-04-30T12:00:00.000Z"
      }
      ''') as Map<String, dynamic>,
    );

    expect(request.functionName, 'save-income');
    expect(request.body['amount'], 2500);
    expect(request.body['type'], isNull);
    expect(request.body['accountId'], 'wallet-2');
    expect(request.body['clientMutationId'], 'mutation-2');
  });
}
