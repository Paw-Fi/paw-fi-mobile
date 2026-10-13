import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/utils/budget_companion_style.dart';
import 'package:moneko/features/home/presentation/widgets/dashboard_budget_header.dart';
import 'package:moneko/features/home/presentation/widgets/home_period_selector.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  for (final dark in [false, true]) {
    for (final sample in [
      (.44, BudgetCompanionReaction.happy),
      (8479.15 / 15000, BudgetCompanionReaction.encouraging),
      (.7499, BudgetCompanionReaction.encouraging),
      (.75, BudgetCompanionReaction.concerned),
      (.99, BudgetCompanionReaction.concerned),
      (1.0, BudgetCompanionReaction.overBudget),
      (1.08, BudgetCompanionReaction.overBudget),
    ]) {
      testWidgets('ring, gauge and mascot agree at ${sample.$1} dark=$dark',
          (tester) async {
        final summary =
            BudgetCompanionSummary(spent: sample.$1 * 15000, budget: 15000);
        final theme = dark ? AppTheme.darkTheme() : AppTheme.lightTheme();
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: DashboardBudgetHeader(
              summary: AsyncData(summary),
              currency: 'TRY',
              mode: HomePeriodMode.monthly,
              selectedDate: DateTime(2026, 10),
              onBudgetTap: () {},
              onRetry: () {},
            ))),
          ),
        ));
        await tester.pumpAndSettle();
        final gauge = tester
            .widget<BudgetGaugeIndicator>(find.byType(BudgetGaugeIndicator));
        final ring = homeBudgetRingStatus(theme.colorScheme, summary.progress!);
        expect(summary.reaction, sample.$2);
        expect(gauge.color, ring.color);
        expect(gauge.color, sample.$2.accent(theme.colorScheme));
        final mascot = tester.widget<Image>(find.byType(Image).first);
        final image = mascot.image is ResizeImage
            ? (mascot.image as ResizeImage).imageProvider
            : mascot.image;
        expect((image as AssetImage).assetName, sample.$2.mascotAsset);
        if (sample.$2 != BudgetCompanionReaction.happy) {
          expect(find.text("You're on track!"), findsNothing);
        }
      });
    }
  }
}
