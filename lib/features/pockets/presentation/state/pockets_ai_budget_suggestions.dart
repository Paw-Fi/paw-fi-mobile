import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

class PocketsAiBudgetSuggestionsRequest {
  const PocketsAiBudgetSuggestionsRequest({
    required this.scopeParams,
    required this.currency,
    required this.locale,
  });

  final PocketsScopeParams scopeParams;
  final String currency;
  final String locale;

  @override
  bool operator ==(Object other) =>
      other is PocketsAiBudgetSuggestionsRequest &&
      other.scopeParams == scopeParams &&
      other.currency.toUpperCase() == currency.toUpperCase() &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(scopeParams, currency.toUpperCase(), locale);
}

class PocketsAiBudgetSuggestion {
  const PocketsAiBudgetSuggestion({
    required this.envelopeId,
    required this.pocketName,
    required this.amountCents,
    required this.reason,
    this.tip,
    this.changeType,
    this.icon,
    this.color,
    this.previousSpentCents,
    this.previousBudgetCents,
    this.incomingCarryCents,
    this.rolloverEnabled = false,
    this.remainingCents,
  });

  factory PocketsAiBudgetSuggestion.fromJson(Map<String, dynamic> json) {
    final envelopeId = json['envelope_id'];
    final amountCents = json['suggested_amount_cents'];
    final reason = json['reason'];
    if (envelopeId is! String || amountCents is! num || reason is! String) {
      throw const PocketsAiBudgetSuggestionsException(
        'The AI returned an invalid suggestion.',
      );
    }
    return PocketsAiBudgetSuggestion(
      envelopeId: envelopeId,
      pocketName:
          json['pocket_name'] is String ? json['pocket_name'] as String : null,
      amountCents: amountCents.toInt(),
      reason: reason,
      tip: json['tip'] is String ? json['tip'] as String : null,
      changeType:
          json['change_type'] is String ? json['change_type'] as String : null,
      icon: json['icon'] is String ? json['icon'] as String : null,
      color: json['color'] is String ? json['color'] as String : null,
      previousSpentCents: json['previous_spent_cents'] is num
          ? (json['previous_spent_cents'] as num).toInt()
          : null,
      previousBudgetCents: json['previous_budget_cents'] is num
          ? (json['previous_budget_cents'] as num).toInt()
          : null,
      incomingCarryCents: json['incoming_carry_cents'] is num
          ? (json['incoming_carry_cents'] as num).toInt()
          : null,
      rolloverEnabled: json['rollover_enabled'] == true,
      remainingCents: json['remaining_cents'] is num
          ? (json['remaining_cents'] as num).toInt()
          : null,
    );
  }

  final String envelopeId;
  final String? pocketName;
  final int amountCents;
  final String reason;
  final String? tip;
  final String? changeType;
  final String? icon;
  final String? color;
  final int? previousSpentCents;
  final int? previousBudgetCents;
  final int? incomingCarryCents;
  final bool rolloverEnabled;
  final int? remainingCents;
}

class PocketsAiBudgetInsight {
  const PocketsAiBudgetInsight({
    required this.type,
    required this.title,
    required this.summary,
    this.action,
    this.estimatedImpactCents,
    this.envelopeId,
  });

  factory PocketsAiBudgetInsight.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final title = json['title'];
    final summary = json['summary'];
    if (type is! String || title is! String || summary is! String) {
      throw const PocketsAiBudgetSuggestionsException(
        'The AI returned an invalid insight.',
      );
    }
    return PocketsAiBudgetInsight(
      type: type,
      title: title,
      summary: summary,
      action: json['action'] is String ? json['action'] as String : null,
      estimatedImpactCents: json['estimated_impact_cents'] is num
          ? (json['estimated_impact_cents'] as num).toInt()
          : null,
      envelopeId:
          json['envelope_id'] is String ? json['envelope_id'] as String : null,
    );
  }

  final String type;
  final String title;
  final String summary;
  final String? action;
  final int? estimatedImpactCents;
  final String? envelopeId;
}

