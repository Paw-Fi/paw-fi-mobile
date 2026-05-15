import 'dart:convert';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';

enum SmartInputConfidence { low, medium, high }

enum RecurringCandidateFrequency { weekly, monthly }

class CategoryPrediction {
  const CategoryPrediction({
    required this.category,
    required this.confidence,
  });

  final String category;
  final SmartInputConfidence confidence;
}

class RecurringCandidate {
  const RecurringCandidate({
    required this.frequency,
    required this.confidence,
    required this.matchCount,
  });

  final RecurringCandidateFrequency frequency;
  final SmartInputConfidence confidence;
  final int matchCount;
}

class SmartInputAmountMeasurement {
  const SmartInputAmountMeasurement({
    required this.value,
    required this.decoratorSignature,
  });

  final double value;
  final String decoratorSignature;

  Map<String, dynamic> toJson() => {
        'value': value,
        'decoratorSignature': decoratorSignature,
      };

  static SmartInputAmountMeasurement? fromJson(Object? value) {
    final map = _asStringDynamicMap(value);
    if (map == null) return null;
    final rawValue = map['value'];
    final amount = rawValue is num ? rawValue.toDouble() : null;
    if (amount == null) return null;
    return SmartInputAmountMeasurement(
      value: amount,
      decoratorSignature: map['decoratorSignature']?.toString() ?? '',
    );
  }
}

class SmartInputMeasurement {
  const SmartInputMeasurement({
    required this.orderedSignature,
    required this.unorderedSignature,
    required this.nonAmountTokenCount,
    required this.amounts,
  });

  final String orderedSignature;
  final String unorderedSignature;
  final int nonAmountTokenCount;
  final List<SmartInputAmountMeasurement> amounts;

  bool get hasSingleReliableAmount =>
      amounts.length == 1 && nonAmountTokenCount > 0;

  bool hasSameMeaningfulShape(SmartInputMeasurement other) {
    if (!hasSingleReliableAmount || !other.hasSingleReliableAmount) {
      return false;
    }
    if (amounts.single.decoratorSignature !=
        other.amounts.single.decoratorSignature) {
      return false;
    }
    return orderedSignature == other.orderedSignature ||
        unorderedSignature == other.unorderedSignature;
  }

  Map<String, dynamic> toJson() => {
        'orderedSignature': orderedSignature,
        'unorderedSignature': unorderedSignature,
        'nonAmountTokenCount': nonAmountTokenCount,
        'amounts': amounts.map((amount) => amount.toJson()).toList(),
      };

  static SmartInputMeasurement? fromJson(Object? value) {
    final map = _asStringDynamicMap(value);
    if (map == null) return null;
    final rawAmounts = map['amounts'];
    if (rawAmounts is! List) return null;
    final amounts = rawAmounts
        .map(SmartInputAmountMeasurement.fromJson)
        .whereType<SmartInputAmountMeasurement>()
        .toList(growable: false);
    return SmartInputMeasurement(
      orderedSignature: map['orderedSignature']?.toString() ?? '',
      unorderedSignature: map['unorderedSignature']?.toString() ?? '',
      nonAmountTokenCount: (map['nonAmountTokenCount'] is num)
          ? (map['nonAmountTokenCount'] as num).toInt()
          : 0,
      amounts: amounts,
    );
  }
}

class SmartInputAnalysisMemory {
  const SmartInputAnalysisMemory({
    required this.measurement,
    required this.item,
  });

  final SmartInputMeasurement measurement;
  final Map<String, dynamic> item;

  static SmartInputAnalysisMemory? fromAnalysisResponse({
    required String inputText,
    required Map<String, dynamic> responseData,
    required String defaultDateYmd,
  }) {
    final measurement = measureSmartInput(inputText);
    if (!measurement.hasSingleReliableAmount) return null;
    if (responseData['success'] != true) return null;

    final data = _asStringDynamicMap(responseData['data']);
    final rawItems = data?['items'];
    if (rawItems is! List || rawItems.length != 1) return null;

    final item = _asStringDynamicMap(rawItems.single);
    if (item == null) return null;

    final itemAmount = _parseFlexibleAmount(item['amount']);
    if (itemAmount == null) return null;
    final measuredAmount = measurement.amounts.single.value;
    if ((itemAmount - measuredAmount).abs() > 0.01) return null;

    final itemDate = item['date']?.toString();
    if (itemDate != defaultDateYmd) return null;

    return SmartInputAnalysisMemory(
      measurement: measurement,
      item: _deepCopyMap(item),
    );
  }

