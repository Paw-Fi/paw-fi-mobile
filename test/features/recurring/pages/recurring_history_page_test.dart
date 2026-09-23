import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/pages/recurring_history_page.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');
}

class _TestAnalyticsNotifier extends AnalyticsNotifier {
  _TestAnalyticsNotifier(super.ref) {
    state = AnalyticsData();
  }
}

class _TestHistoryNotifier extends RecurringOccurrenceHistoryNotifier {
  _TestHistoryNotifier(this.historyState);

  final RecurringOccurrenceHistoryState historyState;

  @override
  Future<RecurringOccurrenceHistoryState> build(
    RecurringOccurrenceHistoryQuery arg,
  ) async =>
      historyState;
}

RecurringOccurrenceSummary _occurrence({
  required String id,
  required DateTime date,
  required String status,
}) {
  final isConfirmed = status == 'confirmed';
  return RecurringOccurrenceSummary(
    id: id,
    recurringId: 'recurring-1',
    scheduledOccurrenceDate: date,
    status: status,
    confirmationSource: isConfirmed ? 'user' : null,
    actualTransactionId: isConfirmed ? 'transaction-$id' : null,
    paidDate: isConfirmed ? date : null,
    amountCents: isConfirmed ? 10000 : null,
    currency: isConfirmed ? 'USD' : null,
    confirmedAt: isConfirmed ? date : null,
    confirmedByUserId: isConfirmed ? 'user-1' : null,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  testWidgets(
      'keeps the immediate next row upcoming and excludes skipped cycles from paid',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextOccurrence = today.add(const Duration(days: 30));
    final historyState = RecurringOccurrenceHistoryState(
      items: [
        _occurrence(
          id: 'skipped-1',
          date: today.subtract(const Duration(days: 30)),
          status: 'skipped',
        ),
        _occurrence(
          id: 'confirmed-1',
          date: today.subtract(const Duration(days: 60)),
          status: 'confirmed',
        ),
      ],
      hasMore: false,
      nextCursor: null,
    );
    final transaction = RecurringTransaction(
      id: 'recurring-1',
      userId: 'user-1',
      date: today.subtract(const Duration(days: 60)),
      category: 'housing',
      description: 'Rent',
      amount: 100,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: today.subtract(const Duration(days: 60)),
        projectionEnabled: false,
      ),
      type: 'expense',
      attachments: const [],
      createdAt: today.subtract(const Duration(days: 90)),
      serverNextOccurrenceDate: nextOccurrence,
      serverLatestActionableOccurrenceDate: nextOccurrence,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuth.new),
          analyticsProvider.overrideWith(_TestAnalyticsNotifier.new),
          recurringOccurrenceHistoryProvider.overrideWith(
            () => _TestHistoryNotifier(historyState),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecurringHistoryPage(transaction: transaction),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Paid (1)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('shows Ended instead of a stale next due date', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endedDate = today.subtract(const Duration(days: 30));
    final historyState = RecurringOccurrenceHistoryState(
      items: [
        _occurrence(
          id: 'skipped-ended',
          date: endedDate,
          status: 'skipped',
        ),
      ],
      hasMore: false,
      nextCursor: null,
    );
    final transaction = RecurringTransaction(
      id: 'recurring-1',
      userId: 'user-1',
      date: endedDate,
      category: 'housing',
      description: 'Ended rent',
      amount: 100,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: endedDate,
        endDate: today.subtract(const Duration(days: 1)),
        excludedDates: [endedDate],
      ),
      type: 'expense',
      attachments: const [],
      createdAt: endedDate,
      serverNextOccurrenceDate: endedDate,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuth.new),
          analyticsProvider.overrideWith(_TestAnalyticsNotifier.new),
          recurringOccurrenceHistoryProvider.overrideWith(
            () => _TestHistoryNotifier(historyState),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecurringHistoryPage(transaction: transaction),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ended'), findsOneWidget);
  });
}