class PocketsAiKnownCashFlow {
  const PocketsAiKnownCashFlow({
    required this.dataStatus,
    required this.incomeCoverageStatus,
    required this.monthFundingStatus,
    required this.recordedIncomeCents,
    required this.projectedRecurringIncomeCents,
    required this.knownIncomeCents,
    required this.actualExpenseCents,
    required this.projectedRecurringExpenseCents,
    required this.knownOutflowCents,
    required this.incomeMarginCents,
    required this.incomingCarryCents,
    required this.knownFundingCents,
    required this.fundingMarginAfterCarryCents,
    required this.knownCommitmentsCovered,
    required this.safeToSpendStatus,
  });

  factory PocketsAiKnownCashFlow.fromJson(Map<String, dynamic> json) {
    int requiredCents(String key) {
      final value = json[key];
      if (value is! num) {
        throw const PocketsAiBudgetSuggestionsException(
          'The AI returned invalid cash-flow context.',
        );
      }
      return value.toInt();
    }

    final dataStatus = json['data_status'];
    final incomeCoverageStatus = json['income_coverage_status'];
    final monthFundingStatus = json['month_funding_status'];
    if (dataStatus is! String ||
        incomeCoverageStatus is! String ||
        monthFundingStatus is! String) {
      throw const PocketsAiBudgetSuggestionsException(
        'The AI returned invalid cash-flow context.',
      );
    }
    return PocketsAiKnownCashFlow(
      dataStatus: dataStatus,
      incomeCoverageStatus: incomeCoverageStatus,
      monthFundingStatus: monthFundingStatus,
      recordedIncomeCents: requiredCents('recorded_income_cents'),
      projectedRecurringIncomeCents:
          requiredCents('projected_recurring_income_cents'),
      knownIncomeCents: requiredCents('known_income_cents'),
      actualExpenseCents: requiredCents('actual_expense_cents'),
      projectedRecurringExpenseCents:
          requiredCents('projected_recurring_expense_cents'),
      knownOutflowCents: requiredCents('known_outflow_cents'),
      incomeMarginCents: requiredCents('income_margin_cents'),
      incomingCarryCents: requiredCents('incoming_carry_cents'),
      knownFundingCents: requiredCents('known_funding_cents'),
      fundingMarginAfterCarryCents:
          requiredCents('funding_margin_after_carry_cents'),
      knownCommitmentsCovered: json['known_commitments_covered'] as bool?,
      safeToSpendStatus: json['safe_to_spend_status'] as String?,
    );
  }

  final String dataStatus;
  final String incomeCoverageStatus;
  final String monthFundingStatus;
  final int recordedIncomeCents;
  final int projectedRecurringIncomeCents;
  final int knownIncomeCents;
  final int actualExpenseCents;
  final int projectedRecurringExpenseCents;
  final int knownOutflowCents;
  final int incomeMarginCents;
  final int incomingCarryCents;
  final int knownFundingCents;
  final int fundingMarginAfterCarryCents;
  final bool? knownCommitmentsCovered;
  final String? safeToSpendStatus;
}

class PocketsAiBudgetSuggestions {
  const PocketsAiBudgetSuggestions({
    required this.summary,
    required this.suggestions,
    required this.usesPreviousMonthPockets,
    this.headline,
    this.financialStatus,
    this.cashFlow,
    this.insights = const [],
    this.celebration,
    this.topSpendInsight,
    this.pocketsHealthTip,
    this.totalSuggestedCents,
    this.suggestedTotalBudgetCents,
  });

