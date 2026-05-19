import 'package:moneko/core/utils/user_timezone.dart';

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
  });

  final bool isRecurring;
  final Map<String, dynamic>? recurrenceRule;
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

Map<String, RecurringInferenceResult> inferRecurringTransactions(
  Iterable<RecurringInferenceInput> transactions,
) {
  final items = transactions.toList(growable: false);
  final results = <String, RecurringInferenceResult>{
    for (final item in items)
      item.id: RecurringInferenceResult(
        isRecurring: item.isRecurring,
        recurrenceRule: item.recurrenceRule,
      ),
  };

  if (items.length < 2) return results;

  final groups = <String, List<RecurringInferenceInput>>{};
  for (final item in items) {
    final merchantKey = normalizeRecurringMerchant(
      item.merchant ?? item.description,
    );
    if (merchantKey == null) continue;
    final key = [
      item.accountId ?? '',
      (item.type ?? 'expense').toLowerCase(),
      (item.currency ?? '').toUpperCase(),
      merchantKey,
    ].join('|');
    groups.putIfAbsent(key, () => <RecurringInferenceInput>[]).add(item);
  }

  for (final group in groups.values) {
    final cluster = _largestAmountCluster(group);
    final pattern = _detectRecurrencePattern(cluster);
    if (pattern == null || cluster.isEmpty) continue;

    final sorted = cluster.toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
    final anchor = sorted.first.date;
    if (anchor == null) continue;

    for (final item in cluster) {
      results[item.id] = RecurringInferenceResult(
        isRecurring: true,
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
        .where((item) => _amountsCloseEnough(item.amountCents!, seed.amountCents!))
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
  return delta <= 500 || delta / larger <= 0.15;
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
    _RecurrenceCandidate('daily', null, 1, 1, 2),
    _RecurrenceCandidate('weekly', null, 6, 8, 2),
    _RecurrenceCandidate('biweekly', null, 13, 16, 2),
    _RecurrenceCandidate('monthly', null, 27, 34, 2),
    _RecurrenceCandidate('monthly', 3, 84, 98, 1),
    _RecurrenceCandidate('monthly', 6, 175, 190, 1),
    _RecurrenceCandidate('yearly', null, 350, 380, 1),
  ];

  for (final candidate in candidates) {
    final matches =
        gaps.where((gap) => gap >= candidate.min && gap <= candidate.max).toList();
    if (matches.length < candidate.needsIntervals) continue;
    final average =
        matches.reduce((sum, gap) => sum + gap) / matches.length;
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
