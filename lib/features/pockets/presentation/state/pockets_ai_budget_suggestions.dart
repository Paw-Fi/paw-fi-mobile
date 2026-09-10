import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

class PocketsAiBudgetSuggestionsRequest {
  const PocketsAiBudgetSuggestionsRequest({
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  @override
  bool operator ==(Object other) =>
      other is PocketsAiBudgetSuggestionsRequest &&
      other.scopeParams == scopeParams &&
      other.currency.toUpperCase() == currency.toUpperCase();

  @override
  int get hashCode => Object.hash(scopeParams, currency.toUpperCase());
}

class PocketsAiBudgetSuggestion {
  const PocketsAiBudgetSuggestion({
    required this.envelopeId,
    required this.amountCents,
    required this.reason,
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
      amountCents: amountCents.toInt(),
      reason: reason,
    );
  }

  final String envelopeId;
  final int amountCents;
  final String reason;
}

class PocketsAiBudgetSuggestions {
  const PocketsAiBudgetSuggestions({
    required this.summary,
    required this.suggestions,
    required this.isFallback,
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
      suggestions: suggestions
          .whereType<Map>()
          .map((item) => PocketsAiBudgetSuggestion.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
      isFallback: json['deterministicFallback'] == true,
    );
  }

  final String summary;
  final List<PocketsAiBudgetSuggestion> suggestions;
  final bool isFallback;
}

class PocketsAiBudgetSuggestionsException implements Exception {
  const PocketsAiBudgetSuggestionsException(this.message, {this.code});

  final String message;
  final String? code;

  bool get isPlusDenied => code == 'SUBSCRIPTION_REQUIRED';

  @override
  String toString() => message;
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
