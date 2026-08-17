import 'package:moneko/features/households/domain/entities/household.dart';

import 'custom_split_sheet.dart';

SplitType resolveStoredSplitType(
  Map<String, dynamic>? config, {
  SplitType fallback = SplitType.amount,
}) {
  if (isStoredSplitConfigEffectivelyEqual(config)) {
    return SplitType.equal;
  }

  final rawValue = config?['splitType']?.toString().trim().toLowerCase();
  switch (rawValue) {
    case 'equal':
      return SplitType.equal;
    case 'amount':
      return SplitType.amount;
    case 'percentage':
      return SplitType.percentage;
    case 'shares':
      return SplitType.shares;
    default:
      return fallback;
  }
}

bool isStoredSplitConfigEffectivelyEqual(Map<String, dynamic>? config) {
  final rawValue = config?['splitType']?.toString().trim().toLowerCase();
  if (rawValue == null || rawValue.isEmpty || rawValue == 'equal') {
    return true;
  }

  final rawSplits = config?['memberSplits'];
  if (rawSplits is! List || rawSplits.isEmpty) return false;

  final splits = rawSplits.whereType<Map>().toList(growable: false);
  if (splits.isEmpty || splits.length != rawSplits.length) return false;

  bool closeTo(double actual, double expected) =>
      (actual - expected).abs() <= 0.01;

  switch (rawValue) {
    case 'percentage':
      final expected = 100 / splits.length;
      return splits.every((split) {
        final percentage = _asDouble(split['percentage']);
        final included =
            _asBool(split['includedInPercentage']) ?? ((percentage ?? 0) != 0);
        return included && percentage != null && closeTo(percentage, expected);
      });
    case 'shares':
      final firstShares = _asPositiveInt(splits.first['shares']);
      if (firstShares == null) return false;
      return splits
          .every((split) => _asPositiveInt(split['shares']) == firstShares);
    case 'amount':
      final firstAmount = _asDouble(splits.first['amount']);
      if (firstAmount == null) return false;
      return splits.every((split) {
        final amount = _asDouble(split['amount']);
        final included =
            _asBool(split['includedInAmount']) ?? ((amount ?? 0) != 0);
        return included && amount != null && closeTo(amount, firstAmount);
      });
    default:
      return false;
  }
}

Map<String, dynamic> serializeStoredSplitConfig({
  required SplitType splitType,
  required List<MemberSplit> splits,
}) {
  return {
    'splitType': splitType.name,
    'templateTotalAmount': _resolveTemplateTotalAmount(splitType, splits),
    'memberSplits': splits
        .map(
          (split) => {
            'userId': split.member.userId,
            'amount': split.amount,
            'percentage': split.percentage,
            'shares': split.shares,
            'includedInAmount': split.includedInAmount,
            'includedInPercentage': split.includedInPercentage,
          },
        )
        .toList(growable: false),
  };
}

List<MemberSplit> resolveStoredSplitsForTransaction({
  required SplitType splitType,
  required List<MemberSplit> splits,
  required Map<String, dynamic>? config,
  required double totalAmount,
}) {
  if (splitType != SplitType.amount) return splits;

  final previousTotal = _asDouble(config?['templateTotalAmount']) ??
      _resolveTemplateTotalAmount(splitType, splits);

  return rescaleAmountSplits(
    splits: splits,
    previousTotal: previousTotal,
    newTotal: totalAmount,
  );
}

List<MemberSplit> deserializeStoredSplitConfig({
  required List<HouseholdMember> members,
  required double totalAmount,
  Map<String, dynamic>? config,
}) {
  if (members.isEmpty) return const <MemberSplit>[];

  final defaultsByUserId = {
    for (final split in buildDefaultMemberSplits(
      members: members,
      totalAmount: totalAmount,
    ))
      split.member.userId: split,
  };

  final rawSplits = config?['memberSplits'];
  final storedByUserId = <String, Map<String, dynamic>>{};
  if (rawSplits is List) {
    for (final item in rawSplits) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final userId = map['userId']?.toString().trim();
      if (userId == null || userId.isEmpty) continue;
      storedByUserId[userId] = map;
    }
  }

  return members.map((member) {
    final fallback = defaultsByUserId[member.userId]!;
    final stored = storedByUserId[member.userId];
    if (stored == null) {
      if (storedByUserId.isNotEmpty) {
        return MemberSplit(
          member: member,
          amount: 0,
          percentage: 0,
          shares: null,
          includedInAmount: false,
          includedInPercentage: false,
        );
      }
      return fallback;
    }

    final storedAmount = _asDouble(stored['amount']);
    final storedPercentage = _asDouble(stored['percentage']);
    final storedShares = _asPositiveInt(stored['shares']);

    return MemberSplit(
      member: member,
      amount: storedAmount ?? fallback.amount,
      percentage: storedPercentage ?? fallback.percentage,
      shares: storedShares ?? fallback.shares,
      includedInAmount:
          _asBool(stored['includedInAmount']) ?? (storedAmount != 0),
      includedInPercentage:
          _asBool(stored['includedInPercentage']) ?? (storedPercentage != 0),
    );
  }).toList(growable: false);
}