  Map<String, dynamic>? tryBuildResponseFor({
    required String inputText,
    required String defaultDateYmd,
  }) {
    final currentMeasurement = measureSmartInput(inputText);
    if (!measurement.hasSameMeaningfulShape(currentMeasurement)) {
      return null;
    }

    final updatedItem = _deepCopyMap(item);
    updatedItem['amount'] = currentMeasurement.amounts.single.value;
    updatedItem['date'] = defaultDateYmd;

    return {
      'success': true,
      'data': {
        'items': [updatedItem],
      },
      'meta': {
        'source': 'smart_input_memory',
        'skippedAnalysis': true,
      },
    };
  }

  Map<String, dynamic> toJson() => {
        'measurement': measurement.toJson(),
        'item': item,
      };

  static SmartInputAnalysisMemory? fromJson(Object? value) {
    final map = _asStringDynamicMap(value);
    if (map == null) return null;
    final measurement = SmartInputMeasurement.fromJson(map['measurement']);
    final item = _asStringDynamicMap(map['item']);
    if (measurement == null || item == null) return null;
    return SmartInputAnalysisMemory(
      measurement: measurement,
      item: _deepCopyMap(item),
    );
  }
}

SmartInputMeasurement measureSmartInput(String input) {
  final spans = <_AmountSpan>[];
  final matches = _amountPattern.allMatches(input).toList(growable: false);
  for (final match in matches) {
    final rawAmount = match.group(0);
    if (rawAmount == null) continue;
    final value = _parseLocalizedAmount(rawAmount);
    if (value == null) continue;
    spans.add(
      _AmountSpan(
        start: match.start,
        end: match.end,
        amount: SmartInputAmountMeasurement(
          value: value,
          decoratorSignature: _amountDecoratorSignature(input, match),
        ),
      ),
    );
  }

  final textWithoutAmounts = _removeSpans(input, spans);
  final tokens = _wordTokens(textWithoutAmounts);
  final sortedTokens = tokens.toList()..sort();

  return SmartInputMeasurement(
    orderedSignature: tokens.join(' '),
    unorderedSignature: sortedTokens.join(' '),
    nonAmountTokenCount: tokens.length,
    amounts: spans.map((span) => span.amount).toList(growable: false),
  );
}

CategoryPrediction? suggestCategoryForMerchant({
  required String? merchant,
  required Iterable<ExpenseEntry> history,
}) {
  final normalizedMerchant = _normalizeMerchant(merchant);
  if (normalizedMerchant == null) return null;

  final matches = history
      .where(
          (entry) => _normalizeMerchant(entry.merchant) == normalizedMerchant)
      .where((entry) => entry.category?.trim().isNotEmpty == true)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  if (matches.isEmpty) return null;

  final category = matches.first.category!.trim();
  final sameCategoryCount =
      matches.where((entry) => entry.category?.trim() == category).length;
  final confidence = sameCategoryCount >= 2 || matches.length == 1
      ? SmartInputConfidence.high
      : SmartInputConfidence.medium;

  return CategoryPrediction(category: category, confidence: confidence);
}

