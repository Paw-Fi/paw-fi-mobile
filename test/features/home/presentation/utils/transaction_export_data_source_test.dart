import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/features/home/presentation/utils/transaction_export_data_source.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_export_options_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('export excludes server tombstones and pending local deletions',
      () async {
    final client = SupabaseClient(
      'https://example.test',
      'anon-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/rest/v1/expenses'));
        expect(request.url.queryParameters['deleted_at'], 'is.null');
        expect(request.url.queryParameters['household_id'], 'eq.household-1');

        return http.Response(
          jsonEncode([
            _expenseRow('keep-expense'),
            _expenseRow('pending-delete-expense'),
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final expenses =
        await TransactionExportDataSource(client).fetchExportExpenses(
      userId: 'user-1',
      dateRange: DateTimeRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
      space: const TransactionExportSpaceOption.household(
        householdId: 'household-1',
        label: 'Home',
      ),
      excludedExpenseIds: const {'pending-delete-expense'},
    );

    expect(expenses.map((expense) => expense.id), ['keep-expense']);
  });
}

Map<String, dynamic> _expenseRow(String id) => {
      'id': id,
      'contact_id': null,
      'user_id': 'user-1',
      'household_id': 'household-1',
      'date': '2026-07-13',
      'amount_cents': 10000,
      'currency': 'USD',
      'category': 'other',
      'raw_text': 'Shared purchase',
      'merchant': null,
      'breakdown': null,
      'receipt_image_url': null,
      'created_at': '2026-07-13T10:00:00.000Z',
      'updated_at': '2026-07-13T10:00:00.000Z',
      'split_group_id': null,
      'type': 'expense',
      'is_recurring': false,
      'account_id': null,
    };
