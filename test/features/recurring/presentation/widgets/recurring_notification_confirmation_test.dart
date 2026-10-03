import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/confirm_recurring_occurrence_sheet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';

class _Series extends RecurringSeriesDetailNotifier {
  _Series(this.transaction);
  final RecurringTransaction transaction;
  @override
  Future<RecurringTransaction> build(RecurringSeriesDetailQuery arg) async =>
      transaction;
}

class _History extends RecurringOccurrenceHistoryNotifier {
  _History(this.result, this.expectedQuery);
  final Future<RecurringOccurrenceHistoryState> result;
  final RecurringOccurrenceHistoryQuery expectedQuery;
  void publish(RecurringOccurrenceHistoryState value) =>
      state = AsyncData(value);
  void failRefresh() => state = AsyncError<RecurringOccurrenceHistoryState>(
          StateError('offline'), StackTrace.current)
      .copyWithPrevious(state);
  @override
  Future<RecurringOccurrenceHistoryState> build(
      RecurringOccurrenceHistoryQuery arg) {
    expect(arg, expectedQuery);
    return result;
  }
}

void main() {
  final date = DateTime(2026, 9, 30);
  final transaction = RecurringTransaction(
    id: 'series-1',
    date: date,
    category: 'housing',
    amount: 123,
    currency: 'EUR',
    ownerType: 'household',
    privacyScope: 'full',
    householdId: 'space-1',
    type: 'expense',
    attachments: const [],
    createdAt: date,
    recurrenceRule: RecurrenceRule(frequency: 'monthly', anchorDate: date),
  );
  final query = RecurringOccurrenceHistoryQuery(
    userId: 'user-1',
    recurringId: 'series-1',
    beforeScheduledDate: DateTime(2026, 10, 1),
    pageSize: 1,
  );
  final materialization = RecurringOccurrenceMaterializationQuery(
    userId: 'user-1',
    householdId: 'space-1',
    recurringId: 'series-1',
    scheduledOccurrenceDate: date,
  );

  Future<void> open(
      WidgetTester tester, Future<RecurringOccurrenceHistoryState> history,
      {bool materialized = false,
      void Function(_History)? captureHistory}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recurringSeriesDetailProvider.overrideWith(() => _Series(transaction)),
        recurringOccurrenceHistoryProvider.overrideWith(() {
          final notifier = _History(history, query);
          captureHistory?.call(notifier);
          return notifier;
        }),
        recurringOccurrenceMaterializedProvider(materialization)
            .overrideWith((ref) async => materialized),
        walletsByCurrencyProvider(const WalletsCurrencyQuery(
                householdId: 'space-1', currency: 'EUR'))
            .overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
            builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () => showConfirmRecurringOccurrenceSheetById(
                      context: context,
                      userId: 'user-1',
                      recurringId: 'series-1',
                      scheduledOccurrenceDate: date,
                    ),
                    child: const Text('Open'),
                  ),
                )),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  RecurringOccurrenceHistoryState state(String status,
          {bool refreshing = false}) =>
      RecurringOccurrenceHistoryState(
        items: [
          RecurringOccurrenceSummary.fromJson({
            'id': 'occurrence-1',
            'recurring_id': 'series-1',
            'scheduled_occurrence_date': '2026-09-30',
            'status': status,
          })
        ],
        hasMore: false,
        nextCursor: null,
        isRefreshing: refreshing,
      );

  testWidgets('notification waits for occurrence status before showing amounts',
      (tester) async {
    final response = Completer<RecurringOccurrenceHistoryState>();
    await open(tester, response.future);
    expect(find.byWidgetPredicate((widget) => widget is Skeletonizer),
        findsOneWidget);
    expect(find.text('€123.00'), findsNothing);
    response.complete(state('pending'));
    await tester.pumpAndSettle();
    expect(find.text('€123.00'), findsOneWidget);
    expect(find.text('Date paid'), findsOneWidget);
    expect(find.text('Scheduled date'), findsOneWidget);
  });

  for (final status in ['confirmed', 'skipped']) {
    testWidgets('cached pending stays non-actionable until fresh $status state',
        (tester) async {
      late _History history;
      await open(tester, Future.value(state('pending', refreshing: true)),
          captureHistory: (notifier) => history = notifier);
      await tester.pump();
      final blocker =
          find.byKey(const ValueKey('notification-occurrence-revalidation'));
      expect(tester.widget<AbsorbPointer>(blocker).absorbing, isTrue);
      history.publish(state(status));
      await tester.pumpAndSettle();
      expect(find.text('Date paid'), findsNothing);
    });

    testWidgets('stale $status notification cannot offer confirmation',
        (tester) async {
      await open(tester, Future.value(state(status)));
      await tester.pumpAndSettle();
      expect(find.text('€123.00'), findsNothing);
      expect(find.text('Date paid'), findsNothing);
    });
  }

  testWidgets(
      'a local materialized confirmation suppresses a stale pending read',
      (tester) async {
    await open(tester, Future.value(state('pending')), materialized: true);
    await tester.pumpAndSettle();
    expect(find.text('€123.00'), findsNothing);
    expect(find.text('Date paid'), findsNothing);
  });

  testWidgets('failed occurrence read offers retry instead of confirmation',
      (tester) async {
    final response = Completer<RecurringOccurrenceHistoryState>();
    await open(tester, response.future);
    response.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('€123.00'), findsNothing);
  });

  testWidgets(
      'cached refresh failure retains amounts with a blocked form and retry',
      (tester) async {
    late _History history;
    await open(tester, Future.value(state('pending', refreshing: true)),
        captureHistory: (notifier) => history = notifier);
    history.failRefresh();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('€123.00'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
        tester
            .widget<AbsorbPointer>(find
                .byKey(const ValueKey('notification-occurrence-revalidation')))
            .absorbing,
        isTrue);
  });
}
