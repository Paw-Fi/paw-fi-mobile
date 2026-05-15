import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');
}

class _FakeTransactionsFeedService extends TransactionsFeedService {
  _FakeTransactionsFeedService(this.itemsByHouseholdId);

  final Map<String?, List<ExpenseEntry>> itemsByHouseholdId;
  final fetchedQueries = <TransactionsFeedQuery>[];

  @override
  Future<TransactionsFeedPageResult> fetchPage(
    TransactionsFeedQuery query, {
    TransactionsFeedCursor? cursor,
  }) async {
    fetchedQueries.add(query);
    return TransactionsFeedPageResult(
      items: itemsByHouseholdId[query.householdId] ?? const <ExpenseEntry>[],
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) async {
    fetchedQueries.add(query);
    return itemsByHouseholdId[query.householdId] ?? const <ExpenseEntry>[];
  }

  @override
  Future<TransactionsFeedSummary> fetchSummary(
    TransactionsFeedQuery query,
  ) async {
    return const TransactionsFeedSummary.empty();
  }
}

class _FakeHouseholdRepository implements HouseholdRepository {
  const _FakeHouseholdRepository();

  @override
  Future<List<SharedBudget>> getHouseholdBudgets(String householdId) async {
    return const <SharedBudget>[];
  }

  @override
  Future<List<Household>> getUserHouseholds(String userId) async {
    return const <Household>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ExpenseEntry _entry(
  String id, {
  String? householdId,
  DateTime? date,
}) {
  final resolvedDate = date ?? DateTime(2026, 4, 20, 12);
  return ExpenseEntry(
    id: id,
    userId: 'user-1',
    householdId: householdId,
    date: resolvedDate,
    amountCents: 1000,
    createdAt: resolvedDate,
    type: 'expense',
    category: 'food',
    currency: 'USD',
  );
}

Household _household(String id) {
  final now = DateTime(2026, 4, 20);
  return Household(
    id: id,
    name: 'Household $id',
    ownerId: 'user-1',
    currency: 'USD',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('builds overview transactions from the local-first transaction feed',
      () async {
    final service = _FakeTransactionsFeedService({
      null: [_entry('personal')],
      'household-1': [_entry('household', householdId: 'household-1')],
    });
    final household = _household('household-1');
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_TestAuth.new),
        preloadedUserHouseholdsProvider('user-1')
            .overrideWith((ref) => [household]),
        householdRepositoryProvider
            .overrideWithValue(const _FakeHouseholdRepository()),
        transactionsFeedServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      budgetDashboardDataProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final data = await container.read(budgetDashboardDataProvider.future);

    expect(
      data.allTransactions.map((transaction) => transaction.entry.id).toList(),
      ['personal', 'household'],
    );
    expect(
      service.fetchedQueries.map((query) => query.householdId).toList(),
      [null, 'household-1'],
    );
    expect(
      service.fetchedQueries.every((query) => query.selectedCurrency == null),
      isTrue,
    );
  });
}
