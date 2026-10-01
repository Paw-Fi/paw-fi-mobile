import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:http/testing.dart';
import 'package:moneko/features/home/presentation/utils/transaction_export_data_source.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_export_options_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('reads current financial classification and actual recurring fields',
      () async {
    final client = _client((request) async {
      final fields = request.url.queryParameters['select']!.split(',');
      expect(
          fields,
          containsAll([
            'account_id',
            'bank_account_id',
            'provider_pending',
            'provider_recurring',
            'analytics_class',
            'analytics_is_final',
            'analytics_spending_multiplier',
            'analytics_counts_toward_income',
            'scheduled_occurrence_date',
          ]));
      expect(request.url.queryParameters['is_recurring'], 'eq.false');
      expect(request.url.queryParameters['date'], 'lte.2026-07-31');
      return _response(request, [
        {
          ..._expenseRow('refund'),
          'account_id': _walletId,
          'bank_account_id': 'bank-1',
          'provider_pending': false,
          'provider_recurring': true,
          'analytics_class': 'refund_or_reversal',
          'analytics_is_final': true,
          'analytics_spending_multiplier': -1,
          'analytics_counts_toward_income': false,
          'scheduled_occurrence_date': '2026-07-10',
        }
      ]);
    });
    final rows = await _fetch(client);
    expect(rows.single.walletId, _walletId);
    expect(rows.single.spendingEffect, -100);
    expect(rows.single.countsTowardIncome, isFalse);
    expect(rows.single.providerRecurring, isTrue);
    expect(rows.single.scheduledOccurrenceDate, DateTime(2026, 7, 10));
  });

  test('paginates beyond one API page and fails if a later page fails',
      () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      if (requests == 1) {
        expect(request.url.queryParameters['offset'], '0');
        return _response(request,
            List.generate(1000, (index) => _expenseRow('expense-$index')));
      }
      expect(request.url.queryParameters['offset'], '1000');
      return _response(request, [_expenseRow('last')]);
    });
    final rows = await _fetch(client);
    expect(rows.length, 1001);
    expect(rows.last.id, 'last');

    requests = 0;
    final failingClient = _client((request) async {
      requests++;
      if (requests == 1) {
        return _response(request,
            List.generate(1000, (index) => _expenseRow('expense-$index')));
      }
      return http.Response(
          '{"message":"server read failed","code":"XX000"}', 500,
          reasonPhrase: 'Internal Server Error',
          request: request,
          headers: {'content-type': 'application/json'});
    });
    await expectLater(
        _fetch(failingClient), throwsA(isA<PostgrestException>()));
  });

  test('resolves wallet and recorder names after pending edits are merged',
      () async {
    final client = _client((request) async {
      if (request.url.path.endsWith('/accounts')) {
        expect(request.url.queryParameters['select'], 'id,name');
        expect(request.url.queryParameters['id'], contains(_walletId));
        return _response(request, [
          {'id': _walletId, 'name': 'Ví mới'}
        ]);
      }
      expect(request.url.path, endsWith('/users'));
      expect(request.url.queryParameters['select'], 'id,full_name');
      return _response(request, [
        {'id': _userId, 'full_name': '王芳'}
      ]);
    });
    final pending = ExpenseEntry.fromJson({
      ..._expenseRow('edited'),
      'household_id': null,
      'user_id': _userId,
      'account_id': _walletId,
      'account_name': 'Old wallet label',
      'raw_text': '新备注',
    });
    final rows = await TransactionExportDataSource(client)
        .enrichExportExpenses([pending]);
    expect(rows.single.accountName, 'Ví mới');
    expect(rows.single.userName, '王芳');
    expect(rows.single.rawText, '新备注');
    expect(rows.single.walletId, _walletId);
  });

  test('uses the existing household member read when profiles are unavailable',
      () async {
    final client = _client((request) async {
      if (request.url.path.endsWith('/users')) return _response(request, []);
      expect(request.url.path, endsWith('/rpc/get_household_home_members_v1'));
      expect(jsonDecode(request.body), {'p_household_id': _householdId});
      return _response(request, [
        {
          'household_id': _householdId,
          'user_id': _userId,
          'users': {'full_name': 'Nguyễn An'},
        }
      ]);
    });
    final rows =
        await TransactionExportDataSource(client).enrichExportExpenses([
      ExpenseEntry.fromJson({
        ..._expenseRow('shared'),
        'household_id': _householdId,
        'user_id': _userId,
      }),
    ]);
    expect(rows.single.userName, 'Nguyễn An');
  });

  test('keeps optimistic wallet labels and does not query their synthetic IDs',
      () async {
    final client =
        _client((request) async => throw StateError('Unexpected read'));
    final rows =
        await TransactionExportDataSource(client).enrichExportExpenses([
      ExpenseEntry.fromJson({
        ..._expenseRow('local'),
        'household_id': null,
        'account_id': 'optimistic-wallet-1',
        'account_name': '现金',
      }),
    ]);
    expect(rows.single.accountName, '现金');
  });

  test('resolves Space names using scoped metadata without exporting IDs',
      () async {
    final client = _client((request) async {
      expect(request.url.path, endsWith('/households'));
      expect(request.url.queryParameters['select'], 'id,name');
      return _response(request, [
        {'id': _householdId, 'name': 'Gia đình'}
      ]);
    });
    final names =
        await TransactionExportDataSource(client).fetchExportHouseholdNames([
      ExpenseEntry.fromJson({
        ..._expenseRow('shared'),
        'household_id': _householdId,
      }),
    ]);
    expect(names, {_householdId: 'Gia đình'});
  });

  test('does not silently replace a failed wallet lookup with empty metadata',
      () async {
    final client = _client((request) async => http.Response(
          '{"message":"wallet read failed","code":"XX000"}',
          500,
          headers: {'content-type': 'application/json'},
          request: request,
        ));
    await expectLater(
        TransactionExportDataSource(client).enrichExportExpenses([
          ExpenseEntry.fromJson({
            ..._expenseRow('expense'),
            'household_id': null,
            'account_id': _walletId,
          }),
        ]),
        throwsA(isA<PostgrestException>()));
  });

  test('does not export an old wallet name when its new metadata is absent',
      () async {
    final client = _client((request) async => _response(request, []));
    final rows =
        await TransactionExportDataSource(client).enrichExportExpenses([
      ExpenseEntry.fromJson({
        ..._expenseRow('moved'),
        'household_id': null,
        'account_id': _walletId,
        'account_name': 'Old wallet',
      }),
    ]);
    expect(rows.single.accountName, '');
  });

  test('batches wallet metadata without dropping names beyond the API limit',
      () async {
    var requestCount = 0;
    final entries = List.generate(
        205,
        (index) => ExpenseEntry.fromJson({
              ..._expenseRow('expense-$index'),
              'household_id': null,
              'account_id':
                  '00000000-0000-0000-0000-${index.toString().padLeft(12, '0')}',
            }));
    final client = _client((request) async {
      requestCount++;
      final ids = request.url.queryParameters['id']!
          .replaceFirst('in.(', '')
          .replaceFirst(')', '')
          .split(',')
          .map((id) => id.replaceAll('"', ''))
          .toList();
      expect(ids.length, lessThanOrEqualTo(100));
      return _response(request, [
        for (final id in ids) {'id': id, 'name': 'Wallet $id'},
      ]);
    });
    final rows =
        await TransactionExportDataSource(client).enrichExportExpenses(entries);
    expect(requestCount, 3);
    expect(rows.length, 205);
    expect(rows.every((row) => row.accountName == 'Wallet ${row.walletId}'),
        isTrue);
  });

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

  test('merges pending local rows over remote rows in the selected space', () {
    final expenses = mergeExportExpenses(
      remoteExpenses: [
        _entry(id: 'remote', date: DateTime(2026, 7, 4), amountCents: 100),
        _entry(id: 'edited', date: DateTime(2026, 7, 3), amountCents: 100),
      ],
      pendingLocalExpenses: [
        _entry(id: 'created', date: DateTime(2026, 7, 5), amountCents: 200),
        _entry(id: 'edited', date: DateTime(2026, 7, 3), amountCents: 300),
        _entry(
          id: 'other-household',
          date: DateTime(2026, 7, 6),
          amountCents: 400,
          householdId: 'household-2',
        ),
        _entry(
          id: 'recurring-template',
          date: DateTime(2026, 7, 7),
          amountCents: 500,
          isRecurring: true,
        ),
      ],
      space: const TransactionExportSpaceOption.household(
        householdId: 'household-1',
        label: 'Home',
      ),
      dateRange: DateTimeRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
    );

    expect(
        expenses.map((expense) => expense.id), ['created', 'remote', 'edited']);
    expect(expenses.last.amountCents, 300);
  });

  test('excludes tombstoned pending local rows from all-space export', () {
    final expenses = mergeExportExpenses(
      remoteExpenses: [
        _entry(id: 'keep', date: DateTime(2026, 7, 4), amountCents: 100),
      ],
      pendingLocalExpenses: [
        _entry(id: 'deleted', date: DateTime(2026, 7, 5), amountCents: 200),
      ],
      space: const TransactionExportSpaceOption.all('All'),
      dateRange: DateTimeRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
      excludedExpenseIds: const {'deleted'},
    );

    expect(expenses.map((expense) => expense.id), ['keep']);
  });

  test('removes a remote row moved outside the local export range', () {
    final expenses = mergeExportExpenses(
      remoteExpenses: [
        _entry(id: 'moved', date: DateTime(2026, 7, 31), amountCents: 100),
      ],
      pendingLocalExpenses: [
        _entry(id: 'moved', date: DateTime(2026, 8, 1), amountCents: 100),
      ],
      space: const TransactionExportSpaceOption.household(
        householdId: 'household-1',
        label: 'Home',
      ),
      dateRange: DateTimeRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
    );

    expect(expenses, isEmpty);
  });

  test('removes a remote row moved to a different local space', () {
    final expenses = mergeExportExpenses(
      remoteExpenses: [
        _entry(id: 'moved', date: DateTime(2026, 7, 31), amountCents: 100),
      ],
      pendingLocalExpenses: [
        _entry(
          id: 'moved',
          date: DateTime(2026, 7, 31),
          amountCents: 100,
          householdId: 'household-2',
        ),
      ],
      space: const TransactionExportSpaceOption.household(
        householdId: 'household-1',
        label: 'Home',
      ),
      dateRange: DateTimeRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
    );

    expect(expenses, isEmpty);
  });
}

ExpenseEntry _entry({
  required String id,
  required DateTime date,
  required int amountCents,
  String? householdId = 'household-1',
  bool isRecurring = false,
}) {
  return ExpenseEntry(
    id: id,
    userId: 'user-1',
    householdId: householdId,
    date: date,
    amountCents: amountCents,
    createdAt: date,
    isRecurring: isRecurring,
  );
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

const _walletId = '00000000-0000-0000-0000-000000000001';
const _userId = '00000000-0000-0000-0000-000000000002';
const _householdId = '00000000-0000-0000-0000-000000000003';

SupabaseClient _client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient('https://example.test', 'anon-key',
        httpClient: MockClient(handler));

http.Response _response(
        http.Request request, List<Map<String, dynamic>> rows) =>
    http.Response(jsonEncode(rows), 200,
        headers: {'content-type': 'application/json'}, request: request);

Future<List<ExpenseEntry>> _fetch(SupabaseClient client) =>
    TransactionExportDataSource(client).fetchExportExpenses(
      userId: 'user-1',
      dateRange: DateTimeRange(
          start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 31)),
      space: const TransactionExportSpaceOption.household(
          householdId: 'household-1', label: 'Home'),
    );
