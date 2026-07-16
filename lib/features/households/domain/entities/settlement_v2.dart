enum SettlementBreakdownDirectionV2 {
  youOwe,
  theyOweYou;

  static SettlementBreakdownDirectionV2 fromJson(String value) {
    switch (value) {
      case 'you_owe':
        return SettlementBreakdownDirectionV2.youOwe;
      case 'they_owe_you':
        return SettlementBreakdownDirectionV2.theyOweYou;
      default:
        throw ArgumentError('Unknown SettlementBreakdownDirectionV2: $value');
    }
  }
}

enum SettlementBreakdownKindV2 {
  transaction,
  adjustment,
  legacyCarryover,
}

int _jsonInteger(
  Object? value,
  String fieldName, {
  int? defaultValue,
}) {
  if (value == null && defaultValue != null) return defaultValue;
  if (value is num && value.isFinite) {
    final integer = value.toInt();
    if (value == integer) return integer;
  }
  throw FormatException('$fieldName must be a finite integer');
}

bool _isV1SnapshotToken(String? value) =>
    value != null && RegExp(r'^v1:[0-9a-f]{64}$').hasMatch(value);

class SettlementPairwiseBalance {
  final String otherUserId;
  final String currency;
  final int splitToCents;
  final int splitFromCents;
  final int paidToCents;
  final int paidFromCents;
  final int netCents;

  const SettlementPairwiseBalance({
    required this.otherUserId,
    required this.currency,
    required this.splitToCents,
    required this.splitFromCents,
    required this.paidToCents,
    required this.paidFromCents,
    required this.netCents,
  });

  int get youOweCents => netCents > 0 ? netCents : 0;

  int get youAreOwedCents => netCents < 0 ? -netCents : 0;

  factory SettlementPairwiseBalance.fromJson(Map<String, dynamic> json) {
    final splitToCents =
        _jsonInteger(json['split_to_cents'], 'split_to_cents', defaultValue: 0);
    final splitFromCents = _jsonInteger(
      json['split_from_cents'],
      'split_from_cents',
      defaultValue: 0,
    );
    final paidToCents =
        _jsonInteger(json['paid_to_cents'], 'paid_to_cents', defaultValue: 0);
    final paidFromCents = _jsonInteger(
      json['paid_from_cents'],
      'paid_from_cents',
      defaultValue: 0,
    );
    if (splitToCents < 0 ||
        splitFromCents < 0 ||
        paidToCents < 0 ||
        paidFromCents < 0) {
      throw const FormatException(
        'Settlement pairwise component cents cannot be negative',
      );
    }

    final netCents =
        _jsonInteger(json['net_cents'], 'net_cents', defaultValue: 0);
    final expectedNetCents =
        (splitToCents - splitFromCents) - (paidToCents - paidFromCents);
    if (netCents != expectedNetCents) {
      throw const FormatException(
        'Settlement pairwise components do not reconcile to net_cents',
      );
    }

    return SettlementPairwiseBalance(
      otherUserId: json['other_user_id'] as String,
      currency: (json['currency'] as String).toUpperCase(),
      splitToCents: splitToCents,
      splitFromCents: splitFromCents,
      paidToCents: paidToCents,
      paidFromCents: paidFromCents,
      netCents: netCents,
    );
  }
}

class SettlementBreakdownRowV2 {
  final SettlementBreakdownDirectionV2 direction;
  final String? expenseId;
  final String? splitGroupId;
  final String? splitLineId;
  final DateTime expenseDate;
  final String? expenseDescription;
  final String? expenseCategory;
  final String? expenseRawText;
  final String? expenseType;
  final int totalAmountCents;
  final int remainingAmountCents;

  const SettlementBreakdownRowV2({
    required this.direction,
    this.expenseId,
    this.splitGroupId,
    this.splitLineId,
    required this.expenseDate,
    this.expenseDescription,
    this.expenseCategory,
    this.expenseRawText,
    this.expenseType,
    required this.totalAmountCents,
    required this.remainingAmountCents,
  });

