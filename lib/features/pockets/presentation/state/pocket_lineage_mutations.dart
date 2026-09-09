import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

enum PocketRetirementDisposition {
  retireZero('retire_zero'),
  releasePositive('release_positive'),
  transferPositive('transfer_positive'),
  coverNegative('cover_negative'),
  transferNegative('transfer_negative');

  const PocketRetirementDisposition(this.value);

  final String value;

  bool get requiresTarget => switch (this) {
        transferPositive || coverNegative || transferNegative => true,
        retireZero || releasePositive => false,
      };
}

class PocketLineageMetadata {
  const PocketLineageMetadata({
    required this.lineageId,
    required this.revision,
    required this.fundingPolicy,
    this.fundingTargetCents,
  });

  factory PocketLineageMetadata.fromJson(Map<String, dynamic> json) {
    return PocketLineageMetadata(
      lineageId: (json['lineage_id'] ??
                  json['pocket_lineage_id'] ??
                  json['rollover_group_id'] ??
                  json['id'])
              ?.toString() ??
          '',
      revision: (json['revision'] as num?)?.toInt() ?? -1,
      fundingPolicy: json['funding_policy']?.toString() ?? 'decide_each_cycle',
      fundingTargetCents: (json['funding_target_cents'] as num?)?.toInt(),
    );
  }

  final String lineageId;
  final int revision;
  final String fundingPolicy;
  final int? fundingTargetCents;
}

String pocketsScopeRpcValue(PocketsScopeType scope) => switch (scope) {
      PocketsScopeType.personal => 'personal',
      PocketsScopeType.portfolio => 'portfolio',
      PocketsScopeType.household => 'household',
    };

Map<String, dynamic> buildPocketLineageFundingPayload({
  required String userId,
  required PocketsScopeType scope,
  required String? householdId,
  required PocketLineageMetadata metadata,
  required String fundingPolicy,
  required int? fundingTargetCents,
}) =>
    {
      'p_user_id': userId,
      'p_scope': pocketsScopeRpcValue(scope),
      'p_household_id': householdId,
      'p_lineage_id': metadata.lineageId,
      'p_expected_revision': metadata.revision,
      'p_funding_policy': fundingPolicy,
      'p_funding_target_cents': fundingTargetCents,
    };

Map<String, dynamic> buildPocketLineageLifecyclePayload({
  required String userId,
  required PocketsScopeType scope,
  required String? householdId,
  required String? lineageId,
  required int? expectedRevision,
  required String budgetMonth,
  required String currency,
  required String operationId,
  required String name,
  required String? icon,
  required String? color,
  required String? logoUrl,
  required bool rolloverEnabled,
  required bool rolloverNegative,
  required int? rolloverCapCents,
  required String fundingPolicy,
  required int? fundingTargetCents,
  required List<String> categories,
  required int currentAmountCents,
}) {
  final normalizedLineageId = lineageId?.trim();
  if (normalizedLineageId != null && normalizedLineageId.isEmpty) {
    throw ArgumentError('A pocket lineage ID cannot be empty.');
  }
  if (normalizedLineageId != null &&
      (expectedRevision == null || expectedRevision < 0)) {
    throw ArgumentError('An existing pocket requires its loaded revision.');
  }
  final normalizedCategories = categories
      .map((category) => category.trim().toLowerCase())
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList(growable: false);
  return {
    'p_user_id': userId,
    'p_scope': pocketsScopeRpcValue(scope),
    'p_household_id': householdId,
    'p_lineage_id': normalizedLineageId,
    'p_expected_revision': expectedRevision,
    'p_budget_month': budgetMonth,
    'p_currency': currency.trim().toUpperCase(),
    'p_operation_id': operationId,
    'p_name': name.trim(),
    'p_icon': icon,
    'p_color': color,
    'p_logo_url': logoUrl,
    'p_rollover_enabled': rolloverEnabled,
    'p_rollover_negative': rolloverNegative,
    'p_rollover_cap_cents': rolloverCapCents,
    'p_funding_policy': fundingPolicy,
    'p_funding_target_cents': fundingTargetCents,
    'p_categories': normalizedCategories,
    'p_current_amount_cents': currentAmountCents,
  };
}

Map<String, dynamic> buildPocketLineageCategoriesPayload({
  required String userId,
  required PocketsScopeType scope,
  required String? householdId,
  required PocketLineageMetadata metadata,
  required String effectiveMonth,
  required List<String> categories,
  required bool followsFundingChange,
}) =>
    {
      'p_user_id': userId,
      'p_scope': pocketsScopeRpcValue(scope),
      'p_household_id': householdId,
      'p_lineage_id': metadata.lineageId,
      'p_expected_revision': metadata.revision + (followsFundingChange ? 1 : 0),
      'p_effective_month': effectiveMonth,
      'p_categories': categories
          .map((category) => category.trim().toLowerCase())
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList(growable: false),
    };

Map<String, dynamic> buildPocketLineageRetirementPayload({
  required String userId,
  required PocketsScopeType scope,
  required String? householdId,
  required PocketLineageMetadata metadata,
  required String effectiveMonth,
  required PocketRetirementDisposition disposition,
  required String? targetLineageId,
}) {
  final target = targetLineageId?.trim();
  if (disposition.requiresTarget && (target == null || target.isEmpty)) {
    throw ArgumentError('A target pocket is required for this disposition.');
  }
  if (!disposition.requiresTarget && target != null && target.isNotEmpty) {
    throw ArgumentError('This disposition does not accept a target pocket.');
  }
  return {
    'p_user_id': userId,
    'p_scope': pocketsScopeRpcValue(scope),
    'p_household_id': householdId,
    'p_lineage_id': metadata.lineageId,
    'p_effective_month': effectiveMonth,
    'p_expected_revision': metadata.revision,
    'p_disposition': disposition.value,
    'p_target_lineage_id': target,
  };
}
