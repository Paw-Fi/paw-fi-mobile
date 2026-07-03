import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_rollover_breakdown.dart';
import 'package:moneko/features/pockets/presentation/pages/pocket_details_page.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  group('RolloverContributionCard', () {
    testWidgets('renders opening and multiple month contributions',
        (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: RolloverContributionCard(
            currency: 'USD',
            breakdown: _breakdown({
              'current_rollover_total_cents': 42400,
              'contributions': [
                _contribution('opening', '2026-03-01', 10000),
                _contribution('month_surplus', '2026-04-01', 30000),
                _contribution('month_surplus', '2026-05-01', 2400),
              ],
            }),
          ),
        ),
      );

      expect(find.text('Where this rollover came from'), findsOneWidget);
      expect(find.text('Opening rollover'), findsOneWidget);
      expect(find.text('April leftover'), findsOneWidget);
      expect(find.text('May leftover'), findsOneWidget);
    });

    testWidgets('renders capped rollover explanation', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: RolloverContributionCard(
            currency: 'USD',
            breakdown: _breakdown({
              'current_rollover_total_cents': 5000,
              'contributions': [
                _contribution('month_surplus', '2026-05-01', 5000),
              ],
              'adjustments': [
                _contribution('cap_adjustment', '2026-05-01', -5000),
              ],
            }),
          ),
        ),
      );

      expect(find.text('Cap adjustment'), findsOneWidget);
    });

    testWidgets('renders negative dropped explanation', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: RolloverContributionCard(
            currency: 'USD',
            breakdown: _breakdown({
              'current_rollover_total_cents': 0,
              'contributions': [],
              'adjustments': [
                _contribution('negative_dropped', '2026-05-01', -2500),
              ],
            }),
          ),
        ),
      );

      expect(find.text('Overspend not carried'), findsOneWidget);
    });

    testWidgets('renders empty fallback state', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: RolloverContributionCard(
            currency: 'USD',
            breakdown: _breakdown({
              'current_rollover_total_cents': 0,
              'contributions': [],
              'adjustments': [],
            }),
          ),
        ),
      );

      expect(
        find.text('No rollover has been carried into this month yet.'),
        findsOneWidget,
      );
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme(),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }
}

PocketRolloverBreakdown _breakdown(Map<String, dynamic> overrides) {
  return PocketRolloverBreakdown.fromJson({
    'period_month': '2026-06-01',
    'currency': 'USD',
    'total_incoming_rollover_cents': 0,
    'opening_rollover_cents': 0,
    'current_rollover_total_cents': 0,
    'contributions': [],
    'adjustments': [],
    'monthly_history': [],
    'warnings': [],
    'next_month_preview': {
      'period_month': '2026-07-01',
      'raw_carry_cents': 0,
      'carry_cents': 0,
      'cap_applied_cents': 0,
      'negative_dropped_cents': 0,
    },
    ...overrides,
  });
}

Map<String, dynamic> _contribution(
  String sourceType,
  String periodMonth,
  int amountCents,
) {
  return {
    'source_type': sourceType,
    'source_period_month': periodMonth,
    'label': sourceType,
    'amount_cents': amountCents,
    'remaining_cents_after_adjustment': amountCents,
    'is_carried': sourceType != 'cap_adjustment' &&
        sourceType != 'negative_dropped' &&
        sourceType != 'reset',
    'reason': null,
  };
}
