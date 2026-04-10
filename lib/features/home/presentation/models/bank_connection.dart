class BankConnection {
  const BankConnection({
    required this.id,
    this.householdId,
    this.provider,
    this.status,
    this.institutionName,
  });

  final String id;
  final String? householdId;
  final String? provider;
  final String? status;
  final String? institutionName;

  factory BankConnection.fromJson(Map<String, dynamic> json) {
    final metadata = _resolveMetadata(json['metadata']);
    return BankConnection(
      id: _stringOrEmpty(json['id']),
      householdId: _nullableString(json['household_id']),
      provider: _nullableString(json['provider']),
      status: _nullableString(json['status']),
      institutionName: _nullableString(metadata['institution_name']),
    );
  }

  String get displayName {
    final trimmedInstitutionName = institutionName?.trim();
    if (trimmedInstitutionName != null && trimmedInstitutionName.isNotEmpty) {
      return trimmedInstitutionName;
    }

    return 'Bank connection';
  }
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

Map<String, dynamic> _resolveMetadata(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  return const <String, dynamic>{};
}
