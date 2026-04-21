import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

class TransactionsPageFilterInput {
  final List<ExpenseEntry> baseExpenses;
  final List<ExpenseEntry> projectedRecurringExpenses;
  final String searchQuery;
  final String selectedCategory;
  final String selectedType;
  final String? selectedCurrency;
  final DateRangeFilter selectedDateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;
  final DateTime now;
  final String? pinnedHouseholdId;
  final ActiveWalletType activeAccountType;
  final String? activeAccountHouseholdId;
  final String? selectedHouseholdId;

  const TransactionsPageFilterInput({
    required this.baseExpenses,
    required this.projectedRecurringExpenses,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedType,
    required this.selectedCurrency,
    required this.selectedDateFilter,
    required this.customStart,
    required this.customEnd,
    required this.now,
    required this.pinnedHouseholdId,
    required this.activeAccountType,
    required this.activeAccountHouseholdId,
    required this.selectedHouseholdId,
  });
}

class TransactionsPageDerivedData {
  final List<ExpenseEntry> filteredExpenses;
  final List<String> categories;
  final List<MonthTransactionGroup> monthGroups;

  const TransactionsPageDerivedData({
    required this.filteredExpenses,
    required this.categories,
    required this.monthGroups,
  });
}

enum TransactionRenderItemType {
  monthHeader,
  dayHeader,
  entry,
}

class TransactionRenderItem {
  final TransactionRenderItemType type;
  final MonthTransactionGroup? monthGroup;
  final DayTransactionGroup? dayGroup;
  final ExpenseEntry? expense;
  final bool isFirst;
  final bool isLast;

  const TransactionRenderItem._({
    required this.type,
    this.monthGroup,
    this.dayGroup,
    this.expense,
    this.isFirst = false,
    this.isLast = false,
  });

  const TransactionRenderItem.monthHeader(MonthTransactionGroup monthGroup)
      : this._(
          type: TransactionRenderItemType.monthHeader,
          monthGroup: monthGroup,
        );

  const TransactionRenderItem.dayHeader(DayTransactionGroup dayGroup)
      : this._(
          type: TransactionRenderItemType.dayHeader,
          dayGroup: dayGroup,
        );

  const TransactionRenderItem.entry({
    required ExpenseEntry expense,
    required bool isFirst,
    required bool isLast,
  }) : this._(
          type: TransactionRenderItemType.entry,
          expense: expense,
          isFirst: isFirst,
          isLast: isLast,
        );

  bool get isMonthHeader => type == TransactionRenderItemType.monthHeader;
  bool get isDayHeader => type == TransactionRenderItemType.dayHeader;
}

TransactionsPageDerivedData deriveTransactionsPageData(
  TransactionsPageFilterInput input,
) {
  final categories = input.baseExpenses
      .map((expense) => (expense.category ?? 'uncategorized').toLowerCase())
      .toSet()
      .toList()
    ..sort();

  var expenses = input.baseExpenses.toList();

  if (input.projectedRecurringExpenses.isNotEmpty) {
    expenses = [
      ...expenses,
      ...dedupeProjectedRecurringExpenseEntries(
        projectedExpenses: input.projectedRecurringExpenses,
        actualExpenses: expenses,
      ),
    ];
  }

  if (input.pinnedHouseholdId == null) {
    expenses = expenses.where((expense) {
      final householdId = expense.householdId;
      switch (input.activeAccountType) {
        case ActiveWalletType.personal:
          return householdId == null || householdId.isEmpty;
        case ActiveWalletType.portfolio:
          final selectedId = input.activeAccountHouseholdId;
          if (selectedId == null || selectedId.isEmpty) return false;
          return householdId == selectedId;
        case ActiveWalletType.household:
          final selectedId = input.selectedHouseholdId;
          if (selectedId == null || selectedId.isEmpty) return false;
          return householdId == selectedId;
      }
    }).toList();
  }

  final selectedCurrency = input.selectedCurrency?.toUpperCase();
  if (selectedCurrency != null) {
    expenses = expenses.where((expense) {
      return expense.currency?.toUpperCase() == selectedCurrency;
    }).toList();
  }

  final normalizedSearchQuery = input.searchQuery.trim().toLowerCase();
  if (normalizedSearchQuery.isNotEmpty) {
    expenses = expenses.where((expense) {
      final category = (expense.category ?? 'uncategorized').toLowerCase();
      final amount = expense.amount.toString();
      final rawText = (expense.rawText ?? '').toLowerCase();
      return category.contains(normalizedSearchQuery) ||
          amount.contains(normalizedSearchQuery) ||
          rawText.contains(normalizedSearchQuery);
    }).toList();
  }

  if (input.selectedCategory != 'all') {
    final normalizedCategory = input.selectedCategory.toLowerCase();
    expenses = expenses.where((expense) {
      return (expense.category ?? 'uncategorized').toLowerCase() ==
          normalizedCategory;
    }).toList();
  }

  if (input.selectedType != 'all') {
    final normalizedType = input.selectedType.toLowerCase();
    expenses = expenses.where((expense) {
      return (expense.type ?? 'expense').toLowerCase() == normalizedType;
    }).toList();
  }

  if (input.selectedDateFilter != DateRangeFilter.allTime) {
    final range = getDateRangeFromFilter(
      input.selectedDateFilter,
      input.customStart,
      input.customEnd,
      now: input.now,
    );
    final from = range['from']!;
    final to = range['to']!;
    final toEndOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);

    expenses = expenses.where((expense) {
      final dateOnly =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
      return !dateOnly.isBefore(from) && !dateOnly.isAfter(toEndOfDay);
    }).toList();
  }

  expenses.sort((left, right) => right.date.compareTo(left.date));

  return TransactionsPageDerivedData(
    filteredExpenses: expenses,
    categories: ['all', ...categories],
    monthGroups: groupTransactionsByMonth(expenses),
  );
}

List<TransactionRenderItem> buildVisibleTransactionRenderItems({
  required List<MonthTransactionGroup> monthGroups,
  required int visibleExpenseCount,
}) {
  if (visibleExpenseCount <= 0 || monthGroups.isEmpty) {
    return const [];
  }

  final items = <TransactionRenderItem>[];
  var renderedExpenses = 0;

  for (final monthGroup in monthGroups) {
    if (renderedExpenses >= visibleExpenseCount) {
      break;
    }

    final dayGroups = groupTransactionsByDay(monthGroup.expenses);
    var addedMonthHeader = false;

    for (final dayGroup in dayGroups) {
      if (renderedExpenses >= visibleExpenseCount) {
        break;
      }

      if (!addedMonthHeader) {
        items.add(TransactionRenderItem.monthHeader(monthGroup));
        addedMonthHeader = true;
      }

      items.add(TransactionRenderItem.dayHeader(dayGroup));

      for (var index = 0; index < dayGroup.expenses.length; index++) {
        final expense = dayGroup.expenses[index];
        items.add(
          TransactionRenderItem.entry(
            expense: expense,
            isFirst: index == 0,
            isLast: index == dayGroup.expenses.length - 1,
          ),
        );
        renderedExpenses++;
      }
    }
  }

  return items;
}
