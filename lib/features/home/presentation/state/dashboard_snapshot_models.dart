import 'package:moneko/core/utils/user_timezone.dart';

class DashboardScopeQuery {
  final String userId;
  final String? householdId;
  final String? selectedCurrency;
  final List<String>? selectedCurrencies;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? intervalGranularity;

  const DashboardScopeQuery({
    required this.userId,
    required this.householdId,
    required this.selectedCurrency,
    this.selectedCurrencies,
    required this.startDate,
    required this.endDate,
    this.intervalGranularity,
  });

  String? get normalizedCurrency {
    final currency = selectedCurrency?.trim().toUpperCase();
    return (currency == null || currency.isEmpty) ? null : currency;
  }

  String? get _identityCurrency {
    return normalizedCurrencies == null ? normalizedCurrency : null;
  }

  List<String>? get normalizedCurrencies {
    final source = selectedCurrencies ??
        (selectedCurrency == null ? null : <String>[selectedCurrency!]);
    final normalized = source
        ?.map((currency) => currency.trim().toUpperCase())
        .where((currency) => currency.isNotEmpty)
        .toSet()
        .toList();
    if (normalized == null || normalized.isEmpty) return null;
    normalized.sort();
    return normalized;
  }

  bool allowsCurrency(String? currency) {
    final selected = normalizedCurrencies;
    if (selected == null) return true;
    final normalized = currency?.trim().toUpperCase();
    return normalized == null ||
        normalized.isEmpty ||
        selected.contains(normalized);
  }

  String? get formattedStartDate =>
      startDate == null ? null : formatDateOnlyYmd(startDate!);

  String? get formattedEndDate =>
      endDate == null ? null : formatDateOnlyYmd(endDate!);

  String? get normalizedIntervalGranularity {
    final value = intervalGranularity?.trim().toLowerCase();
    switch (value) {
      case 'daily':
      case 'weekly':
      case 'monthly':
      case 'yearly':
        return value;
      default:
        return null;
    }
  }

  DashboardScopeQuery copyWith({
    String? userId,
    String? householdId,
    String? selectedCurrency,
    List<String>? selectedCurrencies,
    DateTime? startDate,
    DateTime? endDate,
    String? intervalGranularity,
  }) {
    return DashboardScopeQuery(
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      selectedCurrencies: selectedCurrencies ?? this.selectedCurrencies,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      intervalGranularity: intervalGranularity ?? this.intervalGranularity,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DashboardScopeQuery &&
            userId == other.userId &&
            householdId == other.householdId &&
            _identityCurrency == other._identityCurrency &&
            _listEquals(normalizedCurrencies, other.normalizedCurrencies) &&
            formattedStartDate == other.formattedStartDate &&
            formattedEndDate == other.formattedEndDate &&
            normalizedIntervalGranularity ==
                other.normalizedIntervalGranularity;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        _identityCurrency,
        Object.hashAll(normalizedCurrencies ?? const <String>[]),
        formattedStartDate,
        formattedEndDate,
        normalizedIntervalGranularity,
      );
}

bool _listEquals(List<String>? left, List<String>? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class DashboardRecentTransactionsRequest {
  final DashboardScopeQuery query;
  final int limit;

  const DashboardRecentTransactionsRequest({
    required this.query,
    this.limit = 5,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DashboardRecentTransactionsRequest &&
            query == other.query &&
            limit == other.limit;
  }

  @override
  int get hashCode => Object.hash(query, limit);
}

class DashboardCategorySummary {
  final String category;
  final double amount;
  final int transactionCount;

  const DashboardCategorySummary({
    required this.category,
    required this.amount,
    required this.transactionCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'transaction_count': transactionCount,
    };
  }

  factory DashboardCategorySummary.fromJson(Map<String, dynamic> json) {
    return DashboardCategorySummary(
      category: json['category'] as String? ?? 'uncategorized',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardSnapshotSummary {
  final int transactionCount;
  final double expenseTotal;
  final double incomeTotal;
  final bool hasMultipleCurrencies;
  final List<DashboardCategorySummary> categorySummaries;
  final Map<DateTime, double> periodTotals;

  const DashboardSnapshotSummary({
    required this.transactionCount,
    required this.expenseTotal,
    required this.incomeTotal,
    required this.hasMultipleCurrencies,
    required this.categorySummaries,
    required this.periodTotals,
  });

  const DashboardSnapshotSummary.empty()
      : transactionCount = 0,
        expenseTotal = 0,
        incomeTotal = 0,
        hasMultipleCurrencies = false,
        categorySummaries = const <DashboardCategorySummary>[],
        periodTotals = const <DateTime, double>{};

  Map<String, dynamic> toJson() {
    return {
      'transaction_count': transactionCount,
      'expense_total': expenseTotal,
      'income_total': incomeTotal,
      'has_multiple_currencies': hasMultipleCurrencies,
      'category_summaries': categorySummaries
          .map((item) => item.toJson())
          .toList(growable: false),
      'period_totals': {
        for (final entry in periodTotals.entries)
          entry.key.toIso8601String(): entry.value,
      },
    };
  }

  factory DashboardSnapshotSummary.fromJson(Map<String, dynamic> json) {
    final periodTotalsJson =
        json['period_totals'] as Map<String, dynamic>? ?? const {};
    return DashboardSnapshotSummary(
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      expenseTotal: (json['expense_total'] as num?)?.toDouble() ?? 0,
      incomeTotal: (json['income_total'] as num?)?.toDouble() ?? 0,
      hasMultipleCurrencies: json['has_multiple_currencies'] == true,
      categorySummaries: ((json['category_summaries'] as List?) ?? const [])
          .cast<Map>()
          .map((row) =>
              DashboardCategorySummary.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      periodTotals: periodTotalsJson.map(
        (key, value) =>
            MapEntry(DateTime.parse(key), (value as num?)?.toDouble() ?? 0),
      ),
    );
  }
}
