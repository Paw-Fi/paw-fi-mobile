import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/presentation/widgets/household_member_spending_card.dart';
import 'package:moneko/l10n/app_localizations.dart';

HouseholdSummary _summary() => const HouseholdSummary(
      householdId: 'household-1',
      currency: 'USD',
      period: DatePeriod(startDate: '2026-08-01', endDate: '2026-08-31'),
      totals: Totals(
        totalExpensesCents: 2000,
        totalIncomeCents: 0,
        netCents: -2000,
        transactionCount: 1,
        splitCount: 1,
      ),
      memberContributions: [
        MemberContribution(
          userId: 'member-a',
          userName: 'Avery',
          totalSpentCents: 1000,
          transactionCount: 1,
          splitCount: 1,
          balanceCents: 0,
        ),
        MemberContribution(
          userId: 'member-b',
          userName: 'Blair',
          totalSpentCents: 1000,
          transactionCount: 1,
          splitCount: 1,
          balanceCents: 0,
        ),
      ],
      categoryBreakdown: [],
      budgets: [],
      balances: {},
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'anon',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // Another household widget test may have initialized Supabase already.
    }
  });

  testWidgets(
    'keeps the derived member summary visible while the optional member list refreshes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => buildHouseholdMemberSpendingCard(
                context,
                AppTheme.lightTheme().colorScheme,
                _summary(),
                householdId: 'household-1',
                selectedCurrency: 'USD',
                dateRangeFilter: DateRangeFilter.custom,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Avery'), findsOneWidget);
      expect(find.text('Blair'), findsOneWidget);
    },
  );
}