  SettlementBreakdownKindV2 get kind {
    switch ((expenseType ?? '').trim().toLowerCase()) {
      case 'adjustment':
        return SettlementBreakdownKindV2.adjustment;
      case 'legacy_carryover':
        return SettlementBreakdownKindV2.legacyCarryover;
      default:
        return SettlementBreakdownKindV2.transaction;
    }
  }

  bool get isAdjustment => kind == SettlementBreakdownKindV2.adjustment;

  bool get isLegacyCarryover =>
      kind == SettlementBreakdownKindV2.legacyCarryover;

  bool get isSynthetic => kind != SettlementBreakdownKindV2.transaction;

  factory SettlementBreakdownRowV2.fromJson(Map<String, dynamic> json) {
    final totalAmountCents = _jsonInteger(
      json['total_amount_cents'],
      'total_amount_cents',
      defaultValue: 0,
    );
    final remainingAmountCents = _jsonInteger(
      json['remaining_amount_cents'],
      'remaining_amount_cents',
      defaultValue: 0,
    );
    if (totalAmountCents < 0 || remainingAmountCents < 0) {
      throw const FormatException(
        'Settlement breakdown cents cannot be negative',
      );
    }

    final expenseId = json['expense_id'] as String?;
    final splitGroupId = json['split_group_id'] as String?;
    final splitLineId = json['split_line_id'] as String?;
    final expenseType = json['expense_type'] as String?;
    if ((expenseType ?? '').trim().toLowerCase() == 'legacy_carryover' &&
        (expenseId != null || splitGroupId != null || splitLineId != null)) {
      throw const FormatException(
        'Legacy settlement carryover rows cannot reference a transaction',
      );
    }

    return SettlementBreakdownRowV2(
      direction: SettlementBreakdownDirectionV2.fromJson(
        json['direction'] as String,
      ),
      expenseId: expenseId,
      splitGroupId: splitGroupId,
      splitLineId: splitLineId,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      expenseDescription: json['expense_description'] as String?,
      expenseCategory: json['expense_category'] as String?,
      expenseRawText: json['expense_raw_text'] as String?,
      expenseType: expenseType,
      totalAmountCents: totalAmountCents,
      remainingAmountCents: remainingAmountCents,
    );
  }
}

class SettlementCalculationV3 {
  final int snapshotVersion;
  final String? snapshotToken;
  final String? householdId;
  final String? memberUserId;
  final String? currency;
  final int splitToCents;
  final int splitFromCents;
  final int paidToCents;
  final int paidFromCents;
  final int netCents;
  final List<SettlementBreakdownRowV2> rows;

  SettlementCalculationV3({
    this.snapshotVersion = 0,
    this.snapshotToken,
    this.householdId,
    this.memberUserId,
    this.currency,
    this.splitToCents = 0,
    this.splitFromCents = 0,
    this.paidToCents = 0,
    this.paidFromCents = 0,
    required this.netCents,
    required List<SettlementBreakdownRowV2> rows,
  }) : rows = List<SettlementBreakdownRowV2>.unmodifiable(rows);

  bool get hasAuthoritativeSnapshotToken =>
      snapshotVersion == 1 &&
      snapshotToken != null &&
      snapshotToken!.startsWith('v1:') &&
      householdId != null &&
      memberUserId != null &&
      currency != null;

