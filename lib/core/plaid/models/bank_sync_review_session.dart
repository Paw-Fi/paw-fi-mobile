class BankSyncReviewSession {
  const BankSyncReviewSession({
    required this.connectionId,
    required this.flowReason,
    required this.provider,
    required this.targetHouseholdId,
    required this.accounts,
  });

  final String connectionId;
  final String? flowReason;
  final String provider;
  final String? targetHouseholdId;
  final List<BankSyncReviewAccount> accounts;

  factory BankSyncReviewSession.fromResponse({
    required Map<String, dynamic> data,
    required String? flowReason,
    required String provider,
    required String? targetHouseholdId,
  }) {
    final rawAccounts = data['accounts'] as List<dynamic>? ?? const [];
    return BankSyncReviewSession(
      connectionId: (data['connectionId'] as String?)?.trim() ?? '',
      flowReason:
          _normalizeString(data['flowReason']) ?? _normalizeString(flowReason),
      provider: provider,
      targetHouseholdId: _normalizeString(data['targetHouseholdId']) ??
          _normalizeString(targetHouseholdId),
      accounts: rawAccounts
          .whereType<Map<String, dynamic>>()
          .map(BankSyncReviewAccount.fromJson)
          .toList(growable: false),
    );
  }

  bool get hasAccounts => accounts.isNotEmpty;
}

class BankSyncReviewAccount {
  const BankSyncReviewAccount({
    required this.bankAccountId,
    required this.providerAccountId,
    required this.name,
    required this.currency,
    required this.mask,
    required this.type,
    required this.subtype,
    required this.walletId,
    required this.walletName,
    required this.walletIcon,
    required this.walletColor,
    required this.goalAmountCents,
    required this.openingBalanceCents,
    required this.isDefault,
  });

  final String bankAccountId;
  final String? providerAccountId;
  final String name;
  final String currency;
  final String? mask;
  final String? type;
  final String? subtype;
  final String? walletId;
  final String walletName;
  final String walletIcon;
  final String walletColor;
  final int? goalAmountCents;
  final int openingBalanceCents;
  final bool isDefault;

  factory BankSyncReviewAccount.fromJson(Map<String, dynamic> json) {
    final linkedWallet = json['linkedWallet'] as Map<String, dynamic>?;
    final defaultName = _normalizeString(json['name']) ?? 'Bank Account';

    return BankSyncReviewAccount(
      bankAccountId: _normalizeString(json['id']) ?? '',
      providerAccountId: _normalizeString(json['provider_account_id']) ??
          _normalizeString(json['plaid_account_id']),
      name: defaultName,
      currency: _normalizeString(json['currency'])?.toUpperCase() ?? 'USD',
      mask: _normalizeString(json['mask']),
      type: _normalizeString(json['type']),
      subtype: _normalizeString(json['subtype']),
      walletId: _normalizeString(linkedWallet?['id']),
      walletName: _normalizeString(linkedWallet?['name']) ?? defaultName,
      walletIcon: _normalizeString(linkedWallet?['icon']) ??
          _defaultWalletIcon(
            type: _normalizeString(json['type']),
            subtype: _normalizeString(json['subtype']),
          ),
      walletColor:
          _normalizeString(linkedWallet?['color']) ?? _defaultWalletColor(json),
      goalAmountCents: (linkedWallet?['goal_amount_cents'] as num?)?.round(),
      openingBalanceCents:
          (linkedWallet?['opening_balance_cents'] as num?)?.round() ?? 0,
      isDefault: linkedWallet?['is_default'] == true,
    );
  }

  String get displayName {
    final trimmedMask = _normalizeString(mask);
    if (trimmedMask == null) {
      return name;
    }
    return '$name ••••$trimmedMask';
  }

  bool get hasLinkedWallet => walletId != null && walletId!.isNotEmpty;

  BankSyncReviewAccount copyWith({
    String? currency,
    String? walletId,
    String? walletName,
    String? walletIcon,
    String? walletColor,
    int? goalAmountCents,
    int? openingBalanceCents,
    bool? isDefault,
  }) {
    return BankSyncReviewAccount(
      bankAccountId: bankAccountId,
      providerAccountId: providerAccountId,
      name: name,
      currency: currency ?? this.currency,
      mask: mask,
      type: type,
      subtype: subtype,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      walletIcon: walletIcon ?? this.walletIcon,
      walletColor: walletColor ?? this.walletColor,
      goalAmountCents: goalAmountCents ?? this.goalAmountCents,
      openingBalanceCents: openingBalanceCents ?? this.openingBalanceCents,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

String? _normalizeString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

String _defaultWalletIcon({
  required String? type,
  required String? subtype,
}) {
  final normalizedSubtype = subtype?.toLowerCase();
  final normalizedType = type?.toLowerCase();

  if (normalizedSubtype == 'credit card' || normalizedType == 'credit') {
    return 'card';
  }
  if (normalizedSubtype == 'savings') {
    return 'savings';
  }
  if (normalizedSubtype == 'checking' || normalizedType == 'depository') {
    return 'checking';
  }
  if (normalizedType == 'loan') {
    return 'loan';
  }
  if (normalizedType == 'investment') {
    return 'investment';
  }
  return 'bank';
}

String _defaultWalletColor(Map<String, dynamic> json) {
  const palette = <String>[
    '#6B7280',
    '#3B82F6',
    '#10B981',
    '#8B5CF6',
    '#F59E0B',
    '#EF4444',
  ];

  final seed = [
    _normalizeString(json['id']),
    _normalizeString(json['provider_account_id']),
    _normalizeString(json['name']),
  ].whereType<String>().join('|');

  if (seed.isEmpty) {
    return palette.first;
  }

  final index =
      seed.codeUnits.fold<int>(0, (sum, char) => sum + char) % palette.length;
  return palette[index];
}
