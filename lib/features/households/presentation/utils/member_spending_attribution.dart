import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

class HouseholdMemberSpendingTotals {
  const HouseholdMemberSpendingTotals({
    required this.totalSpentByUserCents,
    required this.transactionCountByUser,
  });

  final Map<String, int> totalSpentByUserCents;
  final Map<String, int> transactionCountByUser;

  int totalForUser(String? userId) {
    if (userId == null || userId.isEmpty) return 0;
    return totalSpentByUserCents[userId] ?? 0;
  }

  int transactionCountForUser(String? userId) {
    if (userId == null || userId.isEmpty) return 0;
    return transactionCountByUser[userId] ?? 0;
  }
}

HouseholdMemberSpendingTotals computeSplitAwareMemberSpendingTotals({
  required List<ExpenseEntry> transactions,
  required DateTime from,
  required DateTime to,
  required List<ExpenseSplitGroup> splits,
  String? selectedCurrency,
}) {
  final totalsByUser = <String, int>{};
  final countsByUser = <String, int>{};
  final splitById = {
    for (final split in splits) split.id: split,
  };
  final normalizedCurrency = selectedCurrency?.trim().toUpperCase();

  void addAmountToUser(String? userId, int amountCents) {
    if (userId == null || userId.isEmpty) return;
    if (amountCents <= 0) return;
    totalsByUser[userId] = (totalsByUser[userId] ?? 0) + amountCents;
    countsByUser[userId] = (countsByUser[userId] ?? 0) + 1;
  }

  for (final transaction in transactions) {
    final transactionDate = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    if (transactionDate.isBefore(from) || transactionDate.isAfter(to)) {
      continue;
    }

    final isIncome = (transaction.type ?? 'expense').toLowerCase() == 'income';
    if (isIncome) continue;

    final transactionCurrency =
        (transaction.currency ?? '').trim().toUpperCase();
    final currencyMatches = normalizedCurrency == null ||
        normalizedCurrency.isEmpty ||
        transactionCurrency.isEmpty ||
        transactionCurrency == normalizedCurrency;
    if (!currencyMatches) continue;

    final fullAmountCents = transaction.amountCents.abs();
    if (fullAmountCents <= 0) continue;

    final splitGroupId = transaction.splitGroupId;
    if (splitGroupId == null || splitGroupId.isEmpty) {
      addAmountToUser(transaction.userId, fullAmountCents);
      continue;
    }

    final splitGroup = splitById[splitGroupId];
    final splitLines = splitGroup?.splitLines;
    if (splitGroup == null || splitLines == null || splitLines.isEmpty) {
      // Missing split data: keep payer-full attribution as fallback.
      addAmountToUser(transaction.userId, fullAmountCents);
      continue;
    }

    for (final line in splitLines) {
      final lineAmountCents = (line.amountCents ?? 0).abs();
      if (lineAmountCents <= 0) continue;
      addAmountToUser(line.userId, lineAmountCents);
    }
  }

  return HouseholdMemberSpendingTotals(
    totalSpentByUserCents: totalsByUser,
    transactionCountByUser: countsByUser,
  );
}