  factory SettlementCalculationV3.fromJson(Map<String, dynamic> json) {
    final rawNetCents = json['net_cents'];
    if (rawNetCents is! num) {
      throw const FormatException(
        'Settlement calculation response is missing net_cents',
      );
    }

    final rawRows = json['rows'];
    if (rawRows != null && rawRows is! List) {
      throw const FormatException(
        'Settlement calculation response rows must be a list',
      );
    }

    final snapshotVersion = json['snapshot_version'] == null
        ? 0
        : _jsonInteger(json['snapshot_version'], 'snapshot_version');
    final snapshotToken = json['snapshot_token'] as String?;
    final householdId = json['household_id'] as String?;
    final memberUserId = json['member_user_id'] as String?;
    final currency = (json['currency'] as String?)?.trim().toUpperCase();
    final hasSnapshotMetadata = snapshotVersion != 0 ||
        snapshotToken != null ||
        householdId != null ||
        memberUserId != null ||
        currency != null;
    if (hasSnapshotMetadata &&
        (snapshotVersion != 1 ||
            !_isV1SnapshotToken(snapshotToken) ||
            householdId == null ||
            householdId.trim().isEmpty ||
            memberUserId == null ||
            memberUserId.trim().isEmpty ||
            currency == null ||
            !RegExp(r'^[A-Z]{3}$').hasMatch(currency))) {
      throw const FormatException(
        'Settlement calculation snapshot metadata is invalid',
      );
    }

    final splitToCents = _jsonInteger(
      json['split_to_cents'],
      'split_to_cents',
      defaultValue: 0,
    );
    final splitFromCents = _jsonInteger(
      json['split_from_cents'],
      'split_from_cents',
      defaultValue: 0,
    );
    final paidToCents = _jsonInteger(
      json['paid_to_cents'],
      'paid_to_cents',
      defaultValue: 0,
    );
    final paidFromCents = _jsonInteger(
      json['paid_from_cents'],
      'paid_from_cents',
      defaultValue: 0,
    );
    final netCents = _jsonInteger(rawNetCents, 'net_cents');
    if (splitToCents < 0 ||
        splitFromCents < 0 ||
        paidToCents < 0 ||
        paidFromCents < 0) {
      throw const FormatException(
        'Settlement calculation component cents cannot be negative',
      );
    }
    final expectedNetCents =
        (splitToCents - splitFromCents) - (paidToCents - paidFromCents);
    if (netCents != expectedNetCents) {
      throw const FormatException(
        'Settlement calculation components do not reconcile to net_cents',
      );
    }

    return SettlementCalculationV3(
      snapshotVersion: snapshotVersion,
      snapshotToken: snapshotToken,
      householdId: householdId,
      memberUserId: memberUserId,
      currency: currency,
      splitToCents: splitToCents,
      splitFromCents: splitFromCents,
      paidToCents: paidToCents,
      paidFromCents: paidFromCents,
      netCents: netCents,
      rows: (rawRows as List? ?? const <dynamic>[])
          .map(
            (row) => SettlementBreakdownRowV2.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  SettlementCalculationV3 excludingExpenseIds(Set<String> expenseIds) {
    if (expenseIds.isEmpty) return this;

    var removedNetCents = 0;
    final visibleRows = <SettlementBreakdownRowV2>[];
    for (final row in rows) {
      if (row.expenseId != null && expenseIds.contains(row.expenseId)) {
        // totalAmountCents is the current gross split obligation while
        // remainingAmountCents may already have settlement allocations
        // removed. Deleting the transaction removes the gross obligation;
        // the immutable payment remains in the ledger. Using the remaining
        // amount here would therefore report zero instead of a reverse
        // balance after deleting a partially paid transaction.
        removedNetCents +=
            row.direction == SettlementBreakdownDirectionV2.youOwe
                ? row.totalAmountCents
                : -row.totalAmountCents;
      } else {
        visibleRows.add(row);
      }
    }
    if (visibleRows.length == rows.length) return this;

    return SettlementCalculationV3(
      snapshotVersion: 0,
      snapshotToken: null,
      householdId: householdId,
      memberUserId: memberUserId,
      currency: currency,
      splitToCents: splitToCents,
      splitFromCents: splitFromCents,
      paidToCents: paidToCents,
      paidFromCents: paidFromCents,
      // Remove the signed gross contribution of locally deleted transaction
      // rows. Synthetic backend corrections deliberately have no expense ID,
      // so they remain intact and explainable.
      netCents: netCents - removedNetCents,
      rows: visibleRows,
    );
  }
}

enum SettlementWriteStatusV2 {
  applied,
  snapshotConflict,
  nothingToSettle;

  static SettlementWriteStatusV2 fromJson(Object? value) {
    switch (value) {
      case 'applied':
        return SettlementWriteStatusV2.applied;
      case 'snapshot_conflict':
        return SettlementWriteStatusV2.snapshotConflict;
      case 'nothing_to_settle':
        return SettlementWriteStatusV2.nothingToSettle;
      default:
        throw FormatException('Unknown settlement write status: $value');
    }
  }
}

class SettlementWriteResultV2 {
  const SettlementWriteResultV2({
    required this.status,
    required this.replayed,
    required this.clientMutationId,
    required this.settlementEventId,
    required this.requestedAmountCents,
    required this.appliedAmountCents,
    required this.pairBalanceBeforeCents,
    required this.pairBalanceAfterCents,
    required this.currentNetCents,
    required this.clearedPairBalance,
    required this.resultSnapshotToken,
    this.reason,
  });

  final SettlementWriteStatusV2 status;
  final bool replayed;
  final String clientMutationId;
  final String? settlementEventId;
  final int requestedAmountCents;
  final int appliedAmountCents;
  final int pairBalanceBeforeCents;
  final int pairBalanceAfterCents;
  final int currentNetCents;
  final bool clearedPairBalance;
  final String? resultSnapshotToken;
  final String? reason;

  factory SettlementWriteResultV2.fromJson(Map<String, dynamic> json) {
    final clientMutationId = json['client_mutation_id'] as String?;
    final replayed = json['replayed'];
    final clearedPairBalance = json['cleared_pair_balance'];
    if (clientMutationId == null || clientMutationId.trim().isEmpty) {
      throw const FormatException(
        'Settlement result is missing client_mutation_id',
      );
    }
    if (replayed is! bool || clearedPairBalance is! bool) {
      throw const FormatException('Settlement result booleans are invalid');
    }
    final status = SettlementWriteStatusV2.fromJson(json['status']);
    final requestedAmountCents = _jsonInteger(
      json['requested_amount_cents'],
      'requested_amount_cents',
    );
    final appliedAmountCents = _jsonInteger(
      json['applied_amount_cents'],
      'applied_amount_cents',
    );
    final pairBalanceBeforeCents = _jsonInteger(
      json['pair_balance_before_cents'],
      'pair_balance_before_cents',
    );
    final pairBalanceAfterCents = _jsonInteger(
      json['pair_balance_after_cents'],
      'pair_balance_after_cents',
    );
    final currentNetCents = _jsonInteger(
      json['current_net_cents'],
      'current_net_cents',
    );
    final settlementEventId = json['settlement_event_id'] as String?;
    final resultSnapshotToken = json['result_snapshot_token'] as String?;

    if (clientMutationId != clientMutationId.trim() ||
        clientMutationId.length > 200 ||
        requestedAmountCents <= 0 ||
        appliedAmountCents < 0 ||
        appliedAmountCents > requestedAmountCents ||
        currentNetCents != pairBalanceAfterCents ||
        clearedPairBalance != (pairBalanceAfterCents == 0) ||
        !_isV1SnapshotToken(resultSnapshotToken)) {
      throw const FormatException('Settlement result invariants are invalid');
    }

    if (status == SettlementWriteStatusV2.applied) {
      if (settlementEventId == null ||
          settlementEventId.trim().isEmpty ||
          appliedAmountCents != requestedAmountCents ||
          pairBalanceBeforeCents == 0 ||
          pairBalanceBeforeCents.abs() - appliedAmountCents !=
              pairBalanceAfterCents.abs() ||
          (pairBalanceAfterCents != 0 &&
              pairBalanceAfterCents.sign != pairBalanceBeforeCents.sign)) {
        throw const FormatException(
          'Applied settlement result invariants are invalid',
        );
      }
    } else if (settlementEventId != null ||
        appliedAmountCents != 0 ||
        pairBalanceAfterCents != pairBalanceBeforeCents) {
      throw const FormatException(
        'Non-applied settlement result invariants are invalid',
      );
    }

    return SettlementWriteResultV2(
      status: status,
      replayed: replayed,
      clientMutationId: clientMutationId,
      settlementEventId: settlementEventId,
      requestedAmountCents: requestedAmountCents,
      appliedAmountCents: appliedAmountCents,
      pairBalanceBeforeCents: pairBalanceBeforeCents,
      pairBalanceAfterCents: pairBalanceAfterCents,
      currentNetCents: currentNetCents,
      clearedPairBalance: clearedPairBalance,
      resultSnapshotToken: resultSnapshotToken,
      reason: json['reason'] as String?,
    );
  }
}
