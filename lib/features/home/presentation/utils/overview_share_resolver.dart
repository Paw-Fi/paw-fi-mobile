import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

String normalizeTransactionType(String? type) {
  final normalized = type?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return 'expense';
  }
  if (normalized == 'incomes') return 'income';
  if (normalized == 'expenses') return 'expense';
  return normalized;
}

bool isIncomeTransactionType(String? type) {
  return normalizeTransactionType(type) == 'income';
}

Set<String> normalizeSharedMemberIds(List<String>? members) {
  if (members == null || members.isEmpty) return const <String>{};
  return members
      .map((memberId) => memberId.trim())
      .where((memberId) => memberId.isNotEmpty)
      .toSet();
}

double resolveSplitLineAmountForUser(
  ExpenseSplitGroup group,
  String currentUserId,
) {
  final lines = group.splitLines;
  if (lines == null || lines.isEmpty) return 0.0;

  ExpenseSplitLine? line;
  for (final candidate in lines) {
    if (candidate.userId == currentUserId) {
      line = candidate;
      break;
    }
  }
  if (line == null) return 0.0;

  switch (group.splitType) {
    case SplitType.amount:
      return (line.amountCents ?? 0) / 100.0;
    case SplitType.percentage:
      return ((line.percentage ?? 0) / 100) * (group.totalAmountCents / 100.0);
    case SplitType.shares:
      final totalShares = lines.fold<int>(
        0,
        (sum, splitLine) => sum + (splitLine.shares ?? 0),
      );
      if (totalShares <= 0 || line.shares == null) return 0.0;
      return (group.totalAmountCents / 100.0) * (line.shares! / totalShares);
    case SplitType.equal:
      return (group.totalAmountCents / 100.0) / lines.length;
  }
}

double resolveUserShareRawAmountForOverview({
  required ExpenseEntry entry,
  required String currentUserId,
  required Map<String, ExpenseSplitGroup> splitGroupsByExpenseId,
  required Map<String, ExpenseSplitGroup> splitGroupsById,
}) {
  final fullAmount = entry.amountCents / 100.0;
  final normalizedCurrentUserId = currentUserId.trim();
  if (normalizedCurrentUserId.isEmpty) return fullAmount;

  final householdId = entry.householdId;
  if (householdId == null || householdId.isEmpty) {
    return fullAmount;
  }

  final splitGroupId = entry.splitGroupId?.trim();
  final hasSplitGroupId = splitGroupId != null && splitGroupId.isNotEmpty;
  final splitGroup = splitGroupsByExpenseId[entry.id] ??
      (hasSplitGroupId ? splitGroupsById[splitGroupId] : null);

  if (splitGroup != null) {
    return resolveSplitLineAmountForUser(splitGroup, normalizedCurrentUserId);
  }

  final normalizedSharedMembers =
      normalizeSharedMemberIds(entry.sharedMemberIds);

  if (hasSplitGroupId) {
    if (entry.userId?.trim() == normalizedCurrentUserId) {
      return fullAmount;
    }
    if (normalizedSharedMembers.contains(normalizedCurrentUserId)) {
      return fullAmount / normalizedSharedMembers.length;
    }
    return 0.0;
  }

  if (normalizedSharedMembers.isNotEmpty) {
    if (!normalizedSharedMembers.contains(normalizedCurrentUserId)) {
      return 0.0;
    }
    return fullAmount / normalizedSharedMembers.length;
  }

  if (entry.userId?.trim() == normalizedCurrentUserId) return fullAmount;
  return 0.0;
}
