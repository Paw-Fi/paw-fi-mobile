import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

class _MockAnalyticsNotifier extends AnalyticsNotifier {
  _MockAnalyticsNotifier(Ref ref, AnalyticsData data) : super(ref) {
    state = data;
  }
}

class _MockRecurringTransactionsNotifier extends RecurringTransactionsNotifier {
  _MockRecurringTransactionsNotifier(
    super.ref,
    super.householdId,
    List<RecurringTransaction> transactions,
  ) {
    state = RecurringTransactionsState(
      data: AsyncValue.data(transactions),
      hasLoadedOnce: true,
    );
  }
}

void main() {
  test('upcoming provider surfaces six month recurring transactions due soon',
      () {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDate = todayDate.add(const Duration(days: 2));
    final anchorDate = DateTime(dueDate.year, dueDate.month - 6, dueDate.day);

    final recurring = RecurringTransaction(
      id: 'rec_six_months',
      date: anchorDate,
      category: 'insurance',
      description: 'Insurance renewal',
      amount: 240.0,
      currency: 'USD',
      ownerType: 'me',
      privacyScope: 'full',
      recurrenceRule: RecurrenceRule(
        frequency: 'monthly',
        anchorDate: anchorDate,
        interval: 6,
      ),
      type: 'expense',
      attachments: const [],
      createdAt: todayDate,
    );

    final container = ProviderContainer(
      overrides: [
        analyticsProvider.overrideWith(
          (ref) => _MockAnalyticsNotifier(
            ref,
            AnalyticsData(
              contact: UserContact(
                id: 'contact_1',
                verified: true,
              ),
            ),
          ),
        ),
        recurringTransactionsProvider(null).overrideWith(
          (ref) => _MockRecurringTransactionsNotifier(ref, null, [recurring]),
        ),
      ],
    );

    addTearDown(container.dispose);

    final upcoming = container.read(
      upcomingRecurringTransactionProvider(
        const UpcomingRecurringScope(householdId: null, currency: 'USD'),
      ),
    );

    expect(upcoming, isNotNull);
    expect(upcoming!.transaction.id, 'rec_six_months');
    expect(upcoming.daysUntil, 2);
  });
}