Map<String, dynamic>? buildCustomSplitsPayload({
  required SplitType splitType,
  required List<MemberSplit> splits,
}) {
  if (splits.isEmpty) return null;

  // The server uses this established sentinel to distinguish a deliberate
  // equal allocation from an omitted automatic/default split. Without it,
  // a manually entered 50/50 amount split is indistinguishable from a stale
  // default-shaped payload when Auto split is disabled.
  if (splitType == SplitType.equal ||
      _hasEqualPositiveValues(splitType, splits)) {
    return {
      'splitType': SplitType.equal.name,
      'memberSplits': splits
          .map((split) => {'userId': split.member.userId})
          .toList(growable: false),
    };
  }

  return {
    'splitType': splitType.name,
    'memberSplits': splits.map((split) {
      final memberData = <String, dynamic>{
        'userId': split.member.userId,
      };

      switch (splitType) {
        case SplitType.amount:
          memberData['amount'] = split.amount;
          break;
        case SplitType.percentage:
          memberData['percentage'] = split.percentage;
          break;
        case SplitType.shares:
          memberData['shares'] = split.shares;
          break;
        case SplitType.equal:
          break;
      }

      return memberData;
    }).toList(growable: false),
  };
}

/// Keeps an allocation supplied by AI explicit, while encoding equal values
/// using the backend's established `equal` sentinel. This is necessary when
/// Auto split is off: an omitted payload means unsplit, but a requested 50/50
/// remains a real split.
Map<String, dynamic>? normalizeExplicitCustomSplitsPayload(
  Object? rawCustomSplits,
) {
  if (rawCustomSplits is! Map) return null;
  final customSplits = Map<String, dynamic>.from(rawCustomSplits);
  final splitType = customSplits['splitType']?.toString().trim().toLowerCase();
  if (splitType == null || splitType.isEmpty) return null;

  final memberSplits = customSplits['memberSplits'];
  if (memberSplits is! List || memberSplits.isEmpty) return null;
  final memberIds = memberSplits
      .whereType<Map>()
      .map((entry) => entry['userId']?.toString().trim())
      .whereType<String>()
      .where((userId) => userId.isNotEmpty)
      .toList(growable: false);
  if (memberIds.isEmpty) return null;

  if (splitType == SplitType.equal.name) {
    return {
      'splitType': SplitType.equal.name,
      'memberSplits': memberIds.map((userId) => {'userId': userId}).toList(),
    };
  }

  final splitValueKey = switch (splitType) {
    'amount' => 'amount',
    'percentage' => 'percentage',
    'shares' => 'shares',
    _ => null,
  };
  if (splitValueKey == null) return null;
  final values = memberSplits
      .whereType<Map>()
      .map((entry) => entry[splitValueKey])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  if (values.length != memberIds.length || values.isEmpty) return null;
  final first = values.first;
  if (first > 0 && values.every((value) => (value - first).abs() < 0.000001)) {
    return {
      'splitType': SplitType.equal.name,
      'memberSplits': memberIds.map((userId) => {'userId': userId}).toList(),
    };
  }

  return customSplits;
}

bool _hasEqualPositiveValues(SplitType splitType, List<MemberSplit> splits) {
  final values = switch (splitType) {
    SplitType.amount => splits.map((split) => split.amount).toList(),
    SplitType.percentage => splits.map((split) => split.percentage).toList(),
    SplitType.shares =>
      splits.map((split) => split.shares?.toDouble()).toList(),
    SplitType.equal => const <double?>[],
  };
  if (values.isEmpty || values.any((value) => value == null)) return false;
  final first = values.first!;
  if (first <= 0) return false;
  return values.every((value) => (value! - first).abs() < 0.000001);
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  return null;
}

int? _asPositiveInt(Object? value) {
  if (value is num) {
    final normalized = value.toInt();
    return normalized > 0 ? normalized : null;
  }
  if (value is String) {
    final normalized = int.tryParse(value.trim());
    if (normalized != null && normalized > 0) return normalized;
  }
  return null;
}

double _resolveTemplateTotalAmount(
  SplitType splitType,
  List<MemberSplit> splits,
) {
  switch (splitType) {
    case SplitType.amount:
      return splits.fold<double>(0, (sum, split) => sum + (split.amount ?? 0));
    case SplitType.percentage:
      return 100;
    case SplitType.shares:
      return splits.fold<double>(
        0,
        (sum, split) => sum + ((split.shares ?? 0) > 0 ? split.shares! : 0),
      );
    case SplitType.equal:
      return splits.length.toDouble();
  }
}
