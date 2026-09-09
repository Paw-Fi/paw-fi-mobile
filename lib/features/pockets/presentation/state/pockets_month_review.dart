class PocketsMonthReview {
  const PocketsMonthReview({
    required this.id,
    this.status = 'unreviewed',
    required this.isOutstanding,
    required this.setupRevision,
    required this.reviewedAt,
    this.monthlyBudgetCents = 0,
    required this.unassignedCents,
    required this.carryCents,
    required this.facts,
    required this.suggestions,
    this.currency = '',
    this.canEdit = false,
    this.isCurrentPeriod = false,
  });

  final String id;
  final String status;
  final bool isOutstanding;
  final int setupRevision;
  final String? reviewedAt;
  final int monthlyBudgetCents;
  final int unassignedCents;
  final int carryCents;
  final Map<String, dynamic> facts;
  final List<PocketsMonthReviewSuggestion> suggestions;
  final String currency;
  final bool canEdit;
  final bool isCurrentPeriod;

  bool get isPendingConfirmation => status == 'pending_sync';

  bool get hasHouseholdConflict => status == 'household_conflict';

  bool get canAutoOpen =>
      isOutstanding && canEdit && isCurrentPeriod && !isPendingConfirmation;

  int get fixedAllocatedCents {
    final suggestedEnvelopeIds = suggestions
        .map((suggestion) => suggestion.envelopeId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return _listValue(facts['current_allocations'])
        .whereType<Map>()
        .where((allocation) => !suggestedEnvelopeIds
            .contains(allocation['envelope_id']?.toString()))
        .fold<int>(
          0,
          (sum, allocation) => sum + _intValue(allocation['amount_cents']),
        );
  }

  int get draftBudgetCents => monthlyBudgetCents - fixedAllocatedCents;

  factory PocketsMonthReview.fromJson(Map<String, dynamic> json) {
    final setup = _mapValue(json['setup']);
    final suggestions = _listValue(
      json['suggestions'] ?? json['allocation_suggestions'],
    )
        .whereType<Map>()
        .map(
          (item) => PocketsMonthReviewSuggestion.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.lineageId.isNotEmpty)
        .toList(growable: false);
    final reviewedAt = json['reviewed_at']?.toString();
    return PocketsMonthReview(
      id: (json['id'] ?? json['review_id'] ?? json['month_key'] ?? '')
          .toString(),
      status:
          (json['status'] ?? (reviewedAt == null ? 'unreviewed' : 'confirmed'))
              .toString(),
      isOutstanding:
          reviewedAt == null && json['status']?.toString() != 'pending_sync',
      setupRevision: _intValue(
        json['setup_revision'] ??
            json['review_setup_revision'] ??
            setup['revision'],
      ),
      reviewedAt: reviewedAt,
      monthlyBudgetCents: _intValue(json['monthly_budget_cents']),
      unassignedCents: _intValue(
        json['unassigned_cents'] ?? json['remaining_cents'],
      ),
      carryCents: _intValue(json['carry_cents'] ?? json['rollover_cents']),
      facts: {
        ..._mapValue(json['facts']),
        'current_allocations': _listValue(json['current_allocations']),
      },
      suggestions: suggestions,
      currency: (json['currency'] ?? json['selected_currency'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
      canEdit: json['can_edit'] == true,
      isCurrentPeriod: json['is_current_period'] == true,
    );
  }

  static PocketsMonthReview? fromV4Payload(Map<String, dynamic> payload) {
    final pocketsV4 = _mapValue(payload['pockets_v4']);
    final rawReview = pocketsV4['review'];
    if (rawReview is Map) {
      final review = Map<String, dynamic>.from(rawReview);
      final parentFacts = _mapValue(pocketsV4['facts']);
      final reviewFacts = _mapValue(review['facts']);
      // Permissions live on the v4 parent. The review body is persisted review
      // data and does not reliably include the current scope/period metadata.
      return PocketsMonthReview.fromJson({
        ...review,
        if (payload['selected_currency'] != null)
          'currency': payload['selected_currency'],
        if (pocketsV4.containsKey('can_edit'))
          'can_edit': pocketsV4['can_edit'],
        if (pocketsV4.containsKey('is_current_period'))
          'is_current_period': pocketsV4['is_current_period'],
        if (!review.containsKey('carry_cents') &&
            pocketsV4.containsKey('carry_cents'))
          'carry_cents': pocketsV4['carry_cents'],
        'facts': {
          ...parentFacts,
          ...reviewFacts,
          for (final key in const [
            'last_cycle_allocations',
            'previous_allocations',
            'last_confirmed_allocations',
          ])
            if (!reviewFacts.containsKey(key) && pocketsV4.containsKey(key))
              key: pocketsV4[key],
        },
      });
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'is_outstanding': isOutstanding,
        'setup_revision': setupRevision,
        'reviewed_at': reviewedAt,
        'monthly_budget_cents': monthlyBudgetCents,
        'unassigned_cents': unassignedCents,
        'carry_cents': carryCents,
        'facts': facts,
        'suggestions': suggestions.map((item) => item.toJson()).toList(),
        'currency': currency,
        'can_edit': canEdit,
        'is_current_period': isCurrentPeriod,
      };

  PocketsMonthReview copyWith({String? status, String? reviewedAt}) =>
      PocketsMonthReview(
        id: id,
        status: status ?? this.status,
        isOutstanding: (status ?? this.status) != 'pending_sync' &&
            (reviewedAt ?? this.reviewedAt) == null,
        setupRevision: setupRevision,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        monthlyBudgetCents: monthlyBudgetCents,
        unassignedCents: unassignedCents,
        carryCents: carryCents,
        facts: facts,
        suggestions: suggestions,
        currency: currency,
        canEdit: canEdit,
        isCurrentPeriod: isCurrentPeriod,
      );
}

class PocketsMonthReviewSuggestion {
  const PocketsMonthReviewSuggestion({
    required this.envelopeId,
    required this.lineageId,
    required this.label,
    required this.amountCents,
    this.incomingCarryCents = 0,
    this.fundingPolicy = '',
    this.reasonCode = '',
  });

  final String envelopeId;
  final String lineageId;
  final String label;
  final int amountCents;
  final int incomingCarryCents;
  final String fundingPolicy;
  final String reasonCode;

  factory PocketsMonthReviewSuggestion.fromJson(Map<String, dynamic> json) {
    return PocketsMonthReviewSuggestion(
      envelopeId: (json['envelope_id'] ?? json['pocket_id'] ?? '').toString(),
      lineageId: (json['lineage_id'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? '').toString(),
      amountCents: _intValue(
        json['amount_cents'] ?? json['suggested_amount_cents'],
      ),
      incomingCarryCents: _intValue(json['incoming_carry_cents']),
      fundingPolicy: (json['funding_policy'] ?? '').toString(),
      reasonCode: (json['reason_code'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'envelope_id': envelopeId,
        'lineage_id': lineageId,
        'label': label,
        'amount_cents': amountCents,
        'incoming_carry_cents': incomingCarryCents,
        'funding_policy': fundingPolicy,
        'reason_code': reasonCode,
      };
}

class PocketsMonthAiReview {
  const PocketsMonthAiReview({
    required this.teaser,
    required this.review,
  });

  final String? teaser;
  final PocketsMonthAiReviewContent? review;

  factory PocketsMonthAiReview.fromJson(Map<String, dynamic> json) {
    return PocketsMonthAiReview(
      teaser: json['teaser']?.toString(),
      review: json['review'] is Map
          ? PocketsMonthAiReviewContent.fromJson(
              Map<String, dynamic>.from(json['review'] as Map),
            )
          : null,
    );
  }

  String? get displayText => review?.headline.text ?? teaser;
}

class PocketsMonthAiReviewContent {
  const PocketsMonthAiReviewContent({
    required this.headline,
    required this.celebration,
    required this.previousCycleSummary,
    required this.attentionItems,
    required this.recommendations,
    required this.pocketExplanations,
  });

  final PocketsMonthAiReviewText headline;
  final PocketsMonthAiReviewText celebration;
  final PocketsMonthAiReviewText previousCycleSummary;
  final List<PocketsMonthAiReviewText> attentionItems;
  final List<PocketsMonthAiReviewText> recommendations;
  final List<PocketsMonthAiPocketExplanation> pocketExplanations;

  factory PocketsMonthAiReviewContent.fromJson(Map<String, dynamic> json) =>
      PocketsMonthAiReviewContent(
        headline:
            PocketsMonthAiReviewText.fromJson(_mapValue(json['headline'])),
        celebration:
            PocketsMonthAiReviewText.fromJson(_mapValue(json['celebration'])),
        previousCycleSummary: PocketsMonthAiReviewText.fromJson(
          _mapValue(json['previous_cycle_summary']),
        ),
        attentionItems: _reviewTextList(json['attention_items']),
        recommendations: _reviewTextList(json['recommendations']),
        pocketExplanations: _listValue(json['pocket_explanations'])
            .whereType<Map>()
            .map((item) => PocketsMonthAiPocketExplanation.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false),
      );
}

class PocketsMonthAiReviewText {
  const PocketsMonthAiReviewText({required this.text, required this.factIds});

  final String text;
  final List<String> factIds;

  factory PocketsMonthAiReviewText.fromJson(Map<String, dynamic> json) =>
      PocketsMonthAiReviewText(
        text: (json['text'] ?? '').toString(),
        factIds: _listValue(json['fact_ids'])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      );
}

class PocketsMonthAiPocketExplanation extends PocketsMonthAiReviewText {
  const PocketsMonthAiPocketExplanation({
    required this.lineageId,
    required super.text,
    required super.factIds,
  });

  final String lineageId;

  factory PocketsMonthAiPocketExplanation.fromJson(Map<String, dynamic> json) =>
      PocketsMonthAiPocketExplanation(
        lineageId: (json['pocket_lineage_id'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
        factIds: _listValue(json['fact_ids'])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      );
}

List<PocketsMonthAiReviewText> _reviewTextList(Object? value) =>
    _listValue(value)
        .whereType<Map>()
        .map((item) => PocketsMonthAiReviewText.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.text.isNotEmpty)
        .toList(growable: false);

bool shouldPreservePocketsMonthReviewDraft({
  required PocketsMonthReview? current,
  required PocketsMonthReview? refreshed,
}) =>
    current != null &&
    refreshed != null &&
    (current.isOutstanding || current.isPendingConfirmation) &&
    (refreshed.isOutstanding || refreshed.isPendingConfirmation) &&
    current.setupRevision == refreshed.setupRevision;

String pocketsMonthReviewDraftKey(PocketsMonthReview review) =>
    '${review.id.isEmpty ? 'review' : review.id}:${review.currency.toUpperCase()}:r${review.setupRevision}';

String pocketsMonthReviewAutoOpenKey({
  required PocketsMonthReview review,
  required String scope,
  required String? householdId,
}) =>
    'pockets_month_review_auto_opened:'
    '$scope:${householdId ?? 'personal'}:'
    '${review.id.isEmpty ? review.currency : review.id}:'
    'r${review.setupRevision}';

Map<String, Map<String, int>> retainPocketsMonthReviewDrafts({
  required Map<String, Map<String, int>> draftsByReviewKey,
  required Iterable<PocketsMonthReview> reviews,
}) =>
    {
      for (final review in reviews)
        if (draftsByReviewKey[pocketsMonthReviewDraftKey(review)]
            case final draft?)
          pocketsMonthReviewDraftKey(review): draft,
    };

String pocketsMonthReviewDraftHash(
    Map<String, int> allocationsCentsByLineageId) {
  var hash = 0x811c9dc5;
  final entries = allocationsCentsByLineageId.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  for (final entry in entries) {
    for (final codeUnit in '${entry.key}:${entry.value};'.codeUnits) {
      hash = (hash ^ codeUnit) * 0x01000193 & 0xffffffff;
    }
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String buildPocketsMonthReviewMutationId({
  required String userId,
  required String reviewId,
  required String periodMonth,
  required String currency,
  required int setupRevision,
  required Map<String, int> allocationsCentsByLineageId,
}) =>
    'mobile:pockets_review_${userId}_${reviewId.isEmpty ? periodMonth : reviewId}_${currency}_r${setupRevision}_${pocketsMonthReviewDraftHash(allocationsCentsByLineageId)}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

Map<String, dynamic> buildPocketsMonthReviewConfirmationPayload({
  required String userId,
  required String scope,
  required String? householdId,
  required String budgetMonth,
  required String currency,
  required PocketsMonthReview review,
  required Map<String, int> allocationsCentsByLineageId,
}) =>
    {
      'p_user_id': userId,
      'p_scope': scope,
      'p_household_id': householdId,
      'p_budget_month': budgetMonth,
      'p_currency': currency,
      'p_expected_setup_revision': review.setupRevision,
      'p_allocations': (allocationsCentsByLineageId.entries.toList()
            ..sort((left, right) => left.key.compareTo(right.key)))
          .where((entry) => entry.key.trim().isNotEmpty)
          .map(
            (entry) => {
              'lineage_id': entry.key,
              'amount_cents': entry.value,
            },
          )
          .toList(growable: false),
    };

class PocketsMonthReviewDraftValidation {
  const PocketsMonthReviewDraftValidation({
    required this.isValid,
    required this.allocatedCents,
  });

  final bool isValid;
  final int allocatedCents;
}

PocketsMonthReviewDraftValidation validatePocketsMonthReviewDraft({
  required PocketsMonthReview review,
  required Map<String, int> allocationsCentsByEnvelopeId,
}) {
  final allocations = allocationsCentsByEnvelopeId.entries.where(
    (entry) => entry.key.trim().isNotEmpty,
  );
  final hasNegativeAllocation = allocations.any((entry) => entry.value < 0);
  final allocatedCents = allocations.fold<int>(
    0,
    (sum, entry) => sum + entry.value,
  );
  return PocketsMonthReviewDraftValidation(
    isValid:
        !hasNegativeAllocation && allocatedCents <= review.draftBudgetCents,
    allocatedCents: allocatedCents,
  );
}

class PocketsMonthReviewVisitGate {
  bool _hasShown = false;

  bool shouldShow(PocketsMonthReview? review) {
    if (review == null || !review.canAutoOpen) return false;
    if (_hasShown) return false;
    _hasShown = true;
    return true;
  }

  void resetForNewVisit() => _hasShown = false;
}

List<dynamic> _listValue(Object? value) => value is List ? value : const [];

Map<String, dynamic> _mapValue(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

int _intValue(Object? value) => value is num ? value.round() : 0;
