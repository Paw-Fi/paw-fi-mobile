import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

ExpenseEntry _entry(String id, {String userId = 'user', int cents = 1000}) =>
    ExpenseEntry(
      id: id,
      userId: userId,
      date: DateTime(2026, 10, 3),
      createdAt: DateTime.utc(2026, 10, 3, 12),
      amountCents: cents,
      currency: 'EUR',
      category: 'food',
      rawText: '食事',
      type: 'expense',
    );

({
  ExpenseEntry entry,
  String clientMutationId,
  String operation,
  Map<String, dynamic> payload,
}) _mutation(ExpenseEntry entry) => (
      entry: entry,
      clientMutationId: 'mobile:${entry.id}',
      operation: 'create',
      payload: <String, dynamic>{
        'functionName': 'save-expense',
        'requestBody': {'amount': entry.amountCents / 100, 'currency': 'EUR'},
      },
    );

void main() {
  test('a failed second write restores rows, outbox, summary and revision',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _entry('original', cents: 2500);
    await database.writeOptimisticTransactionBatch([_mutation(original)]);
    final revision = database.transactionRevision;
    var changes = 0;
    final subscription = database.transactionChanges.listen((_) => changes++);
    addTearDown(subscription.cancel);

    await expectLater(
      database.writeOptimisticTransactionBatch([
        _mutation(original.copyWith(amountCents: 5000)),
        _mutation(_entry('invalid', userId: '')),
      ]),
      throwsArgumentError,
    );
    await Future<void>.delayed(Duration.zero);

    final rows =
        await database.getRecentTransactions(userId: 'user', householdId: null);
    final outbox = await database.getOutboxMutations();
    final summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user', householdId: null),
        month: DateTime(2026, 10),
        currency: 'EUR');
    expect(rows.single.id, 'original');
    expect(rows.single.amountCents, 2500);
    expect(outbox.single.clientMutationId, 'mobile:original');
    expect(outbox.single.payloadJson, contains('25.0'));
    expect(summary?.expenseCents, 2500);
    expect(database.transactionRevision, revision);
    expect(changes, 0);
  });

  test('a successful batch survives reopen and idempotent replay', () async {
    final directory = await Directory.systemTemp.createTemp('ai-batch-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/transactions.sqlite';
    var database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path));
    final mutations = [_mutation(_entry('one')), _mutation(_entry('two'))];
    var changes = 0;
    final subscription = database.transactionChanges.listen((_) => changes++);
    await database.writeOptimisticTransactionBatch(mutations);
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);
    expect(database.transactionRevision, 1);
    await subscription.cancel();
    await database.close();

    database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path));
    addTearDown(database.close);
    final rows =
        await database.getRecentTransactions(userId: 'user', householdId: null);
    expect(rows.map((row) => row.id).toSet(), {'one', 'two'});
    expect(rows.every((row) => row.clientMutationId == 'mobile:${row.id}'),
        isTrue);
    expect((await database.getOutboxMutations()).length, 2);
    await database.writeOptimisticTransactionBatch(mutations);
    expect((await database.getOutboxMutations()).length, 2);
    final summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user', householdId: null),
        month: DateTime(2026, 10),
        currency: 'EUR');
    expect(summary?.expenseCents, 2000);
  });

  test('an empty batch does not emit a mutation revision', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.writeOptimisticTransactionBatch([]);
    expect(database.transactionRevision, 0);
    expect(await database.getOutboxMutations(), isEmpty);
  });
}
