class BankConnection {
  const BankConnection({
    required this.id,
    this.householdId,
    this.provider,
    this.status,
    this.itemStatus,
    this.itemHealthState,
    this.relinkState,
    this.institutionName,
    this.lastSuccessfulSyncAt,
    this.nextManualRefreshEligibleAt,
    this.scheduledRemovalAt,
    this.linkedBankAccountCount = 0,
    this.linkedWalletCount = 0,
    this.canReconnect = false,
    this.canDisconnect = false,
    this.canReviewAccounts = false,
    this.roleGuidance,
    this.latestErrorCode,
    this.reviewCompletedAt,
  });

  final String id;
  final String? householdId;
  final String? provider;
  final String? status;
  final String? itemStatus;
  final String? itemHealthState;
  final String? relinkState;
  final String? institutionName;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? nextManualRefreshEligibleAt;
  final DateTime? scheduledRemovalAt;
  final int linkedBankAccountCount;
  final int linkedWalletCount;
  final bool canReconnect;
  final bool canDisconnect;
  final bool canReviewAccounts;
  final String? roleGuidance;
  final String? latestErrorCode;
  final DateTime? reviewCompletedAt;

  factory BankConnection.fromJson(Map<String, dynamic> json) {
    final metadata = _resolveMetadata(json['metadata']);
    return BankConnection(
      id: _stringOrEmpty(json['id']),
      householdId: _nullableString(json['household_id']),
      provider: _nullableString(json['provider']),
      status: _nullableString(json['status']),
      itemStatus: _nullableString(json['item_status']),
      itemHealthState: _nullableString(json['item_health_state']),
      relinkState: _nullableString(json['relink_state']),
      institutionName: _nullableString(metadata['institution_name']),
      lastSuccessfulSyncAt: _nullableDateTime(json['last_successful_sync_at']),
      nextManualRefreshEligibleAt:
          _nullableDateTime(json['next_manual_refresh_eligible_at']),
      scheduledRemovalAt: _nullableDateTime(json['scheduled_removal_at']),
      linkedBankAccountCount: _intOrZero(json['linked_bank_account_count']),
      linkedWalletCount: _intOrZero(json['linked_wallet_count']),
      canReconnect: json['can_reconnect'] == true,
      canDisconnect: json['can_disconnect'] == true,
      canReviewAccounts: json['can_review_accounts'] == true,
      roleGuidance: _nullableString(json['role_guidance']),
      latestErrorCode: _nullableString(json['latest_error_code']),
      reviewCompletedAt: _nullableDateTime(json['review_completed_at']),
    );
  }

  String get displayName {
    return displayNameOr(id);
  }

  String displayNameOr(String fallback) {
    final trimmedInstitutionName = institutionName?.trim();
    if (trimmedInstitutionName != null && trimmedInstitutionName.isNotEmpty) {
      return trimmedInstitutionName;
    }

    return fallback;
  }

  bool get needsReconnect =>
      status == 'needs_reauth' ||
      itemStatus == 'pending_relink' ||
      relinkState == 'required';

  bool get hasNewAccountsAvailable => relinkState == 'new_accounts_available';

  bool get isPendingRemoval =>
      itemStatus == 'pending_removal' || itemHealthState == 'removal_pending';

  bool get requiresUserAction =>
      !isPendingRemoval && (needsReconnect || hasNewAccountsAvailable);

  String actionDescription({
    required String newAccountsAvailable,
    required String needsRepair,
  }) {
    if (hasNewAccountsAvailable) {
      return newAccountsAvailable;
    }
    return needsRepair;
  }

  bool get isHealthy =>
      !isPendingRemoval &&
      (itemHealthState == null || itemHealthState == 'healthy');

  bool get canRequestManualRefresh =>
      isHealthy && !needsReconnect && !hasNewAccountsAvailable;

  bool get isRemoved => itemStatus == 'removed' || status == 'disabled';
  bool get needsFinishSetup =>
      linkedWalletCount == 0 &&
      !needsReconnect &&
      !isPendingRemoval &&
      !isRemoved &&
      reviewCompletedAt == null;
}

int _intOrZero(dynamic value) => value is num ? value.toInt() : 0;

String _stringOrEmpty(dynamic value) {
  if (value == null) return '';
  final result = value.toString().trim();
  return result.isEmpty ? '' : result;
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

DateTime? _nullableDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _resolveMetadata(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  return const <String, dynamic>{};
}
