import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_rollover_breakdown.dart';

void main() {
  group('PocketRolloverBreakdown', () {
    test('parses opening and monthly contribution payload', () {
      final breakdown = PocketRolloverBreakdown.fromJson({
        'period_month': '2026-06-01',
        'currency': 'EUR',
        'total_incoming_rollover_cents': 42400,
        'opening_rollover_cents': 0,
        'current_rollover_total_cents': 42400,
        'contributions': [
          {
            'source_type': 'opening',
            'source_period_month': '2026-03-01',
            'label': 'Opening balance',
            'amount_cents': 10000,
            'remaining_cents_after_adjustment': 42400,
            'is_carried': true,
            'reason': 'Manual opening rollover.',
          },
          {
            'source_type': 'month_surplus',
            'source_period_month': '2026-04-01',
            'label': 'Apr leftover',
            'amount_cents': 30000,
            'remaining_cents_after_adjustment': 42400,
            'is_carried': true,
          },
          {
            'source_type': 'month_surplus',
            'source_period_month': '2026-05-01',
            'label': 'May leftover',
            'amount_cents': 2400,
            'remaining_cents_after_adjustment': 42400,
            'is_carried': true,
          },
        ],
        'adjustments': [],
        'monthly_history': [
          {
            'period_month': '2026-05-01',
            'base_budget_cents': 10000,
            'incoming_rollover_cents': 40000,
            'opening_rollover_cents': 0,
            'available_budget_cents': 50000,
            'spent_cents': 7600,
            'remaining_cents': 42400,
            'carry_to_next_cents': 42400,
            'rollover_enabled': true,
            'rollover_negative': false,
            'rollover_cap_cents': null,
            'cap_applied_cents': 0,
            'negative_dropped_cents': 0,
          },
        ],
        'warnings': [],
        'next_month_preview': {
          'period_month': '2026-07-01',
          'raw_carry_cents': 50000,
          'carry_cents': 50000,
          'cap_applied_cents': 0,
          'negative_dropped_cents': 0,
        },
      });

      expect(breakdown.currency, 'EUR');
      expect(breakdown.totalIncomingRolloverCents, 42400);
      expect(breakdown.contributions, hasLength(3));
      expect(breakdown.contributions.first.sourceType, 'opening');
      expect(breakdown.contributions[1].amountCents, 30000);
      expect(breakdown.monthlyHistory.single.carryToNextCents, 42400);
      expect(breakdown.hasDetailedContributions, isTrue);
    });

    test('parses cap and negative dropped explanations', () {
      final breakdown = PocketRolloverBreakdown.fromJson({
        'period_month': '2026-06-01',
        'currency': 'USD',
        'total_incoming_rollover_cents': 5000,
        'current_rollover_total_cents': 5000,
        'contributions': [
          {
            'source_type': 'month_surplus',
            'source_period_month': '2026-05-01',
            'label': 'May leftover',
            'amount_cents': 5000,
            'remaining_cents_after_adjustment': 5000,
            'is_carried': true,
          },
        ],
        'adjustments': [
          {
            'source_type': 'cap_adjustment',
            'source_period_month': '2026-05-01',
            'label': 'May cap adjustment',
            'amount_cents': -5000,
            'remaining_cents_after_adjustment': 5000,
            'is_carried': false,
            'reason': 'Rollover cap trimmed carryover.',
          },
          {
            'source_type': 'negative_dropped',
            'source_period_month': '2026-04-01',
            'label': 'Apr overspend not carried',
            'amount_cents': -2500,
            'remaining_cents_after_adjustment': 0,
            'is_carried': false,
            'reason': 'Overspending is not carried.',
          },
        ],
        'monthly_history': [],
        'warnings': [
          {'code': 'missing_month_gap', 'message': 'Missing month'},
        ],
        'next_month_preview': {
          'period_month': '2026-07-01',
          'raw_carry_cents': 12500,
          'carry_cents': 5000,
          'cap_applied_cents': 7500,
          'negative_dropped_cents': 0,
          'rollover_cap_cents': 5000,
        },
      });

      expect(breakdown.explanationRows, hasLength(3));
      expect(breakdown.adjustments[0].sourceType, 'cap_adjustment');
      expect(breakdown.adjustments[1].amountCents, -2500);
      expect(breakdown.warnings.single.message, 'Missing month');
      expect(breakdown.nextMonthPreview.hasCapAdjustment, isTrue);
    });

    test('falls back safely for unavailable or empty RPC payload', () {
      final breakdown = PocketRolloverBreakdown.fromJson({});

      expect(breakdown.currency, 'USD');
      expect(breakdown.totalIncomingRolloverCents, 0);
      expect(breakdown.contributions, isEmpty);
      expect(breakdown.monthlyHistory, isEmpty);
      expect(breakdown.nextMonthPreview.carryCents, 0);
    });
  });
}
