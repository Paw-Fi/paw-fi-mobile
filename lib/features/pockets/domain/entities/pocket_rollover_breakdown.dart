class PocketRolloverBreakdown {
  const PocketRolloverBreakdown({
    required this.periodMonth,
    required this.currency,
    required this.totalIncomingRolloverCents,
    required this.openingRolloverCents,
    required this.currentRolloverTotalCents,
    required this.contributions,
    required this.adjustments,
    required this.monthlyHistory,
    required this.warnings,
    required this.nextMonthPreview,
  });

  factory PocketRolloverBreakdown.fromJson(Map<String, dynamic> json) {
    return PocketRolloverBreakdown(
      periodMonth: _parseDate(json['period_month']),
      currency: json['currency']?.toString() ?? 'USD',
      totalIncomingRolloverCents:
          _parseInt(json['total_incoming_rollover_cents']),
      openingRolloverCents: _parseInt(json['opening_rollover_cents']),
      currentRolloverTotalCents: _parseInt(
        json['current_rollover_total_cents'],
        fallback: _parseInt(json['total_incoming_rollover_cents']) +
            _parseInt(json['opening_rollover_cents']),
      ),
      contributions: _parseList(
        json['contributions'],
        PocketRolloverContribution.fromJson,
      ),
      adjustments: _parseList(
        json['adjustments'],
        PocketRolloverContribution.fromJson,
      ),
      monthlyHistory: _parseList(
        json['monthly_history'],
        PocketRolloverHistoryMonth.fromJson,
      ),
      warnings: _parseList(
        json['warnings'],
        PocketRolloverWarning.fromJson,
      ),
      nextMonthPreview: PocketRolloverNextMonthPreview.fromJson(
        _asMap(json['next_month_preview']),
      ),
    );
  }

  final DateTime periodMonth;
  final String currency;
  final int totalIncomingRolloverCents;
  final int openingRolloverCents;
  final int currentRolloverTotalCents;
  final List<PocketRolloverContribution> contributions;
  final List<PocketRolloverContribution> adjustments;
  final List<PocketRolloverHistoryMonth> monthlyHistory;
  final List<PocketRolloverWarning> warnings;
  final PocketRolloverNextMonthPreview nextMonthPreview;

  bool get hasDetailedContributions =>
      contributions.isNotEmpty || adjustments.isNotEmpty;

  List<PocketRolloverContribution> get explanationRows => [
        ...contributions,
        ...adjustments.where(
          (adjustment) =>
              adjustment.sourceType == 'cap_adjustment' ||
              adjustment.sourceType == 'negative_dropped' ||
              adjustment.sourceType == 'reset',
        ),
      ];
}

class PocketRolloverContribution {
  const PocketRolloverContribution({
    required this.sourceType,
    required this.sourcePeriodMonth,
    required this.label,
    required this.amountCents,
    required this.remainingCentsAfterAdjustment,
    required this.isCarried,
    required this.reason,
  });

  factory PocketRolloverContribution.fromJson(Map<String, dynamic> json) {
    return PocketRolloverContribution(
      sourceType: json['source_type']?.toString() ?? 'month_surplus',
      sourcePeriodMonth: _parseNullableDate(json['source_period_month']),
      label: json['label']?.toString() ?? '',
      amountCents: _parseInt(json['amount_cents']),
      remainingCentsAfterAdjustment:
          _parseInt(json['remaining_cents_after_adjustment']),
      isCarried: json['is_carried'] == true,
      reason: json['reason']?.toString(),
    );
  }

  final String sourceType;
  final DateTime? sourcePeriodMonth;
  final String label;
  final int amountCents;
  final int remainingCentsAfterAdjustment;
  final bool isCarried;
  final String? reason;

  bool get isPositive => amountCents > 0;
  bool get isNegative => amountCents < 0;
}

