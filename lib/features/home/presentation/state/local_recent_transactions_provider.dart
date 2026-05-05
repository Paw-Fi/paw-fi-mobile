import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/local_database/app_database_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';

class LocalRecentTransactionsRequest {
  const LocalRecentTransactionsRequest({
    required this.userId,
    this.householdId,
    this.currency,
    this.limit = 5,
  });

  final String userId;
  final String? householdId;
  final String? currency;
  final int limit;

  String? get normalizedCurrency {
    final value = currency?.trim().toUpperCase();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LocalRecentTransactionsRequest &&
            userId == other.userId &&
            householdId == other.householdId &&
            normalizedCurrency == other.normalizedCurrency &&
            limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        normalizedCurrency,
        limit,
      );
}

final localRecentTransactionsProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, LocalRecentTransactionsRequest>(
  (ref, request) async {
    ref.watch(dashboardRefreshSignalProvider);
    final database = ref.watch(appDatabaseProvider);
    final rows = await database.recentLocalTransactions(
      userId: request.userId,
      householdId: request.householdId,
      currency: request.normalizedCurrency,
      limit: request.limit,
    );
    return rows.map(localRecordToExpenseEntry).toList(growable: false);
  },
);

class HomeTransactionOverlayRequest {
  const HomeTransactionOverlayRequest({
    required this.userId,
    this.householdId,
    this.currency,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String userId;
  final String? householdId;
  final String? currency;
  final String? startDate;
  final String? endDate;
  final int? limit;

  String? get normalizedHouseholdId {
    final value = householdId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get normalizedCurrency {
    final value = currency?.trim().toUpperCase();
    return value == null || value.isEmpty ? null : value;
  }

  DateTime? get parsedStartDate => _parseUtcCalendarDayOrNull(startDate);

  DateTime? get parsedEndDate => _parseUtcCalendarDayOrNull(endDate);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HomeTransactionOverlayRequest &&
            userId == other.userId &&
            normalizedHouseholdId == other.normalizedHouseholdId &&
            normalizedCurrency == other.normalizedCurrency &&
            startDate == other.startDate &&
            endDate == other.endDate &&
            limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        normalizedHouseholdId,
        normalizedCurrency,
        startDate,
        endDate,
        limit,
      );
}

final homeTransactionOverlayProvider = Provider.autoDispose
    .family<List<ExpenseEntry>, HomeTransactionOverlayRequest>(
  (ref, request) {
    final householdId = request.normalizedHouseholdId;
    final source = householdId == null
        ? ref.watch(analyticsProvider.select((state) => state.allExpenses))
        : ref.watch(
            householdOptimisticExpensesProvider.select(
              (state) => state[householdId] ?? const <ExpenseEntry>[],
            ),
          );
    final filtered = source
        .where((entry) => _matchesOverlayRequest(entry, request))
        .toList(growable: false)
      ..sort(_compareEntriesNewestFirst);
    final limit = request.limit;
    if (limit == null || limit <= 0 || filtered.length <= limit) {
      return filtered;
    }
    return filtered.take(limit).toList(growable: false);
  },
);

List<ExpenseEntry> mergeHomeTransactions({
  required List<ExpenseEntry> base,
  required List<ExpenseEntry> overlay,
  int? limit,
}) {
  if (base.isEmpty && overlay.isEmpty) return const [];

  final byId = <String, ExpenseEntry>{};
  for (final entry in base) {
    if (entry.id.isEmpty) continue;
    byId[entry.id] = entry;
  }
  for (final entry in overlay) {
    if (entry.id.isEmpty) continue;
    final existing = byId[entry.id];
    if (existing == null || _isEntryNewer(entry, existing)) {
      byId[entry.id] = entry;
    }
  }

  final merged = byId.values.toList(growable: false)
    ..sort(_compareEntriesNewestFirst);
  if (limit == null || limit <= 0 || merged.length <= limit) {
    return merged;
  }
  return merged.take(limit).toList(growable: false);
}

List<ExpenseEntry> mergeRecentTransactions({
  required List<ExpenseEntry> remote,
  required List<ExpenseEntry> local,
  List<ExpenseEntry> overlay = const <ExpenseEntry>[],
  int limit = 5,
}) {
  if (limit <= 0) {
    return const [];
  }

  return mergeHomeTransactions(
    base: [...remote, ...local],
    overlay: overlay,
    limit: limit,
  );
}

ExpenseEntry localRecordToExpenseEntry(LocalTransactionRecord record) {
  return ExpenseEntry(
    id: record.serverId ?? record.id,
    contactId: record.contactId,
    userId: record.userId,
    householdId: record.householdId,
    date: _parseUtcCalendarDay(record.dateYmd),
    amountCents: record.amountCents,
    currency: record.currency,
    category: record.category,
    createdAt: DateTime.tryParse(record.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.tryParse(record.updatedAt),
    rawText: record.rawText,
    merchant: record.merchant,
    receiptImageUrl: record.receiptImageUrl,
    splitGroupId: record.splitGroupId,
    bankAccountId: record.bankAccountId,
    walletId: record.walletId,
    type: record.type,
    isRecurring: record.isRecurring,
    syncStatus: record.syncStatus,
    reviewReasons: _decodeStringList(record.reviewReasonsJson),
  );
}

DateTime _parseUtcCalendarDay(String value) {
  final parsed = tryParseDateOnlyYmd(value);
  if (parsed == null) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

DateTime? _parseUtcCalendarDayOrNull(String? value) {
  final parsed = tryParseDateOnlyYmd(value);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

List<String>? _decodeStringList(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) {
    return null;
  }
  return decoded.map((item) => item.toString()).toList(growable: false);
}

bool _matchesOverlayRequest(
  ExpenseEntry entry,
  HomeTransactionOverlayRequest request,
) {
  final entryUserId = entry.userId?.trim();
  if (entryUserId != null &&
      entryUserId.isNotEmpty &&
      entryUserId != request.userId) {
    return false;
  }

  final requestHouseholdId = request.normalizedHouseholdId;
  final entryHouseholdId = entry.householdId?.trim();
  if (requestHouseholdId == null) {
    if (entryHouseholdId != null && entryHouseholdId.isNotEmpty) {
      return false;
    }
  } else if (entryHouseholdId != requestHouseholdId) {
    return false;
  }

  final currency = request.normalizedCurrency;
  if (currency != null) {
    final entryCurrency = entry.currency?.trim().toUpperCase();
    if (entryCurrency != currency) {
      return false;
    }
  }

  final entryDate = DateTime.utc(
    entry.date.year,
    entry.date.month,
    entry.date.day,
  );
  final startDate = request.parsedStartDate;
  if (startDate != null && entryDate.isBefore(startDate)) {
    return false;
  }
  final endDate = request.parsedEndDate;
  if (endDate != null && entryDate.isAfter(endDate)) {
    return false;
  }

  return true;
}

int _compareEntriesNewestFirst(ExpenseEntry a, ExpenseEntry b) {
  final byDate = b.date.compareTo(a.date);
  if (byDate != 0) {
    return byDate;
  }
  return b.createdAt.compareTo(a.createdAt);
}

bool _isEntryNewer(ExpenseEntry candidate, ExpenseEntry existing) {
  final byDate = candidate.date.compareTo(existing.date);
  if (byDate != 0) {
    return byDate > 0;
  }
  return !candidate.createdAt.isBefore(existing.createdAt);
}
