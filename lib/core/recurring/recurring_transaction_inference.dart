import 'package:moneko/core/utils/user_timezone.dart';

const double recurringAmountRelativeTolerance = 0.01;
const double recurringDescriptionEditTolerance = 0.10;
const double recurringDescriptionTokenSimilarity = 0.90;

class RecurringInferenceInput {
  const RecurringInferenceInput({
    required this.id,
    required this.date,
    required this.amountCents,
    required this.currency,
    required this.type,
    required this.accountId,
    required this.merchant,
    required this.description,
    this.isRecurring = false,
    this.recurrenceRule,
  });

  final String id;
  final DateTime? date;
  final int? amountCents;
  final String? currency;
  final String? type;
  final String? accountId;
  final String? merchant;
  final String? description;
  final bool isRecurring;
  final Map<String, dynamic>? recurrenceRule;
}

class RecurringInferenceResult {
  const RecurringInferenceResult({
    required this.isRecurring,
    required this.recurrenceRule,
    this.seriesKey,
    this.isSeriesAnchor = false,
  });

  final bool isRecurring;
  final Map<String, dynamic>? recurrenceRule;
  final String? seriesKey;
  final bool isSeriesAnchor;
}

class _RecurrencePattern {
  const _RecurrencePattern({
    required this.frequency,
    required this.interval,
    required this.confidence,
    required this.matchCount,
    required this.cadenceDays,
  });

  final String frequency;
  final int? interval;
  final String confidence;
  final int matchCount;
  final int cadenceDays;
}

class _RecurrenceCandidate {
  const _RecurrenceCandidate(
    this.frequency,
    this.interval,
    this.min,
    this.max,
    this.needsIntervals,
  );

  final String frequency;
  final int? interval;
  final int min;
  final int max;
  final int needsIntervals;
}

class _RecurringInferenceGroup {
  _RecurringInferenceGroup({
    required this.accountId,
    required this.type,
    required this.currency,
    required this.merchantKey,
    required this.items,
  });

  final String accountId;
  final String type;
  final String currency;
  final String merchantKey;
  final List<RecurringInferenceInput> items;
}

Map<String, RecurringInferenceResult> inferRecurringTransactions(
  Iterable<RecurringInferenceInput> transactions,
) {
  final items = transactions.toList(growable: false);
  final results = <String, RecurringInferenceResult>{
    for (final item in items)
      item.id: RecurringInferenceResult(
        isRecurring: item.isRecurring,
        recurrenceRule: item.recurrenceRule,
        isSeriesAnchor: item.isRecurring,
      ),
  };

  if (items.length < 2) return results;

  final groups = <_RecurringInferenceGroup>[];
  for (final item in items) {
    final merchantKey = normalizeRecurringMerchant(
      item.merchant ?? item.description,
    );
    if (merchantKey == null) continue;
    final accountId = item.accountId ?? '';
    final type = (item.type ?? 'expense').toLowerCase();
    final currency = (item.currency ?? '').toUpperCase();
    final existingGroup = _findMatchingGroup(
      groups: groups,
      accountId: accountId,
      type: type,
      currency: currency,
      merchantKey: merchantKey,
    );

    if (existingGroup != null) {
      existingGroup.items.add(item);
      continue;
    }

    groups.add(
      _RecurringInferenceGroup(
        accountId: accountId,
        type: type,
        currency: currency,
        merchantKey: merchantKey,
        items: <RecurringInferenceInput>[item],
      ),
    );
  }

  for (final group in groups) {
    final cluster = _largestAmountCluster(group.items);
    final pattern = _detectRecurrencePattern(cluster);
    if (pattern == null || cluster.isEmpty) continue;

    final sorted = cluster.toList()..sort((a, b) => a.date!.compareTo(b.date!));
    final anchor = sorted.first.date;
    if (anchor == null) continue;
    final anchorId = sorted.first.id;
    final seriesKey = [
      group.accountId,
      group.type,
      group.currency,
      group.merchantKey,
      pattern.frequency,
      pattern.interval ?? 1,
    ].join('|');

    for (final item in cluster) {
      results[item.id] = RecurringInferenceResult(
        isRecurring: true,
        seriesKey: seriesKey,
        isSeriesAnchor: item.id == anchorId,
        recurrenceRule: item.recurrenceRule ??
            {
              'frequency': pattern.frequency,
              'anchor_date': formatDateOnlyYmd(anchor),
              if (pattern.interval != null && pattern.interval! > 1)
                'interval': pattern.interval,
              'provider_hint': {
                'source': 'pattern',
                'confidence': pattern.confidence,
                'match_count': pattern.matchCount,
                'cadence_days': pattern.cadenceDays,
              },
            },
      );
    }
  }

  return results;
}

