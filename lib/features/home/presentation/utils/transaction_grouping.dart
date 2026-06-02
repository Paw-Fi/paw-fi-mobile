import 'package:intl/intl.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';

int compareTransactionsNewestFirst(ExpenseEntry left, ExpenseEntry right) {
  final dateCompare = right.date.compareTo(left.date);
  if (dateCompare != 0) return dateCompare;

  final createdCompare = right.createdAt.compareTo(left.createdAt);
  if (createdCompare != 0) return createdCompare;

  return right.id.compareTo(left.id);
}

class MonthTransactionGroup {
  final DateTime monthStart;
  final List<ExpenseEntry> expenses;
  final double total;

  const MonthTransactionGroup({
    required this.monthStart,
    required this.expenses,
    required this.total,
  });
}

double resolveDayTransactionHeaderTotal(DayTransactionGroup group) =>
    group.total;

List<MonthTransactionGroup> groupTransactionsByMonth(
  List<ExpenseEntry> expenses,
) {
  final Map<DateTime, List<ExpenseEntry>> grouped = {};

  DateTime normalize(ExpenseEntry expense) {
    return DateTime(expense.date.year, expense.date.month, expense.date.day);
  }

  for (final expense in expenses) {
    final localDate = normalize(expense);
    final monthKey = DateTime(localDate.year, localDate.month, 1);
    grouped.putIfAbsent(monthKey, () => []).add(expense);
  }

  final sortedMonths = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  return sortedMonths.map((monthStart) {
    final items = grouped[monthStart]!..sort(compareTransactionsNewestFirst);
    double total = 0;
    for (final e in items) {
      if (_isWalletTransferFeedEntry(e)) continue;
      final isIncome = (e.type ?? 'expense').toLowerCase() == 'income';
      total += (isIncome ? 1 : -1) * e.amount.abs();
    }
    return MonthTransactionGroup(
      monthStart: monthStart,
      expenses: List<ExpenseEntry>.from(items),
      total: total,
    );
  }).toList();
}

class DayTransactionGroup {
  final DateTime date;
  final List<ExpenseEntry> expenses;
  final double total;

  const DayTransactionGroup({
    required this.date,
    required this.expenses,
    required this.total,
  });
}

List<DayTransactionGroup> groupTransactionsByDay(
  List<ExpenseEntry> expenses,
) {
  final Map<DateTime, List<ExpenseEntry>> grouped = {};

  DateTime normalize(ExpenseEntry expense) {
    return DateTime(expense.date.year, expense.date.month, expense.date.day);
  }

  for (final expense in expenses) {
    final localDate = normalize(expense);
    final dayKey = DateTime(localDate.year, localDate.month, localDate.day);
    grouped.putIfAbsent(dayKey, () => []).add(expense);
  }

  final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  return sortedDays.map((day) {
    final items = grouped[day]!..sort(compareTransactionsNewestFirst);
    double total = 0;
    for (final e in items) {
      if (_isWalletTransferFeedEntry(e)) continue;
      final isIncome = (e.type ?? 'expense').toLowerCase() == 'income';
      total += (isIncome ? 1 : -1) * e.amount.abs();
    }
    return DayTransactionGroup(
      date: day,
      expenses: List<ExpenseEntry>.from(items),
      total: total,
    );
  }).toList();
}

String formatMonthHeader(DateTime monthStart, {String? locale}) {
  final formatter = DateFormat('MMMM yyyy', locale);
  return formatter.format(monthStart);
}

bool _isWalletTransferFeedEntry(ExpenseEntry entry) =>
    entry.id.startsWith('transfer:');
