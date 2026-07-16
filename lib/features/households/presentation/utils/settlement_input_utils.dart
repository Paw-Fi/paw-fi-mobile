import 'dart:math' as math;

int? parseSettlementAmountCents(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  // Currency belongs to the surrounding confirmed intent. Accepting a pasted
  // decoration here could silently turn "USD 10" into a CAD settlement.
  if (!RegExp(r'^[0-9.,\s]+$').hasMatch(value) ||
      !RegExp(r'\d').hasMatch(value)) {
    return null;
  }

  if (RegExp(r'\s').hasMatch(value)) {
    final normalizedSpaces = value
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll(RegExp(r' +'), ' ');
    if (!RegExp(r'^\d{1,3}(?: \d{3})+(?:[.,]\d{1,2})?$')
        .hasMatch(normalizedSpaces)) {
      return null;
    }
  }

  final compact = value.replaceAll(RegExp(r'\s+'), '');
  final dotCount = '.'.allMatches(compact).length;
  final commaCount = ','.allMatches(compact).length;
  String integerDigits;
  var fractionalDigits = '';

  if (dotCount > 0 && commaCount > 0) {
    final decimalSeparator =
        compact.lastIndexOf('.') > compact.lastIndexOf(',') ? '.' : ',';
    final groupingSeparator = decimalSeparator == '.' ? ',' : '.';
    if (decimalSeparator.allMatches(compact).length != 1) return null;

    final decimalParts = compact.split(decimalSeparator);
    if (decimalParts.length != 2 ||
        decimalParts[1].isEmpty ||
        decimalParts[1].length > 2 ||
        !RegExp(r'^\d+$').hasMatch(decimalParts[1])) {
      return null;
    }
    final integerGroups = decimalParts[0].split(groupingSeparator);
    if (integerGroups.first.isEmpty ||
        integerGroups.first.length > 3 ||
        integerGroups.any((group) => !RegExp(r'^\d+$').hasMatch(group)) ||
        integerGroups.skip(1).any((group) => group.length != 3)) {
      return null;
    }
    integerDigits = integerGroups.join();
    fractionalDigits = decimalParts[1];
  } else if (dotCount > 1 || commaCount > 1) {
    final separator = dotCount > 1 ? '.' : ',';
    final groups = compact.split(separator);
    if (groups.first.isEmpty ||
        groups.first.length > 3 ||
        groups.any((group) => !RegExp(r'^\d+$').hasMatch(group)) ||
        groups.skip(1).any((group) => group.length != 3)) {
      return null;
    }
    integerDigits = groups.join();
  } else if (dotCount == 1 || commaCount == 1) {
    final separator = dotCount == 1 ? '.' : ',';
    final separatorIndex = compact.indexOf(separator);
    final whole = compact.substring(0, separatorIndex);
    final fractional = compact.substring(separatorIndex + 1);
    if (whole.isEmpty ||
        fractional.isEmpty ||
        fractional.length > 2 ||
        !RegExp(r'^\d+$').hasMatch(whole) ||
        !RegExp(r'^\d+$').hasMatch(fractional)) {
      // One separator followed by three digits is ambiguous between grouping
      // and decimal overprecision, so it is deliberately not guessed.
      return null;
    }
    integerDigits = whole;
    fractionalDigits = fractional;
  } else {
    if (!RegExp(r'^\d+$').hasMatch(compact)) return null;
    integerDigits = compact;
  }

  final wholeCents = int.tryParse(integerDigits);
  final fractionalCents = fractionalDigits.isEmpty
      ? 0
      : int.tryParse(fractionalDigits.padRight(2, '0'));
  if (wholeCents == null || fractionalCents == null) return null;
  final cents = wholeCents * 100 + fractionalCents;
  return cents > 0 ? cents : null;
}

int? clampSettlementAmountCents({
  required int? requestedCents,
  required int maxCents,
}) {
  if (requestedCents == null || requestedCents <= 0 || maxCents <= 0) {
    return null;
  }
  if (requestedCents > maxCents) return null;
  return requestedCents;
}

bool isCurrentSettlementBalanceRequest({
  required int requestGeneration,
  required int currentGeneration,
  required String requestedMemberId,
  required String? currentMemberId,
  required String requestedCurrencyCode,
  required String currentCurrencyCode,
}) {
  return requestGeneration == currentGeneration &&
      requestedMemberId == currentMemberId &&
      requestedCurrencyCode == currentCurrencyCode;
}

String generateSettlementClientMutationId({
  DateTime? now,
  math.Random? random,
}) {
  final secureRandom = random ?? math.Random.secure();
  final entropy = List<String>.generate(
    4,
    (_) => secureRandom.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    growable: false,
  ).join();
  return 'mobile:settlement:${(now ?? DateTime.now()).toUtc().microsecondsSinceEpoch}:$entropy';
}
