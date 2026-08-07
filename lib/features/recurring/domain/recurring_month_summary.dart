import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';

double calculateRecurringMonthlyCommittedAmount(
  RecurringSeriesSummary summary,
) {
  final transaction = summary.transaction;
  final rule = transaction.recurrenceRule;
  if (rule == null) return 0;

  final interval = rule.interval ?? 1;
  final effectiveInterval = interval <= 0 ? 1 : interval;
  final monthlyAmount = switch (rule.frequency) {
    'daily' => transaction.amount * (30.0 / effectiveInterval),
    'weekly' => transaction.amount * (4.333333333333333 / effectiveInterval),
    'biweekly' => transaction.amount * 2.1666666666666667,
    'monthly' => transaction.amount / effectiveInterval,
    'yearly' => transaction.amount / (12.0 * effectiveInterval),
    _ => 0.0,
  };

  return monthlyAmount + summary.currentMonthConfirmedAmountDeltaCents / 100.0;
}