  factory PocketsAiBudgetSuggestions.fromJson(Map<String, dynamic> json) {
    final payload = json['suggestions'];
    if (payload is! Map) {
      throw const PocketsAiBudgetSuggestionsException(
        'The AI suggestions were unavailable.',
      );
    }
    final suggestions = payload['suggestions'];
    if (suggestions is! List) {
      throw const PocketsAiBudgetSuggestionsException(
        'The AI suggestions were unavailable.',
      );
    }
    return PocketsAiBudgetSuggestions(
      summary: payload['summary'] is String ? payload['summary'] as String : '',
      headline:
          payload['headline'] is String ? payload['headline'] as String : null,
      financialStatus: payload['financial_status'] is String
          ? payload['financial_status'] as String
          : null,
      cashFlow: payload['cash_flow'] is Map
          ? PocketsAiKnownCashFlow.fromJson(
              Map<String, dynamic>.from(payload['cash_flow'] as Map),
            )
          : null,
      insights: payload['insights'] is List
          ? (payload['insights'] as List).map((item) {
              if (item is! Map) {
                throw const PocketsAiBudgetSuggestionsException(
                  'The AI returned an invalid insight.',
                );
              }
              return PocketsAiBudgetInsight.fromJson(
                Map<String, dynamic>.from(item),
              );
            }).toList(growable: false)
          : const [],
      celebration: payload['celebration'] is String
          ? payload['celebration'] as String
          : null,
      topSpendInsight: payload['top_spend_insight'] is String
          ? payload['top_spend_insight'] as String
          : null,
      pocketsHealthTip: payload['pockets_health_tip'] is String
          ? payload['pockets_health_tip'] as String
          : null,
      totalSuggestedCents: payload['total_suggested_cents'] is num
          ? (payload['total_suggested_cents'] as num).toInt()
          : null,
      suggestedTotalBudgetCents: payload['suggested_total_budget_cents'] is num
          ? (payload['suggested_total_budget_cents'] as num).toInt()
          : null,
      suggestions: suggestions
          .whereType<Map>()
          .map((item) => PocketsAiBudgetSuggestion.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
      usesPreviousMonthPockets: json['usesPreviousMonthPockets'] == true,
    );
  }

  final String summary;
  final String? headline;
  final String? financialStatus;
  final PocketsAiKnownCashFlow? cashFlow;
  final List<PocketsAiBudgetInsight> insights;
  final String? celebration;
  final String? topSpendInsight;
  final String? pocketsHealthTip;
  final int? totalSuggestedCents;
  final int? suggestedTotalBudgetCents;
  final List<PocketsAiBudgetSuggestion> suggestions;
  final bool usesPreviousMonthPockets;
}

class PocketsAiBudgetSuggestionsException implements Exception {
  const PocketsAiBudgetSuggestionsException(this.message, {this.code});

  final String message;
  final String? code;

  bool get isPlusDenied => code == 'SUBSCRIPTION_REQUIRED';

  @override
  String toString() => message;
}

/// Rebinds source-month suggestion IDs to the envelopes that were copied into
/// the active month. A partial map must never silently save an unrelated plan.
Map<String, int> rebindCopiedPocketSuggestionAmounts({
  required Map<String, int> sourceAmountsCents,
  required Map<String, String> copiedPocketIds,
}) {
  final reboundAmounts = <String, int>{};
  for (final entry in sourceAmountsCents.entries) {
    final copiedPocketId = copiedPocketIds[entry.key];
    if (copiedPocketId == null || copiedPocketId.isEmpty) {
      throw const PocketsAiBudgetSuggestionsException(
        'Your pockets changed while your plan was being prepared. Please try again.',
      );
    }
    reboundAmounts[copiedPocketId] = entry.value;
  }
  return reboundAmounts;
}

final pocketsAiBudgetSuggestionsProvider = FutureProvider.autoDispose
    .family<PocketsAiBudgetSuggestions, PocketsAiBudgetSuggestionsRequest>(
        (ref, request) async {
  final periodMonth = request.scopeParams.periodMonth;
  if (periodMonth == null) {
    throw const PocketsAiBudgetSuggestionsException(
      'Choose a month before generating suggestions.',
    );
  }
  final response = await supabase.functions.invoke(
    'generate-pocket-month-review',
    body: {
      'scope': switch (request.scopeParams.scope) {
        PocketsScopeType.personal => 'personal',
        PocketsScopeType.portfolio => 'portfolio',
        PocketsScopeType.household => 'household',
      },
      'householdId': request.scopeParams.householdId,
      'currency': request.currency.toUpperCase(),
      'cycleStart': _dateKey(periodMonth),
      'locale': request.locale,
    },
  );
  if (response.data is! Map) {
    throw const PocketsAiBudgetSuggestionsException(
      'The AI suggestions were unavailable.',
    );
  }
  final data = Map<String, dynamic>.from(response.data as Map);
  if (data['success'] != true) {
    throw PocketsAiBudgetSuggestionsException(
      data['error']?.toString() ?? 'The AI suggestions were unavailable.',
      code: data['code']?.toString(),
    );
  }
  return PocketsAiBudgetSuggestions.fromJson(data);
});

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
