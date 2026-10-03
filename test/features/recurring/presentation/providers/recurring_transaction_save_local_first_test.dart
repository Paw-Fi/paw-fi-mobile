import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/ui/notifications/app_mutation_error_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';

void main() {
  late Future<http.Response> Function(http.Request request) requestHandler;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'anon',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) => requestHandler(request)),
    );
  });

  test('household recurring expense persists native split request and outbox',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    Map<String, dynamic>? capturedBody;
    requestHandler = (request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse(request, capturedBody!);
    };
    final container = _container(database);
    addTearDown(container.dispose);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .saveRecurringExpense(
          userId: 'user_1',
          amount: 120,
          category: 'groceries',
          currency: 'USD',
          startDate: DateTime(2026, 2, 1),
          frequency: 'monthly',
          dueTime: '09:00:00',
          description: 'Household groceries',
          merchant: 'Fresh Market',
          householdId: 'household_1',
          customSplitType: SplitType.amount,
          customSplits: _amountSplits(),
          payerUserId: 'user_2',
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final requestBody = payload['requestBody'] as Map<String, dynamic>;
    final localRows = await database.getRecurringTransactions(
      userId: 'user_1',
      householdId: 'household_1',
    );

    expect(saved?.currency, 'USD');
    expect(saved?.householdId, 'household_1');
    expect(localRows.single.currency, 'USD');
    expect(localRows.single.amountCents, 12000);
    expect(localRows.single.merchant, 'Fresh Market');
    expect(localRows.single.walletId, 'wallet_usd');
    expect(mutation.operation, 'create');
    expect(mutation.status, localMutationStatusSynced);
    expect(requestBody['payerUserId'], 'user_2');
    expect(requestBody['merchant'], 'Fresh Market');
    expect(requestBody['customSplits'], _amountSplitPayload);
    expect((requestBody['recurrence_rule'] as Map)['due_time'], '09:00:00');
    expect(localRows.single.recurrenceRuleJson?['due_time'], '09:00:00');
    expect(capturedBody?['customSplits'], _amountSplitPayload);
    expect(capturedBody?['merchant'], 'Fresh Market');
  });

  test('single income occurrence queues the atomic override before replay',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (_) => throw const SocketException('offline');
    final container = _container(database);
    addTearDown(container.dispose);
    final recurring = _recurring(
      householdId: 'household_1',
      type: 'income',
      category: 'income:salary',
    );

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateSingleIncomeOccurrence(
          userId: 'user_1',
          recurringSeries: recurring,
          occurrenceDateToSkip: DateTime(2026, 2, 1),
          amount: 120,
          category: 'income:salary',
          currency: 'USD',
          date: DateTime(2026, 2, 2),
          description: 'February salary',
          merchant: 'Employer',
          source: 'Payroll',
          householdId: 'household_1',
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final requestBody = payload['requestBody'] as Map<String, dynamic>;

    expect(saved?.amount, 120);
    expect(mutation.operation,
        localRecurringOccurrenceConfirmationMutationOperation);
    expect(payload['functionName'], 'save-recurring-occurrence-override');
    expect(requestBody['source'], 'Payroll');
    expect(requestBody['category'], 'income:salary');
    expect(requestBody['currency'], 'USD');
    expect(requestBody['accountId'], 'wallet_usd');

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await database.getOutboxMutations()).single.status,
      localMutationStatusFailed,
    );
  });

  test('bank-generated occurrence can queue a manual confirmation offline',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = _container(database);
    addTearDown(container.dispose);
    requestHandler = (_) => throw const SocketException('offline');
    final recurring = RecurringTransaction.fromJson({
      ..._recurring(householdId: null).toJson(),
      'provider': null,
      'provider_fields': {'source': 'plaid_recurring_template'},
    });
    final result = await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(RecurringOccurrenceConfirmationCommand(
          userId: 'user_1',
          recurringTransaction: recurring,
          scheduledOccurrenceDate: recurring.date,
          paidDate: recurring.date,
          amountCents: 11760,
          accountId: 'wallet_usd',
        ));
    expect(result.isQueued, isTrue);
    await container.read(mobileOutboxDrainerProvider).drain();
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusFailed);
  });

  test('confirmed local occurrence cannot queue a second confirmation',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = _container(database);
    addTearDown(container.dispose);
    final today = DateTime.now();
    final recurring = _recurring(householdId: null, date: today);
    await database.upsertTransactions([
      ExpenseEntry(
        id: 'confirmed-occurrence',
        userId: 'user_1',
        date: today,
        amountCents: 10000,
        currency: 'USD',
        category: 'housing',
        createdAt: today,
        type: 'expense',
        parentRecurringId: recurring.id,
        scheduledOccurrenceDate: today,
        recurringConfirmedAt: today,
        recurringConfirmationSource: 'user',
      ),
    ]);

    final result = await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(RecurringOccurrenceConfirmationCommand(
          userId: 'user_1',
          recurringTransaction: recurring,
          scheduledOccurrenceDate: today,
          paidDate: today,
          amountCents: 11000,
          accountId: 'wallet_usd',
        ));

    expect(result.isQueued, isTrue);
    expect(result.optimisticId, 'confirmed-occurrence');
    expect(await database.getOutboxMutations(), isEmpty);
    expect(
      (await database.getTransactionByIdOrClientRecordId(
        'confirmed-occurrence',
      ))
          ?.amountCents,
      10000,
    );
  });

  test('next future occurrence preconfirmation stays local-first', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (_) => throw const SocketException('offline');
    final container = _container(database);
    addTearDown(container.dispose);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledDate = today.add(const Duration(days: 30));
    final paidDate = scheduledDate.add(const Duration(days: 10));
    final recurring = _recurring(householdId: null, date: today).copyWith(
      serverNextOccurrenceDate: scheduledDate,
    );

    final command = RecurringOccurrenceConfirmationCommand(
      userId: 'user_1',
      recurringTransaction: recurring,
      scheduledOccurrenceDate: scheduledDate,
      paidDate: paidDate,
      amountCents: 10000,
      accountId: 'wallet_usd',
      allowNextPreconfirmation: true,
    );
    final result = await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(command);

    expect(result.isQueued, isTrue);
    final localEntry = await database.getTransactionByIdOrClientRecordId(
      command.optimisticId,
    );
    expect(formatDateOnlyYmd(localEntry!.date), formatDateOnlyYmd(paidDate));
    expect(
      formatDateOnlyYmd(localEntry.scheduledOccurrenceDate!),
      formatDateOnlyYmd(scheduledDate),
    );
    final laterScheduledDate = scheduledDate.add(const Duration(days: 30));
    final secondResult = await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(RecurringOccurrenceConfirmationCommand(
          userId: 'user_1',
          recurringTransaction: recurring.copyWith(
            serverNextOccurrenceDate: laterScheduledDate,
          ),
          scheduledOccurrenceDate: laterScheduledDate,
          paidDate: laterScheduledDate,
          amountCents: 10000,
          accountId: 'wallet_usd',
          allowNextPreconfirmation: true,
        ));
    expect(secondResult.isQueued, isFalse);
    await _waitForAsync(() async {
      final mutations = await database.getOutboxMutations();
      return mutations.length == 1 &&
          mutations.single.status == localMutationStatusFailed;
    });
  });

  test('stale reconfirmation preserves the original queued occurrence',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (_) => throw const SocketException('offline');
    final container = _container(database);
    addTearDown(container.dispose);
    final today = DateTime.now();
    final recurring = _recurring(householdId: null, date: today);
    final firstCommand = RecurringOccurrenceConfirmationCommand(
      userId: 'user_1',
      recurringTransaction: recurring,
      scheduledOccurrenceDate: today,
      paidDate: today,
      amountCents: 10000,
      accountId: 'wallet_usd',
    );

    final firstResult = await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(firstCommand);
    expect(firstResult.isQueued, isTrue);
    await _waitForAsync(() async {
      final mutations = await database.getOutboxMutations();
      return mutations.length == 1 &&
          mutations.single.status == localMutationStatusFailed;
    });
    final originalMutation = (await database.getOutboxMutations()).single;
    final originalPayload =
        jsonDecode(originalMutation.payloadJson) as Map<String, dynamic>;

    final staleResult = await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(RecurringOccurrenceConfirmationCommand(
          userId: 'user_1',
          recurringTransaction: recurring,
          scheduledOccurrenceDate: today,
          paidDate: today,
          amountCents: 12500,
          accountId: 'wallet_usd',
        ));

    expect(staleResult.isQueued, isTrue);
    expect(staleResult.optimisticId, firstCommand.optimisticId);
    await container.read(mobileOutboxDrainerProvider).drain();
    final preservedEntry = await database.getTransactionByIdOrClientRecordId(
      firstCommand.optimisticId,
    );
    expect(preservedEntry, isNotNull);
    final preserved = preservedEntry!;
    expect(preserved.amountCents, 10000);
    expect(preserved.parentRecurringId, recurring.id);
    expect(
      formatDateOnlyYmd(preserved.scheduledOccurrenceDate!),
      formatDateOnlyYmd(today),
    );
    expect(preserved.clientMutationId, firstCommand.idempotencyKey);
    final preservedMutations = await database.getOutboxMutations();
    expect(preservedMutations, hasLength(1));
    expect(preservedMutations.single.clientMutationId,
        originalMutation.clientMutationId);
    expect(preservedMutations.single.entityId, originalMutation.entityId);
    expect(preservedMutations.single.operation, originalMutation.operation);
    expect(preservedMutations.single.payloadJson, originalMutation.payloadJson);
    expect(
      (originalPayload['requestBody'] as Map<String, dynamic>)['amount'],
      100.0,
    );

    final canonicalEntry = preserved.copyWith(
      id: 'canonical-occurrence',
      clientRecordId: firstCommand.optimisticId,
      clientMutationId: null,
    );
    await database.upsertTransactions([canonicalEntry]);
    await database.markTransactionMutationExhausted(
      mutation: originalMutation,
    );

    final remainingOccurrences =
        await database.getTransactionsByScheduledOccurrenceRange(
      userId: 'user_1',
      householdId: null,
      parentRecurringId: recurring.id,
      startDate: today,
      endDate: today,
    );
    expect(
      remainingOccurrences.map((entry) => entry.id),
      isNot(contains(firstCommand.optimisticId)),
    );
    final retainedCanonical = await database.getTransactionByIdOrClientRecordId(
      canonicalEntry.id,
    );
    expect(retainedCanonical?.amountCents, 10000);
    expect(retainedCanonical?.parentRecurringId, recurring.id);
  });

  test('simultaneous confirmations preserve the first occurrence mutation',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (_) => throw const SocketException('offline');
    final container = _container(database);
    addTearDown(container.dispose);
    final today = DateTime.now();
    final recurring = _recurring(householdId: null, date: today);
    final firstCommand = RecurringOccurrenceConfirmationCommand(
      userId: 'user_1',
      recurringTransaction: recurring,
      scheduledOccurrenceDate: today,
      paidDate: today,
      amountCents: 10000,
      accountId: 'wallet_usd',
    );
    final secondCommand = RecurringOccurrenceConfirmationCommand(
      userId: 'user_1',
      recurringTransaction: recurring,
      scheduledOccurrenceDate: today,
      paidDate: today,
      amountCents: 12500,
      accountId: 'wallet_usd',
    );

    final results = await Future.wait([
      container
          .read(recurringOccurrenceConfirmationProvider)
          .confirm(firstCommand),
      container
          .read(recurringOccurrenceConfirmationProvider)
          .confirm(secondCommand),
    ]);

    expect(results.map((result) => result.optimisticId).toSet(), hasLength(1));
    await _waitForAsync(() async {
      final mutations = await database.getOutboxMutations();
      return mutations.length == 1 &&
          mutations.single.status == localMutationStatusFailed;
    });
    final retainedEntry = await database.getTransactionByIdOrClientRecordId(
      firstCommand.optimisticId,
    );
    expect(retainedEntry?.amountCents, 10000);
    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    expect(
      (payload['requestBody'] as Map<String, dynamic>)['amount'],
      100.0,
    );
  });

  test('materialized occurrence suppresses its stale recurring CTA', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final container = _container(database);
    addTearDown(container.dispose);
    final scheduledDate = DateTime(2026, 9, 12);
    await database.upsertTransactions([
      ExpenseEntry(
        id: 'confirmed-occurrence',
        userId: 'user_1',
        date: scheduledDate,
        amountCents: 10000,
        currency: 'USD',
        category: 'housing',
        createdAt: scheduledDate,
        type: 'expense',
        parentRecurringId: 'recurring_1',
        scheduledOccurrenceDate: scheduledDate,
        recurringConfirmedAt: scheduledDate,
        recurringConfirmationSource: 'user',
      ),
    ]);

    final isMaterialized = await container.read(
      recurringOccurrenceMaterializedProvider(
        RecurringOccurrenceMaterializationQuery(
          userId: 'user_1',
          householdId: null,
          recurringId: 'recurring_1',
          scheduledOccurrenceDate: scheduledDate,
        ),
      ).future,
    );

    expect(isMaterialized, isTrue);
  });

  test(
      'deleting a recurring series removes its materialized occurrences locally',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (request) async => http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
    final container = _container(database);
    addTearDown(container.dispose);
    final recurring = _recurring(householdId: 'household_1');
    final actual = _entry(recurring).copyWith(
      id: 'actual-occurrence-1',
      isRecurring: false,
      parentRecurringId: recurring.id,
      scheduledOccurrenceDate: DateTime(2026, 2, 1),
    );
    await database.upsertTransactions([actual]);
    final notifier =
        container.read(recurringTransactionsProvider('household_1').notifier);
    notifier.addRecurring(recurring);
    final initialFeedRefresh =
        container.read(transactionsFeedRefreshSignalProvider);
    final initialDashboardRefresh =
        container.read(dashboardRefreshSignalProvider);

    final result = await notifier.deleteRecurring(
      'user_1',
      recurring.id,
      transaction: recurring,
    );

    expect(result.success, isTrue);
    expect(
      await database.getTransactionsByParentRecurringId(
        userId: 'user_1',
        householdId: 'household_1',
        parentRecurringId: recurring.id,
      ),
      isEmpty,
    );
    expect(
      container.read(transactionsFeedRefreshSignalProvider),
      initialFeedRefresh + 1,
    );
    expect(
      container.read(dashboardRefreshSignalProvider),
      initialDashboardRefresh + 1,
    );
  });

  test('terminal recurring deletion restores materialized occurrences locally',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (request) async => _terminalResponse(request);
    final container = _container(database);
    addTearDown(container.dispose);
    final recurring = _recurring(householdId: 'household_1');
    final actual = _entry(recurring).copyWith(
      id: 'actual-occurrence-1',
      isRecurring: false,
      parentRecurringId: recurring.id,
      scheduledOccurrenceDate: DateTime(2026, 2, 1),
    );
    await database.upsertTransactions([actual]);
    final notifier =
        container.read(recurringTransactionsProvider('household_1').notifier);
    notifier.addRecurring(recurring);

    final result = await notifier.deleteRecurring(
      'user_1',
      recurring.id,
      transaction: recurring,
    );

    expect(result.success, isFalse);
    final restoredOccurrences =
        await database.getTransactionsByParentRecurringId(
      userId: 'user_1',
      householdId: 'household_1',
      parentRecurringId: recurring.id,
    );
    expect(restoredOccurrences.single.id, actual.id);
    expect(restoredOccurrences.single.parentRecurringId, recurring.id);
    expect(
      (await database.getOutboxMutations()).single.status,
      localMutationStatusCancelled,
    );
  });

  test(
      'current-month occurrence edit adjusts the recurring header before replay',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (_) => throw const SocketException('offline');
    final container = _container(database);
    addTearDown(container.dispose);
    final now = effectiveNow(preferredTimezone: null);
    final currentMonth = DateTime(now.year, now.month, 1);
    final recurring = _recurring(
      householdId: 'household_1',
      date: currentMonth,
    );
    final actual = _entry(recurring).copyWith(
      id: 'actual-occurrence-1',
      isRecurring: false,
      parentRecurringId: recurring.id,
      scheduledOccurrenceDate: currentMonth,
      amountCents: 8000,
    );

    final result = await container
        .read(recurringOccurrenceUpdateProvider)
        .update(RecurringOccurrenceUpdateCommand(
          userId: 'user_1',
          recurringTransaction: recurring,
          occurrence: RecurringOccurrenceTimelineItem(
            occurrenceId: 'occurrence-1',
            scheduledOccurrenceDate: currentMonth,
            status: 'confirmed',
            actualTransaction: actual,
            amountCents: 8000,
            currency: 'USD',
          ),
          paidDate: currentMonth,
          amountCents: 9000,
          accountId: 'wallet_usd',
        ));

    final headerSummary =
        container.read(recurringSeriesOptimisticProvider.notifier).apply(
      const RecurringReadScope(
        userId: 'user_1',
        householdId: 'household_1',
        currencies: ['USD'],
      ),
      [
        RecurringSeriesSummary(
          transaction: recurring,
          nextOccurrenceDate: DateTime(now.year, now.month + 1, 1),
          latestActionableOccurrenceDate: null,
          currentMonthConfirmedAmountDeltaCents: -2000,
        ),
      ],
    ).single;

    expect(result.isQueued, isTrue);
    expect(headerSummary.currentMonthConfirmedAmountDeltaCents, -1000);

    // Let the intentionally offline background drain finish before disposing
    // the in-memory database.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await database.getOutboxMutations()).single.status,
      localMutationStatusFailed,
    );
  });

  test('HTTP terminal confirmation rolls back once across database restart',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('recurring-restart-');
    final path = '${directory.path}/local.sqlite';
    var database = MonekoDatabase.fromExistingDatabaseForTesting(
      sqlite.sqlite3.open(path),
    );
    var container = _container(database);
    addTearDown(() async {
      container.dispose();
      await database.close();
      await directory.delete(recursive: true);
    });
    var requests = 0;
    requestHandler = (request) async {
      requests += 1;
      return http.Response(
        jsonEncode({
          'success': false,
          'code': 'OCCURRENCE_NOT_MANUALLY_CONFIRMABLE',
          'error': 'OCCURRENCE_NOT_MANUALLY_CONFIRMABLE',
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
    };
    final recurring = _recurring(householdId: null);
    final command = RecurringOccurrenceConfirmationCommand(
      userId: 'user_1',
      recurringTransaction: recurring,
      scheduledOccurrenceDate: recurring.date,
      paidDate: recurring.date,
      amountCents: 11760,
      accountId: 'wallet_usd',
    );
    final result = await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(command);
    expect(result.isQueued, isTrue);
    await container.read(mobileOutboxDrainerProvider).drain();
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
    expect(
        await database.getTransactionByIdOrClientRecordId(command.optimisticId),
        isNull);
    expect(container.read(appMutationErrorProvider)?.feature, 'recurring');

    container.dispose();
    await database.close();
    database = MonekoDatabase.fromExistingDatabaseForTesting(
      sqlite.sqlite3.open(path),
    );
    container = _container(database);
    await container.read(mobileOutboxDrainerProvider).drain();
    expect(requests, 1);
    expect(container.read(appMutationErrorProvider), isNull);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
    expect(
        await database.getTransactionByIdOrClientRecordId(command.optimisticId),
        isNull);
  });

  for (final providerBacked in [false, true]) {
    test(
        'recurring wallet accounting providerBacked=$providerBacked survives reconciliation and restart',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('recurring-wallet-');
      final path = '${directory.path}/local.sqlite';
      var database = MonekoDatabase.fromExistingDatabaseForTesting(
          sqlite.sqlite3.open(path));
      var container = _container(database, personalWalletTest: true);
      addTearDown(() async {
        container.dispose();
        await database.close();
        await directory.delete(recursive: true);
      });
      final now = effectiveNow(preferredTimezone: null);
      final date = DateTime(now.year, now.month, 1);
      final recurring = _recurring(householdId: null, date: date).copyWith(
          currency: 'CAD', accountId: 'wallet_cad', providerRecurring: true);
      final command = RecurringOccurrenceConfirmationCommand(
          userId: 'user_1',
          recurringTransaction: recurring,
          scheduledOccurrenceDate: date,
          paidDate: date,
          amountCents: 11760,
          accountId: 'wallet_cad');
      final query = WalletsScopeQuery(
          userId: 'user_1',
          householdId: null,
          selectedCurrency: 'CAD',
          selectedCurrencies: const ['CAD'],
          currentMonthStart: date);
      final wallet = WalletEntity(
          id: 'wallet_cad',
          userId: 'user_1',
          householdId: null,
          name: 'Card',
          icon: 'wallet',
          color: '#6B7280',
          currency: 'CAD',
          openingBalanceCents: 20000,
          currentBalanceCents: providerBacked ? 0 : 20000,
          goalAmountCents: null,
          isDefault: false,
          isSystem: false,
          isArchived: false,
          hasProviderBalance: providerBacked,
          linkedBankAccountId: providerBacked ? 'bank-cad' : null);
      final cacheKey = walletsListCacheKey(
          userId: query.userId,
          householdId: null,
          selectedCurrency: 'CAD',
          selectedCurrencies: const ['CAD'],
          currentMonthStart: date);
      Future<void> expectBalances(int balance, int spent) async {
        await container.read(networkReachabilityProvider.future);
        container.read(walletsListSessionCacheProvider.notifier).state = {
          cacheKey: [wallet]
        };
        await _waitForAsync(() async {
          final state =
              await container.read(walletsPageStateProvider(query).future);
          final snapshot = state.cachedSnapshotsByMonth[date];
          return snapshot?.walletBalances[wallet.id] == balance &&
              snapshot?.spentTotalCents == spent;
        });
        final state =
            await container.read(walletsPageStateProvider(query).future);
        final snapshot = state.cachedSnapshotsByMonth[date]!;
        final entries =
            await database.getTransactionsByScheduledOccurrenceRange(
                userId: 'user_1',
                householdId: null,
                parentRecurringId: recurring.id,
                startDate: date,
                endDate: date);
        // These are the production sources used by the overview/stack and detail.
        final detailBalance = providerBacked
            ? snapshot.walletBalances[wallet.id]
            : buildWalletSnapshot(
                    wallets: [wallet],
                    transactions: entries,
                    endExclusive: DateTime(now.year, now.month, now.day + 1))
                .walletBalances[wallet.id];
        expect(detailBalance, balance);
      }

      requestHandler = (_) => throw const SocketException('offline');
      await expectBalances(providerBacked ? 0 : 20000, 0);
      expect(
          (await container
                  .read(recurringOccurrenceConfirmationProvider)
                  .confirm(command))
              .isQueued,
          isTrue);
      await container.read(mobileOutboxDrainerProvider).drain();
      await expectBalances(providerBacked ? -11760 : 8240, 11760);
      container.dispose();
      await database.close();
      database = MonekoDatabase.fromExistingDatabaseForTesting(
          sqlite.sqlite3.open(path));
      container = _container(database, personalWalletTest: true);
      await expectBalances(providerBacked ? -11760 : 8240, 11760);
      final local = await database
          .getTransactionByIdOrClientRecordId(command.optimisticId);
      requestHandler = (request) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'transaction':
                  local!.copyWith(id: 'canonical-wallet-actual').toJson()
            }
          }),
          200,
          headers: {'content-type': 'application/json'});
      await database.markMutationFailed(
          clientMutationId: command.idempotencyKey,
          error: 'retry now',
          retryAfter: DateTime.now().subtract(const Duration(seconds: 1)));
      await container.read(mobileOutboxDrainerProvider).drain();
      await expectBalances(providerBacked ? 0 : 8240, 11760);
      container.dispose();
      await database.close();
      database = MonekoDatabase.fromExistingDatabaseForTesting(
          sqlite.sqlite3.open(path));
      container = _container(database, personalWalletTest: true);
      await expectBalances(providerBacked ? 0 : 8240, 11760);
      final result = await container
          .read(recurringOccurrenceConfirmationProvider)
          .confirm(command);
      expect(result.optimisticId, 'canonical-wallet-actual');
      await container.read(mobileOutboxDrainerProvider).drain();
      expect((await database.getOutboxMutations()).single.status,
          localMutationStatusSynced);
    });
  }

  for (final status in [0, 400, 401, 403, 429, 503]) {
    test(
        'HTTP $status retryable confirmation survives restart and reconciles only once',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('recurring-retry-');
      final path = '${directory.path}/local.sqlite';
      var database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path),
      );
      var container = _container(database);
      addTearDown(() async {
        container.dispose();
        await database.close();
        await directory.delete(recursive: true);
      });
      final recurring = _recurring(householdId: null);
      final command = RecurringOccurrenceConfirmationCommand(
        userId: 'user_1',
        recurringTransaction: recurring,
        scheduledOccurrenceDate: recurring.date,
        paidDate: recurring.date,
        amountCents: 11760,
        accountId: 'wallet_usd',
      );
      // Even a domain-looking body cannot make a gateway/server failure terminal.
      requestHandler = (request) async {
        if (status == 0) throw const SocketException('offline');
        return http.Response(
          jsonEncode({
            'success': false,
            'code': status == 400 || status == 403
                ? 'UNKNOWN_ERROR'
                : 'OCCURRENCE_FAILED',
          }),
          status,
          headers: {'content-type': 'application/json'},
        );
      };
      await container
          .read(recurringOccurrenceConfirmationProvider)
          .confirm(command);
      await container.read(mobileOutboxDrainerProvider).drain();
      expect((await database.getOutboxMutations()).single.status,
          localMutationStatusFailed);
      expect(container.read(appMutationErrorProvider), isNull);
      expect(
          (await database
                  .getTransactionByIdOrClientRecordId(command.optimisticId))
              ?.recurringConfirmedAt,
          isNotNull);

      container.dispose();
      await database.close();
      database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path),
      );
      container = _container(database);
      final restored = await database
          .getTransactionByIdOrClientRecordId(command.optimisticId);
      expect(restored?.recurringConfirmedAt, isNotNull);
      var successes = 0;
      requestHandler = (request) async {
        successes += 1;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'transaction': restored!.copyWith(id: 'canonical-actual').toJson()
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };
      await database.markMutationFailed(
        clientMutationId: command.idempotencyKey,
        error: 'retry now',
        retryAfter: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      await container.read(mobileOutboxDrainerProvider).drain();
      expect((await database.getOutboxMutations()).single.status,
          localMutationStatusSynced);
      container.dispose();
      await database.close();
      database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path),
      );
      container = _container(database);
      final reconfirmation = await container
          .read(recurringOccurrenceConfirmationProvider)
          .confirm(command);
      expect(reconfirmation.optimisticId, 'canonical-actual');
      await container.read(mobileOutboxDrainerProvider).drain();
      final actuals = await database.getTransactionsByScheduledOccurrenceRange(
        userId: 'user_1',
        householdId: null,
        parentRecurringId: recurring.id,
        startDate: recurring.date,
        endDate: recurring.date,
      );
      expect(actuals.single.id, 'canonical-actual');
      expect(actuals.single.recurringConfirmedAt, isNotNull);
      expect(successes, 1);
      expect(container.read(appMutationErrorProvider), isNull);
    });
  }

  for (final crashStage in ['queued', 'syncing', 'reconciled']) {
    test('SQLite reopen recovers confirmation interrupted at $crashStage',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('recurring-kill-');
      final path = '${directory.path}/local.sqlite';
      var database = MonekoDatabase.fromExistingDatabaseForTesting(
          sqlite.sqlite3.open(path));
      var container = _container(database);
      addTearDown(() async {
        container.dispose();
        await database.close();
        await directory.delete(recursive: true);
      });
      final recurring = _recurring(householdId: null);
      final command = RecurringOccurrenceConfirmationCommand(
        userId: 'user_1',
        recurringTransaction: recurring,
        scheduledOccurrenceDate: recurring.date,
        paidDate: recurring.date.subtract(const Duration(days: 1)),
        amountCents: 11760,
        accountId: 'wallet_usd',
      );
      final local = _entry(recurring).copyWith(
        id: command.optimisticId,
        isRecurring: false,
        date: command.paidDate,
        amountCents: command.amountCents,
        parentRecurringId: recurring.id,
        scheduledOccurrenceDate: command.scheduledOccurrenceDate,
        recurringConfirmedAt: DateTime.now(),
        recurringConfirmationSource: 'user',
        clientRecordId: command.optimisticId,
        clientMutationId: command.idempotencyKey,
      );
      // Stop at the same durable boundary the controller commits before HTTP.
      await database.writeOptimisticTransaction(
        entry: local,
        clientMutationId: command.idempotencyKey,
        operation: localRecurringOccurrenceConfirmationMutationOperation,
        payload: {
          'idempotencyKey': command.idempotencyKey,
          'clientMutationId': command.idempotencyKey,
          'requestBody': command.toRequestBody(),
        },
      );
      if (crashStage != 'queued') {
        await database.markMutationSyncing(command.idempotencyKey);
      }
      if (crashStage == 'reconciled') {
        await database.replaceOptimisticTransaction(
          optimisticId: command.optimisticId,
          savedEntry: local.copyWith(id: 'canonical-kill-actual'),
          clientMutationId: command.idempotencyKey,
        );
        // The coordinator's later mark-synced call has not happened.
      }
      container.dispose();
      await database.close();
      database = MonekoDatabase.fromExistingDatabaseForTesting(
          sqlite.sqlite3.open(path));
      container = _container(database);
      var requests = 0;
      requestHandler = (_) async {
        requests += 1;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'transaction':
                  local.copyWith(id: 'canonical-kill-actual').toJson()
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };
      if (crashStage == 'syncing') {
        final mutation = (await database.getOutboxMutations()).single;
        final beforeExpiry = mutation.updatedAt.add(const Duration(minutes: 9));
        expect(await database.nextRetryableMutation(beforeExpiry), isNull);
        expect(resolveNextMobileOutboxRetryDelay([mutation], now: beforeExpiry),
            const Duration(minutes: 1));
        expect(
            await database.nextRetryableMutation(
                mutation.updatedAt.add(localMutationSyncLease)),
            isNotNull);
      }
      await container.read(mobileOutboxDrainerProvider).drain();
      expect(requests, crashStage == 'reconciled' ? 0 : 1);
      expect((await database.getOutboxMutations()).single.status,
          localMutationStatusSynced);
      final actuals = await database.getTransactionsByScheduledOccurrenceRange(
        userId: command.userId,
        householdId: null,
        parentRecurringId: recurring.id,
        startDate: command.scheduledOccurrenceDate,
        endDate: command.scheduledOccurrenceDate,
      );
      expect(actuals.single.id, 'canonical-kill-actual');
      expect(actuals.single.date, command.paidDate);
      expect(actuals.single.recurringConfirmedAt, isNotNull);
      expect(container.read(appMutationErrorProvider), isNull);
    });
  }

  test('lost server response replays the same confirmation after SQLite reopen',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('recurring-timeout-');
    final path = '${directory.path}/local.sqlite';
    var database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path));
    var container = _container(database);
    addTearDown(() async {
      container.dispose();
      await database.close();
      await directory.delete(recursive: true);
    });
    final recurring = _recurring(householdId: null);
    final command = RecurringOccurrenceConfirmationCommand(
      userId: 'user_1',
      recurringTransaction: recurring,
      scheduledOccurrenceDate: recurring.date,
      paidDate: recurring.date,
      amountCents: 11760,
      accountId: 'wallet_usd',
    );
    String? firstBody;
    http.Response? committedResponse;
    var requests = 0;
    requestHandler = (request) async {
      requests += 1;
      firstBody = request.body;
      final local = await database
          .getTransactionByIdOrClientRecordId(command.optimisticId);
      committedResponse = http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'transaction':
                  local!.copyWith(id: 'canonical-timeout-actual').toJson()
            }
          }),
          200,
          headers: {'content-type': 'application/json'});
      throw const SocketException('response lost after server commit');
    };
    await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(command);
    await container.read(mobileOutboxDrainerProvider).drain();
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusFailed);
    container.dispose();
    await database.close();
    database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path));
    container = _container(database);
    requestHandler = (request) async {
      requests += 1;
      expect(jsonDecode(request.body), jsonDecode(firstBody!));
      return committedResponse!;
    };
    await database.deferMutation(command.idempotencyKey);
    await container.read(mobileOutboxDrainerProvider).drain();
    container.dispose();
    await database.close();
    database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path));
    container = _container(database);
    await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(command);
    await container.read(mobileOutboxDrainerProvider).drain();
    expect(requests, 2);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusSynced);
    expect(
        (await database
                .getTransactionByIdOrClientRecordId(command.optimisticId))
            ?.id,
        'canonical-timeout-actual');
    expect(container.read(appMutationErrorProvider), isNull);
  });

  test('legacy generic failure survives ten retries and SQLite reopens',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('recurring-outage-');
    final path = '${directory.path}/local.sqlite';
    var database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path));
    var container = _container(database);
    addTearDown(() async {
      container.dispose();
      await database.close();
      await directory.delete(recursive: true);
    });
    final recurring = _recurring(householdId: null);
    final command = RecurringOccurrenceConfirmationCommand(
      userId: 'user_1',
      recurringTransaction: recurring,
      scheduledOccurrenceDate: recurring.date,
      paidDate: recurring.date.subtract(const Duration(days: 1)),
      amountCents: 11760,
      accountId: 'wallet_usd',
    );
    requestHandler = (_) async => http.Response(
          jsonEncode({'success': false, 'code': 'OCCURRENCE_FAILED'}),
          400,
          headers: {'content-type': 'application/json'},
        );
    await container
        .read(recurringOccurrenceConfirmationProvider)
        .confirm(command);
    for (var attempt = 1; attempt <= 10; attempt++) {
      await container.read(mobileOutboxDrainerProvider).drain();
      final mutation = (await database.getOutboxMutations()).single;
      expect(mutation.status, localMutationStatusFailed);
      expect(mutation.attemptCount, attempt);
      expect(container.read(appMutationErrorProvider), isNull);
      container.dispose();
      await database.close();
      database = MonekoDatabase.fromExistingDatabaseForTesting(
          sqlite.sqlite3.open(path));
      container = _container(database);
      final restored = await database
          .getTransactionByIdOrClientRecordId(command.optimisticId);
      expect(
          restored?.scheduledOccurrenceDate, command.scheduledOccurrenceDate);
      expect(restored?.date, command.paidDate);
      await database.deferMutation(command.idempotencyKey);
    }
    final restored =
        await database.getTransactionByIdOrClientRecordId(command.optimisticId);
    var requests = 0;
    requestHandler = (_) async {
      requests += 1;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'transaction':
                restored!.copyWith(id: 'canonical-outage-actual').toJson(),
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    };
    await container.read(mobileOutboxDrainerProvider).drain();
    container.dispose();
    await database.close();
    database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open(path));
    container = _container(database);
    await container.read(mobileOutboxDrainerProvider).drain();
    expect(requests, 1);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusSynced);
    expect(
        (await database
                .getTransactionByIdOrClientRecordId(command.optimisticId))
            ?.id,
        'canonical-outage-actual');
    expect(container.read(appMutationErrorProvider), isNull);
  });

  for (final status in [200, 403]) {
    test(
        'HTTP $status terminal occurrence update rolls back instead of remaining queued',
        () async {
      final database = MonekoDatabase.inMemory();
      addTearDown(database.close);
      requestHandler = (request) async => http.Response(
            _terminalResponse(request).body,
            status,
            headers: {'content-type': 'application/json'},
          );
      final container = _container(database);
      addTearDown(container.dispose);
      final recurring = _recurring(householdId: 'household_1');
      final actual = _entry(recurring).copyWith(
        id: 'actual-occurrence-1',
        isRecurring: false,
        parentRecurringId: recurring.id,
        scheduledOccurrenceDate: DateTime(2026, 2, 1),
        amountCents: 8000,
      );
      await database.upsertTransactions([actual]);

      final result = await container
          .read(recurringOccurrenceUpdateProvider)
          .update(RecurringOccurrenceUpdateCommand(
            userId: 'user_1',
            recurringTransaction: recurring,
            occurrence: RecurringOccurrenceTimelineItem(
              occurrenceId: 'occurrence-1',
              scheduledOccurrenceDate: DateTime(2026, 2, 1),
              status: 'confirmed',
              actualTransaction: actual,
              amountCents: 8000,
              currency: 'USD',
            ),
            paidDate: DateTime(2026, 2, 2),
            amountCents: 9000,
            accountId: 'wallet_usd',
          ));

      expect(result.isQueued, isTrue);
      await _waitForAsync(() async {
        final mutation = (await database.getOutboxMutations()).single;
        return mutation.status == localMutationStatusCancelled;
      });

      final restored =
          await database.getTransactionByIdOrClientRecordId(actual.id);
      expect(restored?.amountCents, 8000);
      expect((await database.getOutboxMutations()).single.status,
          localMutationStatusCancelled);
    });
  }

  test('retryable recurring split failure remains queued and visible',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (_) => throw const SocketException('offline');
    final container = _container(database);
    addTearDown(container.dispose);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .saveRecurringExpense(
          userId: 'user_1',
          amount: 120,
          category: 'groceries',
          currency: 'USD',
          startDate: DateTime(2026, 2, 1),
          frequency: 'monthly',
          dueTime: '09:00:00',
          householdId: 'household_1',
          customSplitType: SplitType.amount,
          customSplits: _amountSplits(),
          payerUserId: 'user_1',
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final visible = container
        .read(recurringTransactionsProvider('household_1'))
        .data
        .requireValue;

    expect(saved, isNotNull);
    expect(saved?.currency, 'USD');
    expect(visible.single.id, saved?.id);
    expect(mutation.status, localMutationStatusQueued);
    expect(
      (payload['requestBody'] as Map<String, dynamic>)['customSplits'],
      _amountSplitPayload,
    );
  });

  test('household recurring income persists custom splits and payer', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    Map<String, dynamic>? capturedBody;
    requestHandler = (request) async {
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse(request, capturedBody!);
    };
    final container = _container(database);
    addTearDown(container.dispose);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .saveRecurringIncome(
          userId: 'user_1',
          amount: 120,
          category: 'income:salary',
          currency: 'USD',
          startDate: DateTime(2026, 2, 1),
          frequency: 'monthly',
          dueTime: '09:00:00',
          householdId: 'household_1',
          customSplitType: SplitType.amount,
          customSplits: _amountSplits(),
          payerUserId: 'user_2',
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final requestBody = payload['requestBody'] as Map<String, dynamic>;

    expect(saved?.type, 'income');
    expect(saved?.payerUserId, 'user_2');
    expect(requestBody['customSplits'], _amountSplitPayload);
    expect(requestBody['payerUserId'], 'user_2');
    expect(capturedBody?['customSplits'], _amountSplitPayload);
    expect((requestBody['recurrence_rule'] as Map)['due_time'], '09:00:00');
  });

  test('same-household recurring edit queues splitUpdate', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(
      householdId: 'household_1',
      splitGroupId: 'split_1',
      dueTime: '09:00:00',
    );
    await database.upsertTransactions([_entry(original)]);
    Map<String, dynamic>? capturedBody;
    requestHandler = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      capturedBody = body;
      return _successResponse(request, body);
    };
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider('household_1').notifier)
        .addRecurring(original);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateRecurringExpense(
          userId: 'user_1',
          expenseId: original.id,
          amount: 150,
          category: 'utilities',
          currency: 'USD',
          startDate: DateTime(2026, 3, 1),
          frequency: 'monthly',
          householdId: 'household_1',
          previousHouseholdId: 'household_1',
          customSplitType: SplitType.percentage,
          customSplits: _percentageSplits(),
          payerUserId: 'user_2',
          reSplitRequested: true,
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final extraBody = payload['extraBody'] as Map<String, dynamic>;

    expect(saved?.amount, 150);
    expect(saved?.payerUserId, 'user_2');
    expect(extraBody['splitUpdate'], _percentageSplitPayload);
    expect(extraBody['reSplitRequested'], isTrue);
    expect(extraBody, isNot(contains('customSplits')));
    expect(capturedBody?['reSplitRequested'], isTrue);
    expect(
      ((payload['updates'] as Map)['recurrence_rule'] as Map)['due_time'],
      '09:00:00',
    );
    expect(saved?.recurrenceRule?.dueTime, '09:00:00');
    expect(mutation.status, localMutationStatusSynced);
  });

  test('same-household recurring edit creates a missing split group', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(householdId: 'household_1');
    await database.upsertTransactions([_entry(original)]);
    requestHandler = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse(request, body);
    };
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider('household_1').notifier)
        .addRecurring(original);

    await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateRecurringExpense(
          userId: 'user_1',
          expenseId: original.id,
          amount: 100,
          category: 'housing',
          currency: 'USD',
          startDate: DateTime(2026, 2, 1),
          frequency: 'monthly',
          householdId: 'household_1',
          previousHouseholdId: 'household_1',
          customSplitType: SplitType.amount,
          customSplits: _amountSplits(),
          payerUserId: 'user_1',
          createSplitGroup: true,
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final extraBody = payload['extraBody'] as Map<String, dynamic>;
    expect(extraBody['customSplits'], _amountSplitPayload);
    expect(extraBody, isNot(contains('splitUpdate')));
  });

  test('same-household recurring income edit queues splitUpdate', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(
      householdId: 'household_1',
      type: 'income',
      category: 'income:salary',
      splitGroupId: 'split_income_1',
    );
    await database.upsertTransactions([_entry(original)]);
    Map<String, dynamic>? capturedBody;
    requestHandler = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      capturedBody = body;
      return _successResponse(request, body);
    };
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider('household_1').notifier)
        .addRecurring(original);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateRecurringIncome(
          userId: 'user_1',
          expenseId: original.id,
          amount: 150,
          category: 'income:salary',
          currency: 'USD',
          startDate: DateTime(2026, 3, 1),
          frequency: 'monthly',
          householdId: 'household_1',
          previousHouseholdId: 'household_1',
          customSplitType: SplitType.percentage,
          customSplits: _percentageSplits(),
          payerUserId: 'user_2',
          reSplitRequested: true,
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final extraBody = payload['extraBody'] as Map<String, dynamic>;

    expect(saved?.type, 'income');
    expect(saved?.payerUserId, 'user_2');
    expect(extraBody['splitUpdate'], _percentageSplitPayload);
    expect(extraBody['reSplitRequested'], isTrue);
    expect(extraBody, isNot(contains('customSplits')));
    expect(capturedBody?['reSplitRequested'], isTrue);
  });

  test('personal recurring edit moves to household and queues customSplits',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring();
    await database.upsertTransactions([_entry(original)]);
    requestHandler = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse(request, body);
    };
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider(null).notifier)
        .addRecurring(original);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateRecurringExpense(
          userId: 'user_1',
          expenseId: original.id,
          amount: 120,
          category: 'groceries',
          currency: 'USD',
          startDate: DateTime(2026, 2, 1),
          frequency: 'monthly',
          householdId: 'household_1',
          previousHouseholdId: null,
          customSplitType: SplitType.amount,
          customSplits: _amountSplits(),
          payerUserId: 'user_1',
          accountId: 'wallet_usd',
        );

    final personal =
        container.read(recurringTransactionsProvider(null)).data.requireValue;
    final household = container
        .read(recurringTransactionsProvider('household_1'))
        .data
        .requireValue;
    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final extraBody = payload['extraBody'] as Map<String, dynamic>;

    expect(saved?.householdId, 'household_1');
    expect(personal.where((item) => item.id == original.id), isEmpty);
    expect(household.single.id, original.id);
    expect(extraBody['customSplits'], _amountSplitPayload);
    expect(extraBody, isNot(contains('splitUpdate')));
  });

  test('household recurring edit moves to personal scope without split data',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(householdId: 'household_1');
    await database.upsertTransactions([_entry(original)]);
    requestHandler = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse(request, body);
    };
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider('household_1').notifier)
        .addRecurring(original);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateRecurringExpense(
          userId: 'user_1',
          expenseId: original.id,
          amount: 80,
          category: 'subscriptions',
          currency: 'USD',
          startDate: DateTime(2026, 4, 1),
          frequency: 'monthly',
          householdId: null,
          previousHouseholdId: 'household_1',
          accountId: 'wallet_usd',
        );

    final household = container
        .read(recurringTransactionsProvider('household_1'))
        .data
        .requireValue;
    final personal =
        container.read(recurringTransactionsProvider(null)).data.requireValue;
    final mutation = (await database.getOutboxMutations()).single;
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    final extraBody = payload['extraBody'] as Map<String, dynamic>;

    expect(saved?.householdId, isNull);
    expect(household, isEmpty);
    expect(personal.single.id, original.id);
    expect(extraBody, isNot(contains('customSplits')));
    expect(extraBody, isNot(contains('splitUpdate')));
  });

  test('terminal recurring split rejection restores SQLite and cancels outbox',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(householdId: 'household_1');
    await database.upsertTransactions([_entry(original)]);
    requestHandler = (request) async => http.Response(
          jsonEncode({
            'success': false,
            'error': 'Split total does not match amount',
            'code': 'VALIDATION_ERROR',
            'status': 400,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider('household_1').notifier)
        .addRecurring(original);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateRecurringExpense(
          userId: 'user_1',
          expenseId: original.id,
          amount: 150,
          category: 'utilities',
          currency: 'USD',
          startDate: DateTime(2026, 3, 1),
          frequency: 'monthly',
          householdId: 'household_1',
          previousHouseholdId: 'household_1',
          customSplitType: SplitType.percentage,
          customSplits: _percentageSplits(),
          payerUserId: 'user_2',
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final localRows = await database.getRecurringTransactions(
      userId: 'user_1',
      householdId: 'household_1',
    );
    final visible = container
        .read(recurringTransactionsProvider('household_1'))
        .data
        .requireValue
        .single;

    expect(saved, isNull);
    expect(visible.amount, original.amount);
    expect(visible.category, original.category);
    expect(localRows.single.amountCents, 10000);
    expect(localRows.single.category, 'housing');
    expect(mutation.status, localMutationStatusCancelled);
  });

  test('terminal recurring income split rejection restores local state',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(
      householdId: 'household_1',
      type: 'income',
      category: 'income:salary',
    );
    await database.upsertTransactions([_entry(original)]);
    requestHandler = (request) async => _terminalResponse(request);
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider('household_1').notifier)
        .addRecurring(original);

    final saved = await container
        .read(recurringTransactionSaveProvider.notifier)
        .updateRecurringIncome(
          userId: 'user_1',
          expenseId: original.id,
          amount: 150,
          category: 'income:salary',
          currency: 'USD',
          startDate: DateTime(2026, 3, 1),
          frequency: 'monthly',
          householdId: 'household_1',
          previousHouseholdId: 'household_1',
          customSplitType: SplitType.percentage,
          customSplits: _percentageSplits(),
          payerUserId: 'user_2',
          accountId: 'wallet_usd',
        );

    final mutation = (await database.getOutboxMutations()).single;
    final localRows = await database.getRecurringTransactions(
      userId: 'user_1',
      householdId: 'household_1',
    );
    final visible = container
        .read(recurringTransactionsProvider('household_1'))
        .data
        .requireValue
        .single;

    expect(saved, isNull);
    expect(visible.amount, original.amount);
    expect(localRows.single.amountCents, 10000);
    expect(localRows.single.type, 'income');
    expect(mutation.status, localMutationStatusCancelled);
  });

  test('older rejected recurring edit cannot overwrite a newer pending edit',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(householdId: 'household_1');
    await database.upsertTransactions([_entry(original)]);
    final requests = <http.Request>[];
    final responses = <Completer<http.Response>>[];
    requestHandler = (request) {
      requests.add(request);
      final response = Completer<http.Response>();
      responses.add(response);
      return response.future;
    };
    final container = _container(database);
    addTearDown(container.dispose);
    container
        .read(recurringTransactionsProvider('household_1').notifier)
        .addRecurring(original);
    final notifier = container.read(recurringTransactionSaveProvider.notifier);

    final olderUpdate = notifier.updateRecurringExpense(
      userId: 'user_1',
      expenseId: original.id,
      amount: 120,
      category: 'utilities',
      currency: 'USD',
      startDate: DateTime(2026, 3, 1),
      frequency: 'monthly',
      householdId: 'household_1',
      previousHouseholdId: 'household_1',
      customSplitType: SplitType.percentage,
      customSplits: _percentageSplits(),
      payerUserId: 'user_1',
      accountId: 'wallet_usd',
    );
    await _waitFor(() => responses.length == 1);

    final newerUpdate = notifier.updateRecurringExpense(
      userId: 'user_1',
      expenseId: original.id,
      amount: 180,
      category: 'utilities',
      currency: 'USD',
      startDate: DateTime(2026, 3, 1),
      frequency: 'monthly',
      householdId: 'household_1',
      previousHouseholdId: 'household_1',
      customSplitType: SplitType.percentage,
      customSplits: _percentageSplits(),
      payerUserId: 'user_1',
      accountId: 'wallet_usd',
    );
    await _waitFor(() => responses.length == 2);

    responses[0].complete(_terminalResponse(requests[0]));
    expect(await olderUpdate, isNull);

    final visibleAfterOlderFailure = container
        .read(recurringTransactionsProvider('household_1'))
        .data
        .requireValue
        .single;
    final localAfterOlderFailure = await database.getRecurringTransactions(
      userId: 'user_1',
      householdId: 'household_1',
    );
    expect(visibleAfterOlderFailure.amount, 180);
    expect(localAfterOlderFailure.single.amountCents, 18000);

    final newerBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
    responses[1].complete(_successResponse(requests[1], newerBody));
    expect((await newerUpdate)?.amount, 180);
  });
}