class PocketRolloverHistoryMonth {
  const PocketRolloverHistoryMonth({
    required this.periodMonth,
    required this.baseBudgetCents,
    required this.rolloverFromPreviousCents,
    required this.openingRolloverCents,
    required this.availableBudgetCents,
    required this.spentCents,
    required this.remainingCents,
    required this.carryToNextCents,
    required this.rolloverEnabled,
    required this.rolloverNegative,
    required this.rolloverCapCents,
    required this.capAppliedCents,
    required this.negativeDroppedCents,
  });

  factory PocketRolloverHistoryMonth.fromJson(Map<String, dynamic> json) {
    return PocketRolloverHistoryMonth(
      periodMonth: _parseDate(json['period_month']),
      baseBudgetCents: _parseInt(json['base_budget_cents']),
      rolloverFromPreviousCents: _parseInt(
        json['incoming_rollover_cents'] ?? json['rollover_from_previous_cents'],
      ),
      openingRolloverCents: _parseInt(json['opening_rollover_cents']),
      availableBudgetCents: _parseInt(json['available_budget_cents']),
      spentCents: _parseInt(json['spent_cents']),
      remainingCents: _parseInt(json['remaining_cents']),
      carryToNextCents: _parseInt(
        json['carry_to_next_cents'],
        fallback: _parseInt(json['remaining_cents']),
      ),
      rolloverEnabled: json['rollover_enabled'] == true,
      rolloverNegative: json['rollover_negative'] == true,
      rolloverCapCents: json['rollover_cap_cents'] == null
          ? null
          : _parseInt(json['rollover_cap_cents']),
      capAppliedCents: _parseInt(json['cap_applied_cents']),
      negativeDroppedCents: _parseInt(json['negative_dropped_cents']),
    );
  }

  final DateTime periodMonth;
  final int baseBudgetCents;
  final int rolloverFromPreviousCents;
  final int openingRolloverCents;
  final int availableBudgetCents;
  final int spentCents;
  final int remainingCents;
  final int carryToNextCents;
  final bool rolloverEnabled;
  final bool rolloverNegative;
  final int? rolloverCapCents;
  final int capAppliedCents;
  final int negativeDroppedCents;
}

class PocketRolloverWarning {
  const PocketRolloverWarning({
    required this.code,
    required this.message,
  });

  factory PocketRolloverWarning.fromJson(Map<String, dynamic> json) {
    return PocketRolloverWarning(
      code: json['code']?.toString() ?? 'warning',
      message: json['message']?.toString() ?? '',
    );
  }

  final String code;
  final String message;
}

class PocketRolloverNextMonthPreview {
  const PocketRolloverNextMonthPreview({
    required this.periodMonth,
    required this.rawCarryCents,
    required this.carryCents,
    required this.capAppliedCents,
    required this.negativeDroppedCents,
    required this.rolloverNegative,
    required this.rolloverCapCents,
  });

  factory PocketRolloverNextMonthPreview.fromJson(Map<String, dynamic> json) {
    return PocketRolloverNextMonthPreview(
      periodMonth: _parseDate(json['period_month']),
      rawCarryCents: _parseInt(json['raw_carry_cents']),
      carryCents: _parseInt(json['carry_cents']),
      capAppliedCents: _parseInt(json['cap_applied_cents']),
      negativeDroppedCents: _parseInt(json['negative_dropped_cents']),
      rolloverNegative: json['rollover_negative'] == true,
      rolloverCapCents: json['rollover_cap_cents'] == null
          ? null
          : _parseInt(json['rollover_cap_cents']),
    );
  }

  final DateTime periodMonth;
  final int rawCarryCents;
  final int carryCents;
  final int capAppliedCents;
  final int negativeDroppedCents;
  final bool rolloverNegative;
  final int? rolloverCapCents;

  bool get hasCapAdjustment => capAppliedCents > 0;
  bool get hasDroppedNegative => negativeDroppedCents > 0;
}

List<T> _parseList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  return ((value as List?) ?? const [])
      .whereType<Map>()
      .map((row) => parse(Map<String, dynamic>.from(row)))
      .toList(growable: false);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int _parseInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

DateTime _parseDate(Object? value) {
  return _parseNullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _parseNullableDate(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty || raw == 'null') return null;
  return DateTime.tryParse(raw);
}
