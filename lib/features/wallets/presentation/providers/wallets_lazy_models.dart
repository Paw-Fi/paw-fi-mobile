class WalletsScopeQuery {
  WalletsScopeQuery({
    required this.userId,
    required this.householdId,
    required this.selectedCurrency,
    this.selectedCurrencies,
    required DateTime currentMonthStart,
  }) : currentMonthStart = DateTime(
          currentMonthStart.year,
          currentMonthStart.month,
        );

  final String userId;
  final String? householdId;
  final String selectedCurrency;
  final List<String>? selectedCurrencies;
  final DateTime currentMonthStart;

  List<String>? get normalizedSelectedCurrencies {
    final values = (selectedCurrencies ?? const <String>[])
        .map((currency) => currency.trim().toUpperCase())
        .where((currency) => currency.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values.isEmpty ? null : values;
  }

  bool get hasMultiCurrencySelection =>
      (normalizedSelectedCurrencies?.length ?? 0) > 1;

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
            _listEquals(other.normalizedSelectedCurrencies,
                normalizedSelectedCurrencies) &&
            other.currentMonthStart == currentMonthStart);
  }

  @override
  int get hashCode => Object.hash(
        userId,
        householdId,
        selectedCurrency,
        Object.hashAll(normalizedSelectedCurrencies ?? const <String>[]),
        currentMonthStart,
      );
}

