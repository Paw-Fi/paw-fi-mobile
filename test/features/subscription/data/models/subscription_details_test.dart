import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  SubscriptionDetails details({
    required DateTime currentPeriodEnd,
    DateTime? commitmentEnd,
  }) {
    return SubscriptionDetails(
      subscription: Subscription(
        id: 'sub-1',
        userId: 'user-1',
        provider: 'app_store',
        plan: 'plus',
        status: 'active',
        currentPeriodEnd: currentPeriodEnd,
        cancelAtPeriodEnd: true,
        commitmentMonths: commitmentEnd == null ? null : 12,
        commitmentEnd: commitmentEnd,
        createdAt: DateTime.now(),
      ),
      invoices: const [],
    );
  }

  test('scheduled commitment cancellation displays the commitment end', () {
    final currentPeriodEnd = DateTime.now().add(const Duration(days: 20));
    final commitmentEnd = DateTime.now().add(const Duration(days: 200));
    final expectedDays = commitmentEnd.difference(DateTime.now()).inDays;

    expect(
      details(
        currentPeriodEnd: currentPeriodEnd,
        commitmentEnd: commitmentEnd,
      ).renewalInfo(l10n),
      l10n.accessEndsInDays(expectedDays),
    );
  });

  test('scheduled non-commitment cancellation falls back to period end', () {
    final currentPeriodEnd = DateTime.now().add(const Duration(days: 20));
    final expectedDays = currentPeriodEnd.difference(DateTime.now()).inDays;

    expect(
      details(currentPeriodEnd: currentPeriodEnd).renewalInfo(l10n),
      l10n.accessEndsInDays(expectedDays),
    );
  });
}
