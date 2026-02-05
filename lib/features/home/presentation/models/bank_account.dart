class BankAccount {
  final String id;
  final String name;
  final String? mask;
  final String? type;
  final String? subtype;
  final String? currency;
  final double? balanceCurrent;
  final double? balanceAvailable;
  final double? balanceLimit;
  final String? provider;
  final String? bankConnectionId;
  final String? connectionHouseholdId;
  final String? connectionStatus;
  final String? connectionProvider;

  const BankAccount({
    required this.id,
    required this.name,
    this.mask,
    this.type,
    this.subtype,
    this.currency,
    this.balanceCurrent,
    this.balanceAvailable,
    this.balanceLimit,
    this.provider,
    this.bankConnectionId,
    this.connectionHouseholdId,
    this.connectionStatus,
    this.connectionProvider,
  });

  String get displayName {
    final trimmedMask = mask?.trim();
    if (trimmedMask != null && trimmedMask.isNotEmpty) {
      return '$name ••••$trimmedMask';
    }
    return name;
  }

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    final connection = _resolveConnection(json['bank_connections']);
    return BankAccount(
      id: _stringOrEmpty(json['id']),
      name: _stringOrEmpty(json['name']),
      mask: json['mask'] as String?,
      type: json['type'] as String?,
      subtype: json['subtype'] as String?,
      currency: json['currency'] as String?,
      balanceCurrent: _parseDouble(json['balance_current']),
      balanceAvailable: _parseDouble(json['balance_available']),
      balanceLimit: _parseDouble(json['balance_limit']),
      provider: json['provider'] as String?,
      bankConnectionId: json['bank_connection_id'] as String?,
      connectionHouseholdId: connection['household_id'] as String?,
      connectionStatus: connection['status'] as String?,
      connectionProvider: connection['provider'] as String?,
    );
  }
}

String _stringOrEmpty(dynamic value) {
  if (value == null) return '';
  final result = value.toString().trim();
  return result.isEmpty ? '' : result;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Map<String, dynamic> _resolveConnection(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is List &&
      value.isNotEmpty &&
      value.first is Map<String, dynamic>) {
    return value.first as Map<String, dynamic>;
  }
  return const <String, dynamic>{};
}
