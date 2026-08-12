import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

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
          description: 'Household groceries',
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
    expect(localRows.single.walletId, 'wallet_usd');
    expect(mutation.operation, 'create');
    expect(mutation.status, localMutationStatusSynced);
    expect(requestBody['payerUserId'], 'user_2');
    expect(requestBody['customSplits'], _amountSplitPayload);
    expect(capturedBody?['customSplits'], _amountSplitPayload);
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

  test(
      'current-month occurrence edit adjusts the recurring header before replay',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    requestHandler = (_) => throw const SocketException('offline');
    final container = _container(database);
    addTearDown(container.dispose);
    final recurring = _recurring(
      householdId: 'household_1',
      date: DateTime(2026, 8, 1),
    );
    final actual = _entry(recurring).copyWith(
      id: 'actual-occurrence-1',
      isRecurring: false,
      parentRecurringId: recurring.id,
      scheduledOccurrenceDate: DateTime(2026, 8, 1),
      amountCents: 8000,
    );

    final result = await container
        .read(recurringOccurrenceUpdateProvider)
        .update(RecurringOccurrenceUpdateCommand(
          userId: 'user_1',
          recurringTransaction: recurring,
          occurrence: RecurringOccurrenceTimelineItem(
            occurrenceId: 'occurrence-1',
            scheduledOccurrenceDate: DateTime(2026, 8, 1),
            status: 'confirmed',
            actualTransaction: actual,
            amountCents: 8000,
            currency: 'USD',
          ),
          paidDate: DateTime(2026, 8, 1),
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
          nextOccurrenceDate: DateTime(2026, 9, 1),
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
  });

  test('same-household recurring edit queues splitUpdate', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _recurring(
      householdId: 'household_1',
      splitGroupId: 'split_1',
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

ProviderContainer _container(MonekoDatabase database) {
  return ProviderContainer(
    overrides: [
      localDatabaseProvider.overrideWith((ref) async => database),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.household,
          selected: SelectedHouseholdState(householdId: 'household_1'),
          portfolioHouseholdIds: {},
        ),
      ),
    ],
  );
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
