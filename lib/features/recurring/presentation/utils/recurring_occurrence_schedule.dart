import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

List<DateTime> getOccurrencesList(
  RecurringTransaction transaction,
  DateTime userNow,
) {
  if (transaction.recurrenceRule == null) return [transaction.date];

  final rule = transaction.recurrenceRule!;
  final interval = rule.interval ?? 1;
  final effectiveInterval = interval <= 0 ? 1 : interval;
  final dates = <DateTime>[];
  var current = DateTime(
    rule.anchorDate.year,
    rule.anchorDate.month,
    rule.anchorDate.day,
  );
  final endLimit = userNow.add(const Duration(days: 90));

  for (var i = 0; i < 50; i++) {
    if (rule.endDate != null && current.isAfter(rule.endDate!)) break;

    final isExcluded = rule.excludedDates.any((date) =>
        date.year == current.year &&
        date.month == current.month &&
        date.day == current.day);
    if (!isExcluded) dates.add(current);

    current = switch (rule.frequency) {
      'daily' => current.add(Duration(days: effectiveInterval)),
      'weekly' => current.add(Duration(days: 7 * effectiveInterval)),
      'biweekly' => current.add(Duration(days: 14 * effectiveInterval)),
      'monthly' => DateTime(
          current.year,
          current.month + effectiveInterval,
          current.day,
        ),
      'yearly' => DateTime(
          current.year + effectiveInterval,
          current.month,
          current.day,
        ),
      _ => current.add(const Duration(days: 30)),
    };
    if (current.isAfter(endLimit)) break;
  }

  dates.sort();
  return dates;
}

DateTime confirmationOpensAt(
  RecurringTransaction transaction,
  DateTime scheduledOccurrenceDate,
) {
  final rule = transaction.recurrenceRule;
  if (rule?.reminderEnabled != true) return scheduledOccurrenceDate;

  final value = rule?.reminderValue ?? 0;
  if (value <= 0) return scheduledOccurrenceDate;

  return switch (rule?.reminderUnit?.toLowerCase()) {
    'days' => scheduledOccurrenceDate.subtract(Duration(days: value)),
    'hours' => scheduledOccurrenceDate.subtract(Duration(hours: value)),
    _ => scheduledOccurrenceDate,
  };
}

bool canConfirmOccurrenceAt(
  RecurringTransaction transaction,
  DateTime scheduledOccurrenceDate,
  DateTime userNow,
) {
  final userWallNow = DateTime(
    userNow.year,
    userNow.month,
    userNow.day,
    userNow.hour,
    userNow.minute,
    userNow.second,
    userNow.millisecond,
    userNow.microsecond,
  );
  return !userWallNow.isBefore(
    confirmationOpensAt(transaction, scheduledOccurrenceDate),
  );
}