bool _listEquals(List<String>? a, List<String>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

  Map<String, dynamic> toJson() {
    return {
      'month_start': _formatDate(monthStart),
      'month_end_exclusive': _formatDate(monthEndExclusive),
      'income_total_cents': incomeTotalCents,
      'spent_total_cents': spentTotalCents,
      'net_worth_cents': netWorthCents,
      'wallet_balances': [
        for (final entry in walletBalances.entries)
          {
            'wallet_id': entry.key,
            'balance_cents': entry.value,
          }
      ],
    };
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

  Map<String, dynamic> toJson() {
    return {
      'month_start': _formatDate(monthStart),
      'net_worth_cents': netWorthCents,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'available_months':
          availableMonths.map(_formatDate).toList(growable: false),
      'net_worth_series':
          netWorthSeries.map((point) => point.toJson()).toList(growable: false),
    };
  }
}

class WalletsPageState {
  WalletsPageState({
    required this.history,
    required List<DateTime> visibleMonths,
    required DateTime selectedMonthStart,
    required Map<DateTime, WalletsMonthSnapshot> cachedSnapshotsByMonth,
    required Set<DateTime> loadingMonths,
    required Map<DateTime, Object> monthErrorsByMonth,
    required DateTime lastResolvedSelectedMonthStart,
    this.isRefreshing = false,
  })  : visibleMonths = visibleMonths
            .map(normalizeWalletMonthStart)
            .toList(growable: false),
        selectedMonthStart = normalizeWalletMonthStart(selectedMonthStart),
        cachedSnapshotsByMonth = <DateTime, WalletsMonthSnapshot>{
          for (final entry in cachedSnapshotsByMonth.entries)
            normalizeWalletMonthStart(entry.key): entry.value,
        },
        loadingMonths = loadingMonths.map(normalizeWalletMonthStart).toSet(),
        monthErrorsByMonth = <DateTime, Object>{
          for (final entry in monthErrorsByMonth.entries)
            normalizeWalletMonthStart(entry.key): entry.value,
        },
        lastResolvedSelectedMonthStart =
            normalizeWalletMonthStart(lastResolvedSelectedMonthStart);

  final WalletsHistorySummary history;
  final List<DateTime> visibleMonths;
  final DateTime selectedMonthStart;
  final Map<DateTime, WalletsMonthSnapshot> cachedSnapshotsByMonth;
  final Set<DateTime> loadingMonths;
  final Map<DateTime, Object> monthErrorsByMonth;
  final DateTime lastResolvedSelectedMonthStart;
  final bool isRefreshing;

  WalletsMonthSnapshot? get selectedSnapshot =>
      cachedSnapshotsByMonth[selectedMonthStart];

  WalletsMonthSnapshot? get displayedSnapshot =>
      selectedSnapshot ??
      cachedSnapshotsByMonth[lastResolvedSelectedMonthStart];

  bool get isSelectedMonthLoading => loadingMonths.contains(selectedMonthStart);

  Object? get selectedMonthError => monthErrorsByMonth[selectedMonthStart];

  int get selectedMonthIndex => visibleMonths.indexOf(selectedMonthStart);

  WalletsPageState copyWith({
    WalletsHistorySummary? history,
    List<DateTime>? visibleMonths,
    DateTime? selectedMonthStart,
    Map<DateTime, WalletsMonthSnapshot>? cachedSnapshotsByMonth,
    Set<DateTime>? loadingMonths,
    Map<DateTime, Object>? monthErrorsByMonth,
    DateTime? lastResolvedSelectedMonthStart,
    bool? isRefreshing,
  }) {
    return WalletsPageState(
      history: history ?? this.history,
      visibleMonths: visibleMonths ?? this.visibleMonths,
      selectedMonthStart: selectedMonthStart ?? this.selectedMonthStart,
      cachedSnapshotsByMonth:
          cachedSnapshotsByMonth ?? this.cachedSnapshotsByMonth,
      loadingMonths: loadingMonths ?? this.loadingMonths,
      monthErrorsByMonth: monthErrorsByMonth ?? this.monthErrorsByMonth,
      lastResolvedSelectedMonthStart:
          lastResolvedSelectedMonthStart ?? this.lastResolvedSelectedMonthStart,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'history': history.toJson(),
      'visible_months': visibleMonths.map(_formatDate).toList(growable: false),
      'selected_month_start': _formatDate(selectedMonthStart),
      'cached_snapshots_by_month': {
        for (final entry in cachedSnapshotsByMonth.entries)
          _formatDate(entry.key): entry.value.toJson(),
      },
      'last_resolved_selected_month_start':
          _formatDate(lastResolvedSelectedMonthStart),
    };
  }

  factory WalletsPageState.fromCacheJson(Map<String, dynamic> json) {
    final visibleMonths =
        (json['visible_months'] as List<dynamic>? ?? const <dynamic>[])
            .map(_toMonthDate)
            .toList(growable: false);
    final snapshotsJson =
        json['cached_snapshots_by_month'] as Map<String, dynamic>? ??
            const <String, dynamic>{};

    return WalletsPageState(
      history: WalletsHistorySummary.fromJson(
        Map<String, dynamic>.from(
          json['history'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      visibleMonths: visibleMonths,
      selectedMonthStart: _toMonthDate(json['selected_month_start']),
      cachedSnapshotsByMonth: {
        for (final entry in snapshotsJson.entries)
          _toMonthDate(entry.key): WalletsMonthSnapshot.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      loadingMonths: const <DateTime>{},
      monthErrorsByMonth: const <DateTime, Object>{},
      lastResolvedSelectedMonthStart:
          _toMonthDate(json['last_resolved_selected_month_start']),
    );
  }
}

DateTime normalizeWalletMonthStart(DateTime date) {
  return DateTime(date.year, date.month, 1);
}

List<DateTime> buildWalletMonthWindow({
  required DateTime anchorMonth,
  required int count,
}) {
  final normalizedAnchor = normalizeWalletMonthStart(anchorMonth);
  return List<DateTime>.generate(
    count,
    (index) => DateTime(
      normalizedAnchor.year,
      normalizedAnchor.month - index,
      1,
    ),
    growable: false,
  );
}

List<DateTime> appendOlderWalletMonthBatch({
  required List<DateTime> visibleMonths,
  required int batchSize,
}) {
  if (visibleMonths.isEmpty) {
    return const <DateTime>[];
  }

  final oldestVisibleMonth = normalizeWalletMonthStart(visibleMonths.last);
  return List<DateTime>.generate(
    batchSize,
    (index) => DateTime(
      oldestVisibleMonth.year,
      oldestVisibleMonth.month - index - 1,
      1,
    ),
    growable: false,
  );
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
