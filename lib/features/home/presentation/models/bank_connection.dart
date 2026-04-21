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
    );
  }

  String get displayName {
    final trimmedInstitutionName = institutionName?.trim();
    if (trimmedInstitutionName != null && trimmedInstitutionName.isNotEmpty) {
      return trimmedInstitutionName;
    }

    return 'Bank connection';
  }

  bool get needsReconnect =>
      status == 'needs_reauth' || relinkState == 'required';

  bool get isHealthy => itemHealthState == null || itemHealthState == 'healthy';
}

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