RecurringCandidate? detectRecurringCandidate({
  required String? merchant,
  required int amountCents,
  required DateTime date,
  required Iterable<ExpenseEntry> history,
}) {
  final normalizedMerchant = _normalizeMerchant(merchant);
  if (normalizedMerchant == null || amountCents <= 0) return null;

  final matches = history
      .where(
          (entry) => _normalizeMerchant(entry.merchant) == normalizedMerchant)
      .where((entry) => entry.amountCents.abs() == amountCents.abs())
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  if (matches.isEmpty) return null;

  final monthlyMatches = _cadenceMatchCount(
    dates: [date, ...matches.map((entry) => entry.date)],
    minDays: 27,
    maxDays: 34,
  );
  if (monthlyMatches >= 1) {
    return RecurringCandidate(
      frequency: RecurringCandidateFrequency.monthly,
      confidence: monthlyMatches >= 2
          ? SmartInputConfidence.high
          : SmartInputConfidence.medium,
      matchCount: monthlyMatches,
    );
  }

  final weeklyMatches = _cadenceMatchCount(
    dates: [date, ...matches.map((entry) => entry.date)],
    minDays: 6,
    maxDays: 8,
  );
  if (weeklyMatches >= 1) {
    return RecurringCandidate(
      frequency: RecurringCandidateFrequency.weekly,
      confidence: weeklyMatches >= 2
          ? SmartInputConfidence.high
          : SmartInputConfidence.medium,
      matchCount: weeklyMatches,
    );
  }

  return null;
}

Map<String, dynamic>? _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return null;
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
  );
}

double? _parseFlexibleAmount(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return _parseLocalizedAmount(value);
  return null;
}

class _AmountSpan {
  const _AmountSpan({
    required this.start,
    required this.end,
    required this.amount,
  });

  final int start;
  final int end;
  final SmartInputAmountMeasurement amount;
}

final RegExp _amountPattern = RegExp(
  r"[+\-]?[0-9\u0660-\u0669\u06F0-\u06F9\u0966-\u096F\uFF10-\uFF19](?:[0-9\u0660-\u0669\u06F0-\u06F9\u0966-\u096F\uFF10-\uFF19.,\u066B\u066C'’]*[0-9\u0660-\u0669\u06F0-\u06F9\u0966-\u096F\uFF10-\uFF19])?",
);

double? _parseLocalizedAmount(String raw) {
  final normalized = _normalizeDecimalDigits(raw)
      .replaceAll('\u066B', '.')
      .replaceAll('\u066C', ',')
      .replaceAll(RegExp(r"[\s'’]"), '')
      .trim();
  if (normalized.isEmpty) return null;

  final sign = normalized.startsWith('-') ? '-' : '';
  final unsigned = normalized.replaceFirst(RegExp(r'^[+\-]'), '');
  if (!RegExp(r'\d').hasMatch(unsigned)) return null;

  final decimalSeparator = _detectDecimalSeparator(unsigned);
  String canonical;
  if (decimalSeparator == null) {
    canonical = unsigned.replaceAll(RegExp(r'[,.]'), '');
  } else {
    final separatorIndex = unsigned.lastIndexOf(decimalSeparator);
    final integerPart =
        unsigned.substring(0, separatorIndex).replaceAll(RegExp(r'[,.]'), '');
    final decimalPart =
        unsigned.substring(separatorIndex + 1).replaceAll(RegExp(r'[,.]'), '');
    canonical = '$integerPart.$decimalPart';
  }

  if (canonical.isEmpty || canonical == '.') return null;
  return double.tryParse('$sign$canonical');
}

String? _detectDecimalSeparator(String normalized) {
  final lastDot = normalized.lastIndexOf('.');
  final lastComma = normalized.lastIndexOf(',');
  final lastSeparator = lastDot > lastComma ? lastDot : lastComma;
  if (lastSeparator < 0) return null;

  final trailingDigits =
      normalized.substring(lastSeparator + 1).replaceAll(RegExp(r'\D'), '');
  if (trailingDigits.isEmpty) return null;

  final separator = normalized[lastSeparator];
  final hasBothSeparators = lastDot >= 0 && lastComma >= 0;
  if (hasBothSeparators) return separator;
  if (trailingDigits.length <= 2) return separator;
  return null;
}

String _normalizeDecimalDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final digit = _decimalDigitValue(rune);
    if (digit != null) {
      buffer.write(digit);
    } else {
      buffer.write(String.fromCharCode(rune));
    }
  }
  return buffer.toString();
}

int? _decimalDigitValue(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return rune - 0x30;
  if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660;
  if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0;
  if (rune >= 0x0966 && rune <= 0x096F) return rune - 0x0966;
  if (rune >= 0xFF10 && rune <= 0xFF19) return rune - 0xFF10;
  return null;
}

