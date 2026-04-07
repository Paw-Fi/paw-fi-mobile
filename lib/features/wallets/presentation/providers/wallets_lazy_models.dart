class WalletsScopeQuery {
  WalletsScopeQuery({
    required this.userId,
    required this.householdId,
    required this.selectedCurrency,
    required DateTime currentMonthStart,
  }) : currentMonthStart = DateTime(
          currentMonthStart.year,
          currentMonthStart.month,
        );

  final String userId;
  final String? householdId;
  final String selectedCurrency;
  final DateTime currentMonthStart;

  Map<String, dynamic> toHistoryRpcParams() {
    return <String, dynamic>{
      'p_user_id': userId,
      'p_household_id': householdId,
      'p_currency': selectedCurrency,
      'p_current_month_start': _formatDate(currentMonthStart),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is WalletsScopeQuery &&
            other.userId == userId &&
            other.householdId == householdId &&
            other.selectedCurrency == selectedCurrency &&
            other.currentMonthStart == currentMonthStart);
  }

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        selectedCurrency,
        currentMonthStart,
      );
}

class WalletsMonthQuery {
  WalletsMonthQuery({
    required this.scope,
    required DateTime monthStart,
  }) : monthStart = DateTime(monthStart.year, monthStart.month);

  final WalletsScopeQuery scope;
  final DateTime monthStart;

  Map<String, dynamic> toRpcParams() {
    return <String, dynamic>{
      'p_user_id': scope.userId,
      'p_household_id': scope.householdId,
      'p_currency': scope.selectedCurrency,
      'p_month_start': _formatDate(monthStart),
      'p_include_archived': false,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is WalletsMonthQuery &&
            other.scope == scope &&
            other.monthStart == monthStart);
  }

  @override
  int get hashCode => Object.hash(scope, monthStart);
}

class WalletMonthBalance {
  const WalletMonthBalance({
    required this.walletId,
    required this.balanceCents,
  });

  final String walletId;
  final int balanceCents;

  factory WalletMonthBalance.fromJson(Map<String, dynamic> json) {
    return WalletMonthBalance(
      walletId: (json['wallet_id'] ?? '').toString(),
      balanceCents: _toInt(json['balance_cents']),
    );
  }
}

class WalletsMonthSnapshot {
  const WalletsMonthSnapshot({
    required this.monthStart,
    required this.monthEndExclusive,
    required this.incomeTotalCents,
    required this.spentTotalCents,
    required this.netWorthCents,
    required this.walletBalances,
  });

  final DateTime monthStart;
  final DateTime monthEndExclusive;
  final int incomeTotalCents;
  final int spentTotalCents;
  final int netWorthCents;
  final Map<String, int> walletBalances;

  factory WalletsMonthSnapshot.fromJson(Map<String, dynamic> json) {
    final balancesJson = (json['wallet_balances'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WalletMonthBalance.fromJson)
        .toList(growable: false);

    return WalletsMonthSnapshot(
      monthStart: _toMonthDate(json['month_start']),
      monthEndExclusive: _toMonthDate(json['month_end_exclusive']),
      incomeTotalCents: _toInt(json['income_total_cents']),
      spentTotalCents: _toInt(json['spent_total_cents']),
      netWorthCents: _toInt(json['net_worth_cents']),
      walletBalances: <String, int>{
        for (final row in balancesJson) row.walletId: row.balanceCents,
      },
    );
  }
}

class WalletNetWorthPoint {
  const WalletNetWorthPoint({
    required this.monthStart,
    required this.netWorthCents,
  });

  final DateTime monthStart;
  final int netWorthCents;

  factory WalletNetWorthPoint.fromJson(Map<String, dynamic> json) {
    return WalletNetWorthPoint(
      monthStart: _toMonthDate(json['month_start']),
      netWorthCents: _toInt(json['net_worth_cents']),
    );
  }
}

class WalletsHistorySummary {
  const WalletsHistorySummary({
    required this.availableMonths,
    required this.netWorthSeries,
  });

  final List<DateTime> availableMonths;
  final List<WalletNetWorthPoint> netWorthSeries;

  factory WalletsHistorySummary.fromJson(Map<String, dynamic> json) {
    final availableMonths =
        (json['available_months'] as List<dynamic>? ?? const [])
            .map(_toMonthDate)
            .toList(growable: false);

    final netWorthSeries =
        (json['net_worth_series'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WalletNetWorthPoint.fromJson)
            .toList(growable: false);

    return WalletsHistorySummary(
      availableMonths: availableMonths,
      netWorthSeries: netWorthSeries,
    );
  }
}

int _toInt(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? 0;
}

DateTime _toMonthDate(dynamic value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  final raw = value?.toString() ?? '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return DateTime(1970, 1, 1);
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