String? normalizeRecurringMerchant(String? value) {
  final normalized = (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\b\d{2,}\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalized.length < 3 ? null : normalized;
}

_RecurringInferenceGroup? _findMatchingGroup({
  required List<_RecurringInferenceGroup> groups,
  required String accountId,
  required String type,
  required String currency,
  required String merchantKey,
}) {
  for (final group in groups) {
    if (group.accountId == accountId &&
        group.type == type &&
        group.currency == currency &&
        _merchantKeysAreSimilar(group.merchantKey, merchantKey)) {
      return group;
    }
  }
  return null;
}

bool _merchantKeysAreSimilar(String left, String right) {
  if (left == right) return true;

  final shorter = left.length <= right.length ? left : right;
  final longer = left.length <= right.length ? right : left;
  if (shorter.length >= 6 && longer.startsWith(shorter)) return true;

  final leftTokens = _merchantTokens(left);
  final rightTokens = _merchantTokens(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return _editDistance(left, right) <= _allowedNameDistance(left, right);
  }

  final shared = leftTokens.intersection(rightTokens).length;
  final union = leftTokens.union(rightTokens).length;
  if (union > 0 && shared / union >= recurringDescriptionTokenSimilarity) {
    return true;
  }

  return _editDistance(left, right) <= _allowedNameDistance(left, right);
}

Set<String> _merchantTokens(String value) {
  return value.split(' ').where((token) => token.length >= 3).toSet();
}

int _allowedNameDistance(String left, String right) {
  final maxLength = left.length > right.length ? left.length : right.length;
  if (maxLength < 6) return 0;
  final tolerance = (maxLength * recurringDescriptionEditTolerance).round();
  return tolerance < 1 ? 1 : tolerance;
}

int _editDistance(String left, String right) {
  if (left == right) return 0;
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;

  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 0; i < left.length; i += 1) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < right.length; j += 1) {
      final cost = left.codeUnitAt(i) == right.codeUnitAt(j) ? 0 : 1;
      final deletion = previous[j + 1] + 1;
      final insertion = current[j] + 1;
      final substitution = previous[j] + cost;
      current[j + 1] =
          [deletion, insertion, substitution].reduce((a, b) => a < b ? a : b);
    }
    previous = current;
  }

  return previous.last;
}

List<RecurringInferenceInput> _largestAmountCluster(
  List<RecurringInferenceInput> transactions,
) {
  final sorted = transactions
      .where((item) => item.date != null && (item.amountCents ?? 0) > 0)
      .toList()
    ..sort((a, b) => a.amountCents!.compareTo(b.amountCents!));
  var best = <RecurringInferenceInput>[];
  for (final seed in sorted) {
    final cluster = sorted
        .where(
            (item) => _amountsCloseEnough(item.amountCents!, seed.amountCents!))
        .toList(growable: false);
    if (cluster.length > best.length) {
      best = cluster;
    }
  }
  return best;
}

bool _amountsCloseEnough(int a, int b) {
  final delta = (a - b).abs();
  final larger = [a.abs(), b.abs(), 1].reduce((x, y) => x > y ? x : y);
  final tolerance = (larger * recurringAmountRelativeTolerance).round();
  return delta <= (tolerance < 1 ? 1 : tolerance);
}

_RecurrencePattern? _detectRecurrencePattern(
  List<RecurringInferenceInput> transactions,
) {
  final dates = transactions
      .map((item) => item.date)
      .whereType<DateTime>()
      .map((date) => DateTime(date.year, date.month, date.day))
      .toSet()
      .toList()
    ..sort();
  if (dates.length < 2) return null;

  final gaps = <int>[];
  for (var i = 1; i < dates.length; i += 1) {
    gaps.add(dates[i].difference(dates[i - 1]).inDays);
  }

  const candidates = <_RecurrenceCandidate>[
    _RecurrenceCandidate('daily', null, 1, 2, 2),
    _RecurrenceCandidate('weekly', null, 4, 10, 2),
    _RecurrenceCandidate('biweekly', null, 11, 17, 2),
    _RecurrenceCandidate('monthly', null, 24, 37, 2),
    _RecurrenceCandidate('monthly', 3, 81, 101, 1),
    _RecurrenceCandidate('monthly', 6, 172, 193, 1),
    _RecurrenceCandidate('yearly', null, 347, 383, 1),
  ];

  for (final candidate in candidates) {
    final matches = gaps
        .where((gap) => gap >= candidate.min && gap <= candidate.max)
        .toList();
    if (matches.length < candidate.needsIntervals) continue;
    final average = matches.reduce((sum, gap) => sum + gap) / matches.length;
    return _RecurrencePattern(
      frequency: candidate.frequency,
      interval: candidate.interval,
      confidence: matches.length >= 2 ? 'high' : 'medium',
      matchCount: matches.length,
      cadenceDays: average.round(),
    );
  }

  return null;
}