ProviderContainer _container(MonekoDatabase database,
    {bool personalWalletTest = false}) {
  return ProviderContainer(
    overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        HouseholdScope(
          viewMode: personalWalletTest ? ViewMode.personal : ViewMode.household,
          selected: SelectedHouseholdState(
              householdId: personalWalletTest ? null : 'household_1'),
          portfolioHouseholdIds: const {},
        ),
      ),
      if (personalWalletTest) ...[
        networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
        currencyRateTableProvider.overrideWith((ref) async => CurrencyRateTable(
            baseCurrency: 'CAD',
            rates: const {'CAD': 1},
            fetchedAt: DateTime.now())),
        transactionsFeedServiceProvider
            .overrideWithValue(_RecurringDatabaseFeed(database)),
      ],
    ],
  );
}

class _RecurringDatabaseFeed extends EmptyTransactionsFeedService {
  const _RecurringDatabaseFeed(this.database);
  final MonekoDatabase database;
  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) =>
      database.getTransactionsByScheduledOccurrenceRange(
          userId: query.userId,
          householdId: query.householdId,
          parentRecurringId: 'recurring_1',
          startDate: DateTime(2000),
          endDate: DateTime(9999));
}

List<MemberSplit> _amountSplits() => [
      MemberSplit(member: _member('user_1'), amount: 70),
      MemberSplit(member: _member('user_2'), amount: 50),
    ];

