import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockFunctionResponse extends Mock implements FunctionResponse {}

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

class _FakeAnalyticsNotifier extends AnalyticsNotifier {
  _FakeAnalyticsNotifier(super.ref) : super() {
    state = AnalyticsData(allExpenses: const []);
  }

  String? loadedUserId;

  @override
  Future<void> loadData(
    String userId, {
    int retryCount = 0,
    bool forceReload = false,
  }) async {
    loadedUserId = userId;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  ProviderContainer createContainer({
    required SupabaseClient supabaseClient,
    required void Function(_FakeAnalyticsNotifier notifier)
        onAnalyticsNotifierCreated,
    MonekoDatabase? database,
  }) {
    return ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'user-1', email: 'user@test.com')),
        ),
        analyticsProvider.overrideWith((ref) {
          final notifier = _FakeAnalyticsNotifier(ref);
          onAnalyticsNotifierCreated(notifier);
          return notifier;
        }),
        transactionEditSupabaseClientProvider.overrideWithValue(supabaseClient),
        if (database != null)
          localDatabaseProvider.overrideWith((ref) async => database),
      ],
    );
  }

  group('TransactionEditNotifier.updateExpense', () {
    late _MockSupabaseClient supabaseClient;
    late _MockFunctionsClient functionsClient;
    _FakeAnalyticsNotifier? analyticsNotifier;

    setUp(() {
      supabaseClient = _MockSupabaseClient();
      functionsClient = _MockFunctionsClient();
      analyticsNotifier = null;
      when(() => supabaseClient.functions).thenReturn(functionsClient);
    });

    test(
      'keeps the save successful when category retry throws after primary success',
      () async {
        final primaryResponse = _MockFunctionResponse();
        when(() => primaryResponse.data).thenReturn({
          'success': true,
          'data': {'category': 'food'},
        });

        var callCount = 0;
        final requestBodies = <Map<String, dynamic>>[];
        when(
          () => functionsClient.invoke(
            'update-expense',
            body: any(named: 'body'),
          ),
        ).thenAnswer((invocation) async {
          callCount += 1;
          requestBodies.add(
            Map<String, dynamic>.from(
              invocation.namedArguments[#body] as Map<String, dynamic>,
            ),
          );
          if (callCount == 1) {
            return primaryResponse;
          }
          throw Exception('retry failed');
        });

        final container = createContainer(
          supabaseClient: supabaseClient,
          onAnalyticsNotifierCreated: (notifier) =>
              analyticsNotifier = notifier,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(transactionEditProvider.notifier)
            .updateExpense('expense-1', {
          'category': 'comida y bebidas',
          'raw_text': 'Transferencia a Alcides Ruiz por Asaditos',
        });

        final state = container.read(transactionEditProvider);
        expect(result, isTrue);
        expect(state.error, isNull);
        expect(state.isLoading, isFalse);
        expect(analyticsNotifier?.loadedUserId, 'user-1');
        expect(callCount, 2);
        expect(requestBodies.first['clientRecordId'], 'expense-1');
        expect(
          requestBodies.first['clientMutationId'],
          startsWith('mobile:update_transaction_expense-1_'),
        );
        expect(
          requestBodies.first['idempotencyKey'],
          requestBodies.first['clientMutationId'],
        );
        expect(
          (requestBodies.first['updates'] as Map<String, dynamic>).keys,
          containsAll(<String>['category', 'raw_text']),
        );
        expect(
          (requestBodies.last['updates'] as Map<String, dynamic>).keys,
          <String>['category'],
        );
      },
    );

    test(
      'keeps the save successful when category retry returns an error payload',
      () async {
        final primaryResponse = _MockFunctionResponse();
        when(() => primaryResponse.data).thenReturn({
          'success': true,
          'data': {'category': 'food'},
        });

        final retryResponse = _MockFunctionResponse();
        when(() => retryResponse.data).thenReturn({
          'success': false,
          'error': 'retry failed',
          'code': 'SERVER_ERROR',
          'data': {'category': 'food'},
        });

        var callCount = 0;
        final requestBodies = <Map<String, dynamic>>[];
        when(
          () => functionsClient.invoke(
            'update-expense',
            body: any(named: 'body'),
          ),
        ).thenAnswer((invocation) async {
          callCount += 1;
          requestBodies.add(
            Map<String, dynamic>.from(
              invocation.namedArguments[#body] as Map<String, dynamic>,
            ),
          );
          return callCount == 1 ? primaryResponse : retryResponse;
        });

        final container = createContainer(
          supabaseClient: supabaseClient,
          onAnalyticsNotifierCreated: (notifier) =>
              analyticsNotifier = notifier,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(transactionEditProvider.notifier)
            .updateExpense('expense-1', {
          'category': 'comida y bebidas',
          'raw_text': 'Transferencia a Alcides Ruiz por Asaditos',
        });

        final state = container.read(transactionEditProvider);
        expect(result, isTrue);
        expect(state.error, isNull);
        expect(state.isLoading, isFalse);
        expect(analyticsNotifier?.loadedUserId, 'user-1');
        expect(callCount, 2);
        expect(
          (requestBodies.first['updates'] as Map<String, dynamic>).keys,
          containsAll(<String>['category', 'raw_text']),
        );
        expect(
          (requestBodies.last['updates'] as Map<String, dynamic>).keys,
          <String>['category'],
        );
      },
    );

    test('returns failure when the primary update response is unsuccessful',
        () async {
      final failedResponse = _MockFunctionResponse();
      when(() => failedResponse.data).thenReturn({
        'success': false,
        'error': 'Failed to update expense',
        'code': 'SERVER_ERROR',
      });

      when(
        () => functionsClient.invoke(
          'update-expense',
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => failedResponse);

      final container = createContainer(
        supabaseClient: supabaseClient,
        onAnalyticsNotifierCreated: (notifier) => analyticsNotifier = notifier,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(transactionEditProvider.notifier)
          .updateExpense('expense-1', {
        'category': 'comida y bebidas',
        'raw_text': 'Transferencia a Alcides Ruiz por Asaditos',
      });

      final state = container.read(transactionEditProvider);
      expect(result, isFalse);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
      expect(analyticsNotifier?.loadedUserId, isNull);
      verify(
        () => functionsClient.invoke(
          'update-expense',
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test(
      'updates cached receipt URL and refreshes transaction feed after receipt replacement',
      () async {
        final successResponse = _MockFunctionResponse();
        when(() => successResponse.data).thenReturn({
          'success': true,
          'data': {'receipt_image_url': 'https://example.com/new.jpg'},
        });

        when(
          () => functionsClient.invoke(
            'update-expense',
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => successResponse);

        final container = createContainer(
          supabaseClient: supabaseClient,
          onAnalyticsNotifierCreated: (notifier) =>
              analyticsNotifier = notifier,
        );
        addTearDown(container.dispose);

        container.read(analyticsProvider);
        analyticsNotifier!.state = AnalyticsData(
          expenses: [
            ExpenseEntry(
              id: 'expense-1',
              date: DateTime(2026, 4, 29),
              amountCents: 1299,
              createdAt: DateTime(2026, 4, 29, 12),
              receiptImageUrl: 'https://example.com/old.jpg',
            ),
          ],
          allExpenses: [
            ExpenseEntry(
              id: 'expense-1',
              date: DateTime(2026, 4, 29),
              amountCents: 1299,
              createdAt: DateTime(2026, 4, 29, 12),
              receiptImageUrl: 'https://example.com/old.jpg',
            ),
          ],
        );

        final originalFeedSignal =
            container.read(transactionsFeedRefreshSignalProvider);

        final result = await container
            .read(transactionEditProvider.notifier)
            .updateExpense('expense-1', {
          'receipt_image_url': 'https://example.com/new.jpg',
        });

        expect(result, isTrue);
        expect(
          container.read(analyticsProvider).allExpenses.single.receiptImageUrl,
          'https://example.com/new.jpg',
        );
        expect(
          container.read(transactionsFeedRefreshSignalProvider),
          originalFeedSignal + 1,
        );
      },
    );

    test(
      'applies household expense optimistic overlay while backend update is in flight',
      () async {
        final successResponse = _MockFunctionResponse();
        when(() => successResponse.data).thenReturn({
          'success': true,
          'data': {'category': 'groceries'},
        });

        final responseCompleter = Completer<FunctionResponse>();
        when(
          () => functionsClient.invoke(
            'update-expense',
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => responseCompleter.future);

        final container = createContainer(
          supabaseClient: supabaseClient,
          onAnalyticsNotifierCreated: (notifier) =>
              analyticsNotifier = notifier,
        );
        addTearDown(container.dispose);

        final original = ExpenseEntry(
          id: 'household-expense-1',
          userId: 'user-1',
          householdId: 'household-1',
          date: DateTime(2026, 5, 7),
          amountCents: 1200,
          currency: 'USD',
          category: 'food',
          createdAt: DateTime(2026, 5, 7, 10),
          type: 'expense',
        );

        final updateFuture =
            container.read(transactionEditProvider.notifier).updateExpense(
                  original.id,
                  {'category': 'groceries'},
                  originalExpense: original,
                );

        await Future<void>.delayed(Duration.zero);

        final optimistic = container.read(householdOptimisticExpensesProvider);
        expect(
          optimistic['household-1']?.single.category,
          'groceries',
        );

        responseCompleter.complete(successResponse);
        expect(await updateFuture, isTrue);
      },
    );

    test('writes optimistic update metadata to local outbox', () async {
      final database = MonekoDatabase.inMemory();
      addTearDown(database.close);

      final original = ExpenseEntry(
        id: 'expense-1',
        userId: 'user-1',
        date: DateTime(2026, 5, 7),
        amountCents: 1200,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime(2026, 5, 7, 10),
        type: 'expense',
      );
      final updated = original.copyWith(amountCents: 1500);
      await database.upsertTransactions([original]);

      final successResponse = _MockFunctionResponse();
      when(() => successResponse.data).thenReturn({
        'success': true,
        'data': updated.toJson(),
      });

      final requestBodies = <Map<String, dynamic>>[];
      when(
        () => functionsClient.invoke(
          'update-expense',
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        requestBodies.add(
          Map<String, dynamic>.from(
            invocation.namedArguments[#body] as Map<String, dynamic>,
          ),
        );
        return successResponse;
      });

      final container = createContainer(
        supabaseClient: supabaseClient,
        onAnalyticsNotifierCreated: (notifier) => analyticsNotifier = notifier,
        database: database,
      );
      addTearDown(container.dispose);

      container.read(analyticsProvider);
      analyticsNotifier!.state = AnalyticsData(
        expenses: [original],
        allExpenses: [original],
      );

      final result = await container
          .read(transactionEditProvider.notifier)
          .updateExpense('expense-1', {'amount_cents': 1500});

      final mutations = await database.getOutboxMutations();
      final localRows = await database.getRecentTransactions(
        userId: 'user-1',
        householdId: null,
      );

      expect(result, isTrue);
      expect(requestBodies.single['clientRecordId'], 'expense-1');
      expect(mutations.single.operation, 'update_transaction');
      expect(mutations.single.status, localMutationStatusSynced);
      expect(localRows.single.amountCents, 1500);
    });

    test(
        'delete removes personal transaction immediately and rolls back on failure',
        () async {
      final failedResponse = _MockFunctionResponse();
      when(() => failedResponse.data).thenReturn({
        'success': false,
        'error': 'network failed',
      });

      final responseCompleter = Completer<FunctionResponse>();
      when(
        () => functionsClient.invoke(
          'delete-expense',
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) => responseCompleter.future);

      final container = createContainer(
        supabaseClient: supabaseClient,
        onAnalyticsNotifierCreated: (notifier) => analyticsNotifier = notifier,
      );
      addTearDown(container.dispose);

      final original = ExpenseEntry(
        id: 'expense-1',
        userId: 'user-1',
        date: DateTime(2026, 5, 7),
        amountCents: 1200,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime(2026, 5, 7, 10),
        type: 'expense',
      );

      container.read(analyticsProvider);
      analyticsNotifier!.state = AnalyticsData(
        expenses: [original],
        allExpenses: [original],
      );

      final deleteFuture = container
          .read(transactionEditProvider.notifier)
          .deleteExpensesOptimistically([original]);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(analyticsProvider).allExpenses, isEmpty);

      responseCompleter.complete(failedResponse);
      expect(await deleteFuture, isFalse);
      expect(
          container.read(analyticsProvider).allExpenses.single.id, 'expense-1');
    });
  });
}
