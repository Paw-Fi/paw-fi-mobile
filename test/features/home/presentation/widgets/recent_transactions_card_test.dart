import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/sync/application/sync_queue_controller.dart';
import 'package:moneko/core/sync/data/sync_providers.dart';
import 'package:moneko/core/sync/data/sync_queue_service.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/recent_transactions_card.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/transactions/data/transaction_providers.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';
import 'package:moneko/features/transactions/domain/transaction_repository.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _FakeTransactionRepository implements TransactionRepository {
  final reviewedIds = <String>[];

  @override
  Future<String> createLocalTransaction(CreateTransactionCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<List<LocalTransactionRecord>> needsReviewTransactions({
    required String userId,
    String? householdId,
    int limit = 50,
  }) async {
    return const <LocalTransactionRecord>[];
  }

  @override
  Future<void> markTransactionReviewed(String transactionId) async {
    reviewedIds.add(transactionId);
  }

  @override
  Future<void> updateReviewCategory({
    required String transactionId,
    required String category,
  }) async {}
}

class _FakeSyncQueueProcessor implements SyncQueueProcessor {
  var callCount = 0;

  @override
  Future<SyncQueueProcessResult> processPendingOperations({
    int limit = 20,
  }) async {
    callCount += 1;
    return const SyncQueueProcessResult(
      processed: 1,
      succeeded: 1,
      failed: 0,
    );
  }
}

void main() {
  Future<double> pumpCardAndMeasureHeight(
    WidgetTester tester,
    List<ExpenseEntry> expenses,
  ) async {
    const cardKey = Key('recent-transactions-card-under-test');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingRecurringTransactionProvider(
            const UpcomingRecurringScope(householdId: null, currency: 'USD'),
          ).overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 390,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: KeyedSubtree(
                      key: cardKey,
                      child: buildRecentTransactionsCard(
                        context,
                        Theme.of(context).colorScheme,
                        expenses,
                        null,
                        selectedCurrency: 'USD',
                        onViewAll: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    return tester.getSize(find.byKey(cardKey)).height;
  }

  ExpenseEntry entry(String id, int day) {
    return ExpenseEntry(
      id: id,
      date: DateTime(2026, 4, day),
      amountCents: 1200,
      createdAt: DateTime(2026, 4, day, 12),
      type: 'expense',
      category: 'food',
      currency: 'USD',
      rawText: 'Lunch',
    );
  }

  testWidgets(
    'empty recent transactions card reserves the populated dashboard footprint',
    (tester) async {
      final emptyHeight = await pumpCardAndMeasureHeight(
        tester,
        const <ExpenseEntry>[],
      );
      final populatedHeight = await pumpCardAndMeasureHeight(
        tester,
        List.generate(5, (index) => entry('tx_$index', index + 1)),
      );

      expect(emptyHeight, greaterThanOrEqualTo(populatedHeight));
    },
  );

  testWidgets('recent transactions card shows upcoming recurring banner', (
    tester,
  ) async {
    final upcoming = UpcomingRecurringTransaction(
      transaction: RecurringTransaction(
        id: 'rec_1',
        date: DateTime(2026, 1, 10),
        category: 'insurance',
        description: 'Insurance renewal',
        amount: 120.0,
        currency: 'USD',
        ownerType: 'me',
        privacyScope: 'full',
        recurrenceRule: RecurrenceRule(
          frequency: 'monthly',
          anchorDate: DateTime(2026, 1, 10),
          interval: 6,
        ),
        type: 'expense',
        attachments: const [],
        createdAt: DateTime(2026, 1, 1),
      ),
      nextOccurrence: DateTime(2026, 7, 10),
      daysUntil: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingRecurringTransactionProvider(
            const UpcomingRecurringScope(householdId: null, currency: 'USD'),
          ).overrideWithValue(upcoming),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: buildRecentTransactionsCard(
                context,
                Theme.of(context).colorScheme,
                const <ExpenseEntry>[],
                null,
                selectedCurrency: 'USD',
                onViewAll: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.upcomingBills), findsOneWidget);
    expect(find.text('Insurance renewal'), findsOneWidget);
    expect(find.text(l10n.inDays(2)), findsOneWidget);
    expect(find.text(l10n.noTransactionsFound), findsNothing);
  });

  testWidgets('recent transactions card surfaces local sync status', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingRecurringTransactionProvider(
            const UpcomingRecurringScope(householdId: null, currency: 'USD'),
          ).overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: buildRecentTransactionsCard(
                context,
                Theme.of(context).colorScheme,
                [
                  entry('review_tx', 30).copyWith(syncStatus: 'needsReview'),
                  entry('failed_tx', 29).copyWith(syncStatus: 'failed'),
                ],
                null,
                selectedCurrency: 'USD',
                onViewAll: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.confirm), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets('needs review row opens review sheet and can be confirmed', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository();
    final syncProcessor = _FakeSyncQueueProcessor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingRecurringTransactionProvider(
            const UpcomingRecurringScope(householdId: null, currency: 'USD'),
          ).overrideWithValue(null),
          transactionRepositoryProvider.overrideWithValue(repository),
          syncConnectivityProvider.overrideWith((ref) => const Stream.empty()),
          syncQueueProcessorProvider.overrideWithValue(syncProcessor),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: buildRecentTransactionsCard(
                context,
                Theme.of(context).colorScheme,
                [
                  entry('review_tx', 30).copyWith(
                    syncStatus: 'needsReview',
                    reviewReasons: const ['lowConfidence'],
                  ),
                ],
                null,
                selectedCurrency: 'USD',
                onViewAll: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.confirm), findsOneWidget);

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.confirmExpense), findsOneWidget);

    await tester.tap(find.text(l10n.confirm).last);
    await tester.pumpAndSettle();

    expect(repository.reviewedIds, ['review_tx']);
    expect(syncProcessor.callCount, 1);
  });
}