List<MemberSplit> _percentageSplits() => [
      MemberSplit(member: _member('user_1'), percentage: 60),
      MemberSplit(member: _member('user_2'), percentage: 40),
    ];

HouseholdMember _member(String userId) {
  final now = DateTime(2026, 1, 1);
  return HouseholdMember(
    id: 'member_$userId',
    householdId: 'household_1',
    userId: userId,
    role: HouseholdRole.member,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

RecurringTransaction _recurring({
  String? householdId,
  String type = 'expense',
  String category = 'housing',
  String? splitGroupId,
  String? dueTime,
  DateTime? date,
}) {
  final resolvedDate = date ?? DateTime(2026, 2, 1);
  return RecurringTransaction(
    id: 'recurring_1',
    userId: 'user_1',
    date: resolvedDate,
    category: category,
    description: 'Rent',
    amount: 100,
    currency: 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    householdId: householdId,
    payerUserId: householdId == null ? null : 'user_1',
    splitGroupId: splitGroupId,
    accountId: 'wallet_usd',
    recurrenceRule: RecurrenceRule(
      frequency: 'monthly',
      anchorDate: resolvedDate,
      dueTime: dueTime,
    ),
    type: type,
    attachments: const [],
    createdAt: resolvedDate,
    updatedAt: resolvedDate,
  );
}

ExpenseEntry _entry(RecurringTransaction recurring) {
  return ExpenseEntry(
    id: recurring.id,
    userId: recurring.userId!,
    householdId: recurring.householdId,
    date: recurring.date,
    amountCents: (recurring.amount * 100).round(),
    currency: recurring.currency,
    category: recurring.category,
    createdAt: recurring.createdAt,
    rawText: recurring.description,
    walletId: recurring.accountId,
    type: recurring.type,
    isRecurring: true,
    recurrenceRuleJson: recurring.recurrenceRule?.toJson(),
  );
}

http.Response _successResponse(
  http.Request request,
  Map<String, dynamic> body,
) {
  final updates = body['updates'] as Map<String, dynamic>?;
  final amount = updates == null
      ? (body['amount'] as num).toDouble()
      : (updates['amount_cents'] as num).toDouble() / 100;
  final recurrenceRule = updates?['recurrence_rule'] ?? body['recurrence_rule'];
  final category = updates?['category'] ?? body['category'];
  final type = category.toString().startsWith('income:') ? 'income' : 'expense';
  return http.Response(
    jsonEncode({
      'success': true,
      'data': {
        'id': body['expenseId'] ?? body['clientRecordId'],
        'user_id': body['userId'],
        'date': updates?['date'] ?? body['date'],
        'category': category,
        'description': updates?['raw_text'] ?? body['description'],
        'merchant': updates?['merchant'] ?? body['merchant'],
        'amount': amount,
        'currency': updates?['currency'] ?? body['currency'],
        'owner_type': body['ownerType'] ?? 'me',
        'privacy_scope': body['privacyScope'] ?? 'full',
        'household_id': updates?['household_id'] ?? body['householdId'],
        'payer_user_id': updates?['payer_user_id'] ?? body['payerUserId'],
        'account_id': updates?['account_id'] ?? body['accountId'],
        'recurrence_rule': recurrenceRule,
        'type': type,
        'created_at': '2026-02-01T00:00:00.000Z',
        'updated_at': '2026-02-02T00:00:00.000Z',
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

http.Response _terminalResponse(http.Request request) => http.Response(
      jsonEncode({
        'success': false,
        'error': 'Split total does not match amount',
        'code': 'VALIDATION_ERROR',
        'status': 400,
      }),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

Future<void> _waitForAsync(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for asynchronous condition');
}

const _amountSplitPayload = {
  'splitType': 'amount',
  'memberSplits': [
    {'userId': 'user_1', 'amount': 70.0},
    {'userId': 'user_2', 'amount': 50.0},
  ],
};

const _percentageSplitPayload = {
  'splitType': 'percentage',
  'memberSplits': [
    {'userId': 'user_1', 'percentage': 60.0},
    {'userId': 'user_2', 'percentage': 40.0},
  ],
};