String _amountDecoratorSignature(String input, RegExpMatch match) {
  final prefix = _collectAdjacentDecorators(
    input,
    start: match.start,
    direction: -1,
  );
  final suffix = _collectAdjacentDecorators(
    input,
    start: match.end - 1,
    direction: 1,
  );
  final decorators = '$prefix$suffix'.runes.toList()..sort();
  return String.fromCharCodes(decorators);
}

String _collectAdjacentDecorators(
  String input, {
  required int start,
  required int direction,
}) {
  final chars = <String>[];
  var index = start + direction;
  while (index >= 0 && index < input.length) {
    final code = input.codeUnitAt(index);
    if (_isWhitespace(code) ||
        _isWordCodeUnit(code) ||
        code == 0x2E ||
        code == 0x2C ||
        code == 0x066B ||
        code == 0x066C ||
        code == 0x27 ||
        code == 0x2019) {
      break;
    }
    chars.add(input[index]);
    index += direction;
  }
  if (direction < 0) {
    return chars.reversed.join().toLowerCase();
  }
  return chars.join().toLowerCase();
}

String _removeSpans(String input, List<_AmountSpan> spans) {
  if (spans.isEmpty) return input;
  final buffer = StringBuffer();
  var cursor = 0;
  for (final span in spans) {
    if (span.start > cursor) {
      buffer.write(input.substring(cursor, span.start));
    }
    buffer.write(' ');
    cursor = span.end;
  }
  if (cursor < input.length) {
    buffer.write(input.substring(cursor));
  }
  return buffer.toString();
}

List<String> _wordTokens(String input) {
  final normalized = _normalizeDecimalDigits(input).toLowerCase();
  final buffer = StringBuffer();
  for (final rune in normalized.runes) {
    if (_isWordRune(rune)) {
      buffer.write(String.fromCharCode(rune));
    } else {
      buffer.write(' ');
    }
  }
  return buffer
      .toString()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

bool _isWordRune(int rune) {
  if (_decimalDigitValue(rune) != null) return true;
  if (rune >= 0x41 && rune <= 0x5A) return true;
  if (rune >= 0x61 && rune <= 0x7A) return true;
  if (rune == 0x5F) return true;
  if (rune > 0x7F &&
      !_isWhitespace(rune) &&
      !_isSymbolOrPunctuationRune(rune)) {
    return true;
  }
  return false;
}

bool _isSymbolOrPunctuationRune(int rune) {
  return (rune >= 0x2000 && rune <= 0x206F) ||
      (rune >= 0x20A0 && rune <= 0x20CF) ||
      (rune >= 0x2190 && rune <= 0x2BFF) ||
      (rune >= 0x3000 && rune <= 0x303F) ||
      (rune >= 0xFE10 && rune <= 0xFE1F) ||
      (rune >= 0xFE30 && rune <= 0xFE6F) ||
      (rune >= 0xFF00 && rune <= 0xFF65) ||
      (rune >= 0x1F000 && rune <= 0x1FAFF);
}

bool _isWordCodeUnit(int codeUnit) {
  return _isWordRune(codeUnit);
}

bool _isWhitespace(int rune) {
  return rune == 0x20 ||
      rune == 0x09 ||
      rune == 0x0A ||
      rune == 0x0D ||
      rune == 0x0B ||
      rune == 0x0C;
}

String? _normalizeMerchant(String? merchant) {
  final normalized = merchant?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.replaceAll(RegExp(r'\s+'), ' ');
}

int _cadenceMatchCount({
  required List<DateTime> dates,
  required int minDays,
  required int maxDays,
}) {
  if (dates.length < 2) return 0;

  final sorted = dates.toList()..sort((a, b) => b.compareTo(a));
  var matches = 0;
  for (var index = 0; index < sorted.length - 1; index++) {
    final days = sorted[index].difference(sorted[index + 1]).inDays.abs();
    if (days >= minDays && days <= maxDays) {
      matches += 1;
    }
  }
  return matches;
}
