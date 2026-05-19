import 'package:moneko/features/home/presentation/widgets/custom_split_config_codec.dart'
    as split_config;
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart'
    as split_sheet;
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';

ExpenseSplitGroup? buildOptimisticHouseholdSplitGroup({
  required String householdId,
  required String expenseId,
  required String payerUserId,
  required double totalAmount,
  required String currency,
  required List<HouseholdMember> members,
  required bool autoSplitEnabled,
  required Map<String, dynamic>? autoSplitConfig,
  Object? rawCustomSplits,
  String? description,
  String? splitGroupId,
  DateTime? createdAt,
}) {
  final totalCents = (totalAmount.abs() * 100).round();
  if (householdId.trim().isEmpty ||
      expenseId.trim().isEmpty ||
      payerUserId.trim().isEmpty ||
      totalCents <= 0) {
    return null;
  }

  final explicit = _buildLinesFromCustomSplits(
    rawCustomSplits,
    totalCents: totalCents,
    fallbackMembers: members,
  );
  final resolved = explicit ??
      _buildLinesFromAutoSplitConfig(
        members: members,
        totalAmount: totalAmount,
        totalCents: totalCents,
        autoSplitEnabled: autoSplitEnabled,
        autoSplitConfig: autoSplitConfig,
      );
  if (resolved == null || resolved.lineInputs.isEmpty) return null;

  final now = createdAt ?? DateTime.now();
  final normalizedGroupId = (splitGroupId?.trim().isNotEmpty == true)
      ? splitGroupId!.trim()
      : 'optimistic_split_$expenseId';

  final lines = <ExpenseSplitLine>[];
  for (var index = 0; index < resolved.lineInputs.length; index++) {
    final input = resolved.lineInputs[index];
    if (input.amountCents <= 0) continue;
    lines.add(
      ExpenseSplitLine(
        id: '${normalizedGroupId}_line_$index',
        splitGroupId: normalizedGroupId,
        userId: input.userId,
        amountCents: input.amountCents,
        percentage: input.percentage,
        shares: input.shares,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
  if (lines.isEmpty) return null;

  return ExpenseSplitGroup(
    id: normalizedGroupId,
    householdId: householdId,
    expenseId: expenseId,
    payerUserId: payerUserId,
    splitType: resolved.splitType,
    currency: currency,
    totalAmountCents: totalCents,
    description: description,
    createdAt: now,
    updatedAt: now,
    splitLines: lines,
  );
}

_ResolvedSplitLines? _buildLinesFromCustomSplits(
  Object? rawCustomSplits, {
  required int totalCents,
  required List<HouseholdMember> fallbackMembers,
}) {
  if (rawCustomSplits is! Map) return null;
  final customSplits = Map<String, dynamic>.from(rawCustomSplits);
  final splitType = _parseSplitType(customSplits['splitType']);
  if (splitType == null) return null;
  if (splitType == SplitType.equal) return null;

  final rawMemberSplits = customSplits['memberSplits'];
  final rawMaps = rawMemberSplits is List
      ? rawMemberSplits
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where(
            (entry) => entry['userId']?.toString().trim().isNotEmpty == true,
          )
          .toList(growable: false)
      : const <Map<String, dynamic>>[];
  if (_isSemanticallyEqualCustomSplit(splitType, rawMaps)) return null;

  final userIds = rawMaps.isNotEmpty
      ? rawMaps.map((entry) => entry['userId'].toString().trim()).toList()
      : fallbackMembers.map((member) => member.userId).toList();
  if (userIds.isEmpty) return null;

  int amountCentsFor(Map<String, dynamic> entry) {
    switch (splitType) {
      case SplitType.amount:
        return ((_parseAmountValue(entry['amount']) ?? 0).abs() * 100).round();
      case SplitType.percentage:
        final percentage = _parseAmountValue(entry['percentage']) ?? 0;
        return ((totalCents * percentage) / 100).round();
      case SplitType.shares:
        final totalShares = rawMaps.fold<int>(
          0,
          (sum, item) => sum + (_parsePositiveInt(item['shares']) ?? 0),
        );
        if (totalShares <= 0) return 0;
        final shares = _parsePositiveInt(entry['shares']) ?? 0;
        return ((totalCents * shares) / totalShares).round();
      case SplitType.equal:
        return 0;
    }
  }

  final lineInputs = _lineInputsFromRawMaps(
    rawMaps,
    splitType: splitType,
    totalCents: totalCents,
    amountCentsFor: amountCentsFor,
  );
  if (lineInputs.isEmpty) return null;
  return _ResolvedSplitLines(splitType: splitType, lineInputs: lineInputs);
}

bool _isSemanticallyEqualCustomSplit(
  SplitType splitType,
  List<Map<String, dynamic>> rawMaps,
) {
  if (rawMaps.length <= 1) return true;

  final values = switch (splitType) {
    SplitType.amount =>
      rawMaps.map((entry) => _parseAmountValue(entry['amount'])).toList(),
    SplitType.percentage =>
      rawMaps.map((entry) => _parseAmountValue(entry['percentage'])).toList(),
    SplitType.shares => rawMaps
        .map((entry) => _parsePositiveInt(entry['shares'])?.toDouble())
        .toList(),
    SplitType.equal => const <double?>[],
  };
  if (splitType == SplitType.equal) return true;
  if (values.any((value) => value == null)) return false;

  final baseline = values.first!;
  return values.every(
    (value) => ((value ?? 0) - baseline).abs() <= 0.000001,
  );
}

_ResolvedSplitLines? _buildLinesFromAutoSplitConfig({
  required List<HouseholdMember> members,
  required double totalAmount,
  required int totalCents,
  required bool autoSplitEnabled,
  required Map<String, dynamic>? autoSplitConfig,
}) {
  if (!autoSplitEnabled || members.isEmpty) return null;
  final storedSplitType = split_config.resolveStoredSplitType(
    autoSplitConfig,
    fallback: split_sheet.SplitType.equal,
  );
  final templateSplits = split_config.deserializeStoredSplitConfig(
    members: members,
    totalAmount: totalAmount,
    config: autoSplitConfig,
  );
  final splits = split_config.resolveStoredSplitsForTransaction(
    splitType: storedSplitType,
    splits: templateSplits,
    config: autoSplitConfig,
    totalAmount: totalAmount,
  );
  final lineInputs = _lineInputsFromMemberSplits(
    splits,
    splitType: storedSplitType,
    totalCents: totalCents,
  );
  if (lineInputs.isEmpty) return null;
  return _ResolvedSplitLines(
    splitType: _domainSplitTypeFromStored(storedSplitType),
    lineInputs: lineInputs,
  );
}

List<_SplitLineInput> _lineInputsFromRawMaps(
  List<Map<String, dynamic>> rawMaps, {
  required SplitType splitType,
  required int totalCents,
  required int Function(Map<String, dynamic> entry) amountCentsFor,
}) {
  if (rawMaps.isEmpty) return const <_SplitLineInput>[];
  final cents = rawMaps.map(amountCentsFor).toList(growable: true);
  _applyRemainderToLastPositive(cents, totalCents);
  return [
    for (var index = 0; index < rawMaps.length; index++)
      _SplitLineInput(
        userId: rawMaps[index]['userId'].toString().trim(),
        amountCents: cents[index],
        percentage: _parseAmountValue(rawMaps[index]['percentage']),
        shares: _parsePositiveInt(rawMaps[index]['shares']),
      ),
  ];
}

List<_SplitLineInput> _lineInputsFromMemberSplits(
  List<split_sheet.MemberSplit> splits, {
  required split_sheet.SplitType splitType,
  required int totalCents,
}) {
  final included = splits.where((split) {
    switch (splitType) {
      case split_sheet.SplitType.equal:
        return true;
      case split_sheet.SplitType.amount:
        return split.includedInAmount;
      case split_sheet.SplitType.percentage:
        return split.includedInPercentage;
      case split_sheet.SplitType.shares:
        return (split.shares ?? 0) > 0;
    }
  }).toList(growable: false);
  if (included.isEmpty) return const <_SplitLineInput>[];

  if (splitType == split_sheet.SplitType.equal) {
    return _equalLineInputs(
      userIds: included.map((split) => split.member.userId).toList(),
      totalCents: totalCents,
    );
  }

  final cents = included.map((split) {
    switch (splitType) {
      case split_sheet.SplitType.amount:
        return (((split.amount ?? 0).abs()) * 100).round();
      case split_sheet.SplitType.percentage:
        return ((totalCents * (split.percentage ?? 0)) / 100).round();
      case split_sheet.SplitType.shares:
        final totalShares = included.fold<int>(
          0,
          (sum, item) => sum + (item.shares ?? 0),
        );
        if (totalShares <= 0) return 0;
        return ((totalCents * (split.shares ?? 0)) / totalShares).round();
      case split_sheet.SplitType.equal:
        return 0;
    }
  }).toList(growable: true);
  _applyRemainderToLastPositive(cents, totalCents);

  return [
    for (var index = 0; index < included.length; index++)
      _SplitLineInput(
        userId: included[index].member.userId,
        amountCents: cents[index],
        percentage: included[index].percentage,
        shares: included[index].shares,
      ),
  ];
}

List<_SplitLineInput> _equalLineInputs({
  required List<String> userIds,
  required int totalCents,
}) {
  final normalizedUserIds = userIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (normalizedUserIds.isEmpty) return const <_SplitLineInput>[];
  final perUser = totalCents ~/ normalizedUserIds.length;
  var remainder = totalCents % normalizedUserIds.length;
  return normalizedUserIds.map((userId) {
    final extra = remainder > 0 ? 1 : 0;
    if (remainder > 0) remainder -= 1;
    return _SplitLineInput(
      userId: userId,
      amountCents: perUser + extra,
    );
  }).toList(growable: false);
}

void _applyRemainderToLastPositive(List<int> cents, int totalCents) {
  if (cents.isEmpty) return;
  final current = cents.fold<int>(0, (sum, value) => sum + value);
  final diff = totalCents - current;
  if (diff == 0) return;
  final index = cents.lastIndexWhere((value) => value > 0);
  cents[index >= 0 ? index : cents.length - 1] += diff;
}

SplitType? _parseSplitType(Object? rawSplitType) {
  final value = rawSplitType?.toString().trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  try {
    return SplitType.fromJson(value);
  } catch (_) {
    return null;
  }
}

SplitType _domainSplitTypeFromStored(split_sheet.SplitType splitType) {
  switch (splitType) {
    case split_sheet.SplitType.equal:
      return SplitType.equal;
    case split_sheet.SplitType.amount:
      return SplitType.amount;
    case split_sheet.SplitType.percentage:
      return SplitType.percentage;
    case split_sheet.SplitType.shares:
      return SplitType.shares;
  }
}

double? _parseAmountValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? _parsePositiveInt(Object? value) {
  if (value is num) {
    final parsed = value.toInt();
    return parsed > 0 ? parsed : null;
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }
  return null;
}

class _ResolvedSplitLines {
  final SplitType splitType;
  final List<_SplitLineInput> lineInputs;

  const _ResolvedSplitLines({
    required this.splitType,
    required this.lineInputs,
  });
}

class _SplitLineInput {
  final String userId;
  final int amountCents;
  final double? percentage;
  final int? shares;

  const _SplitLineInput({
    required this.userId,
    required this.amountCents,
    this.percentage,
    this.shares,
  });
}
