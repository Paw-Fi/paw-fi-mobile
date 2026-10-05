import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/pockets/presentation/pages/pockets_ai_budget_suggestions_page.dart';
import 'package:moneko/features/pockets/presentation/state/monthly_intro_insights.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class PocketsAiBudgetIntroSheet extends HookConsumerWidget {
  const PocketsAiBudgetIntroSheet({
    super.key,
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required PocketsScopeParams scopeParams,
    required String currency,
  }) async {
    final buildWithAi = await MonekoBottomSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PocketsAiBudgetIntroSheet(
        scopeParams: scopeParams,
        currency: currency,
      ),
    );
    if (buildWithAi != true || !context.mounted) return;
    await PocketsAiBudgetSuggestionsPage.openIfEntitled(
      context,
      ref,
      scopeParams: scopeParams,
      currency: currency,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final targetMonth = scopeParams.periodMonth ?? DateTime.now();
    final monthLabel = formatLocalizedMonth(
      context,
      targetMonth,
      abbreviated: false,
    );

    final insightParams = MonthlyIntroInsightsParams(
      scopeParams: scopeParams,
      currency: currency,
    );
    final introState = ref.watch(monthlyIntroInsightsProvider(insightParams));
    final insight = introState.primaryInsight;
    final previousSetup =
        ref.watch(latestPreviousPocketMonthProvider(scopeParams));
    final sourceMonth = previousSetup.valueOrNull;
    final isCopying = useState(false);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (introState.milestoneText != null &&
                insight.type != MonthlyInsightType.longevityMilestone) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.sheetElementBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        introState.milestoneText!,
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Center(
              child: Image.asset(
                'lib/assets/gifs/moneko-celebrate.gif',
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.helloMonth(monthLabel).toUpperCase(),
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.aFreshMonthStartsHere,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _HeroInsightCard(
                key: ValueKey(
                  '${insight.type.name}_${insight.headline}_${introState.isLoading}',
                ),
                insight: insight,
                isLoading: introState.isLoading,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryAdaptiveButton(
              onPressed: isCopying.value
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: Text(context.l10n.buildMyMonthPlan(monthLabel)),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: sourceMonth != null
                    ? PrimaryAdaptiveButton.outlined(
                        key: const ValueKey('copy-previous-plan'),
                        onPressed: isCopying.value
                            ? null
                            : () async {
                                if (isCopying.value) return;
                                isCopying.value = true;
                                final notifier = ref.read(
                                    pocketsProvider(scopeParams).notifier);
                                final formatter =
                                    MaterialLocalizations.of(context);
                                try {
                                  final result = await MonekoAlertDialog.show(
                                    context: context,
                                    title: context
                                        .l10n.pocketsCopyPreviousPlanTitle,
                                    description:
                                        '${context.l10n.pocketsCopyPreviousPlanDescription}\n\n'
                                        '${formatter.formatMonthYear(sourceMonth)} -> '
                                        '${formatter.formatMonthYear(targetMonth)} ($currency)',
                                    confirmLabel:
                                        context.l10n.pocketsCopyConfirm,
                                    cancelLabel: context.l10n.cancel,
                                  );
                                  if (result?.confirmed != true ||
                                      !context.mounted) {
                                    return;
                                  }
                                  await notifier
                                      .copyPocketsFromMonth(sourceMonth);
                                  if (!context.mounted) return;
                                  AppToast.success(context,
                                      context.l10n.budgetCreatedSuccessfully);
                                  Navigator.of(context).pop();
                                } catch (error) {
                                  if (context.mounted) {
                                    AppToast.error(
                                        context,
                                        ErrorHandler.getUserFriendlyMessage(
                                            error));
                                  }
                                } finally {
                                  if (context.mounted) isCopying.value = false;
                                }
                              },
                        child: Text(isCopying.value
                            ? context.l10n.pocketsCopyingAction
                            : context.l10n.pocketsCopyLastMonthAction),
                      )
                    : previousSetup.isLoading
                        ? Container(
                            key: const ValueKey('previous-plan-loading'),
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.sheetElementBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          )
                        : previousSetup.hasError
                            ? PlainAdaptiveButton(
                                onPressed: () => ref.invalidate(
                                    latestPreviousPocketMonthProvider(
                                        scopeParams)),
                                child: Text(context.l10n.tryAgain),
                              )
                            : const SizedBox.shrink(),
              ),
            ),
         
          ],
        ),
      ),
    );
  }
}

class _HeroInsightCard extends StatelessWidget {
  const _HeroInsightCard({
    super.key,
    required this.insight,
    required this.isLoading,
  });

  final MonthlyIntroInsight insight;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (badgeBg, badgeText) = switch (insight.sentiment) {
      MonthlyInsightSentiment.positive => (
          colorScheme.successSurface,
          colorScheme.success,
        ),
      MonthlyInsightSentiment.supportive => (
          colorScheme.infoSurface,
          colorScheme.primary,
        ),
      MonthlyInsightSentiment.neutral => (
          colorScheme.muted,
          colorScheme.mutedForeground,
        ),
    };
    final metric = insight.metric;
    final metricHasLeadingMinus =
        metric?.startsWith('-') == true || metric?.startsWith('−') == true;
    final metricHasLeadingPlus = metric?.startsWith('+') == true;
    final metricValue =
        metric == null || (!metricHasLeadingMinus && !metricHasLeadingPlus)
            ? metric
            : metric.substring(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  insight.badge,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: badgeText,
                  ),
                ),
              ),
              if (metricValue != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (metricHasLeadingMinus || metricHasLeadingPlus)
                      Icon(
                        metricHasLeadingMinus
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        size: 20,
                        color: badgeText,
                      ),
                    Text(
                      metricValue,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.headline,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.description,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
          if (insight.metricLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              insight.metricLabel!,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
