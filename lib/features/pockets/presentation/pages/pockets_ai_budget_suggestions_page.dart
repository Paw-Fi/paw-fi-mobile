import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_style_constants.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_ai_budget_suggestions.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class PocketsAiBudgetSuggestionsPage extends HookConsumerWidget {
  const PocketsAiBudgetSuggestionsPage({
    super.key,
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  static Future<void> open(
    BuildContext context, {
    required PocketsScopeParams scopeParams,
    required String currency,
  }) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PocketsAiBudgetSuggestionsPage(
            scopeParams: scopeParams,
            currency: currency,
          ),
        ),
      );

  static Future<void> openIfEntitled(
    BuildContext context,
    WidgetRef ref, {
    required PocketsScopeParams scopeParams,
    required String currency,
  }) async {
    final hasAccess = await PlusLockedSheet.ensureAccess(
      context,
      ref,
      feature: PlusFeature.aiMonthlyBudgetSuggestions,
    );
    if (!hasAccess || !context.mounted) return;
    await open(
      context,
      scopeParams: scopeParams,
      currency: currency,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isApplying = useState(false);
    final locale = Localizations.localeOf(context).toLanguageTag();

    final request = useMemoized(
      () => PocketsAiBudgetSuggestionsRequest(
        scopeParams: scopeParams,
        currency: currency,
        locale: locale,
      ),
      [scopeParams, currency, locale],
    );

    final result = ref.watch(pocketsAiBudgetSuggestionsProvider(request));
    final pocketsState = ref.watch(pocketsProvider(scopeParams));
    final pocketsNotifier = ref.read(pocketsProvider(scopeParams).notifier);

    final pocketMap = {
      for (final p in pocketsState.editing) p.id: p,
      for (final p in pocketsState.saved) p.id: p,
    };

    final effectiveCurrency =
        currency.trim().isNotEmpty ? currency.trim() : 'USD';
    final currencySymbol = resolveCurrencySymbol(effectiveCurrency);

    final periodMonth = scopeParams.periodMonth ?? DateTime.now();
    final normalizedFinancialStartDay =
        normalizeFinancialMonthStartDay(scopeParams.financialMonthStartDay);
    final isCurrentYear = periodMonth.year == DateTime.now().year;
    final monthLabel = normalizedFinancialStartDay == 1
        ? (isCurrentYear
            ? formatLocalizedMonth(context, periodMonth, abbreviated: false)
            : '${formatLocalizedMonth(context, periodMonth, abbreviated: false)} ${periodMonth.year}')
        : formatLocalizedMonth(context, periodMonth, abbreviated: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.foreground, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.l10n.pocketsAiPageTitle,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.foreground,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: result.when(
        loading: () => _SuggestionsLoadingView(colorScheme: colorScheme),
        error: (error, _) => _SuggestionsErrorView(
          colorScheme: colorScheme,
          onRetry: () =>
              ref.invalidate(pocketsAiBudgetSuggestionsProvider(request)),
        ),
        data: (data) {
          final totalPocketTargetsCents = data.suggestions.fold<int>(
            0,
            (sum, item) => sum + item.amountCents,
          );
          final totalSuggestedCents =
              data.suggestedTotalBudgetCents == totalPocketTargetsCents
                  ? data.suggestedTotalBudgetCents!
                  : totalPocketTargetsCents;
          final totalIncomingCarryCents = data.suggestions.fold<int>(
            0,
            (sum, item) {
              final pocket = pocketMap[item.envelopeId];
              final incomingCarryCents = item.incomingCarryCents ??
                  pocket?.rolloverFromPreviousCents ??
                  pocket?.openingRolloverCents ??
                  0;
              return sum + incomingCarryCents;
            },
          );

          final coachingCards = [
            if (data.celebration != null && data.celebration!.trim().isNotEmpty)
              _CoachingCardItem(
                tag: 'Win',
                title: context.l10n.pocketsAiPageWinsTitle,
                body: data.celebration!.trim(),
                tagColor: colorScheme.primary,
              ),
            if (data.topSpendInsight != null &&
                data.topSpendInsight!.trim().isNotEmpty)
              _CoachingCardItem(
                tag: 'Strategy',
                title: context.l10n.pocketsAiPageInsightsTitle,
                body: data.topSpendInsight!.trim(),
                tagColor: colorScheme.primary,
              ),
            if (data.pocketsHealthTip != null &&
                data.pocketsHealthTip!.trim().isNotEmpty)
              _CoachingCardItem(
                tag: 'Mindset',
                title: context.l10n.pocketsAiPageTipTitle,
                body: data.pocketsHealthTip!.trim(),
                tagColor: colorScheme.primary,
              ),
          ];

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero Editorial Statement (Apple-style Typography)
                      _EditorialHeroHeader(
                        colorScheme: colorScheme,
                        currencySymbol: currencySymbol,
                        totalSuggestedCents: totalSuggestedCents,
                        totalIncomingCarryCents: totalIncomingCarryCents,
                        monthLabel: monthLabel,
                        summary: data.summary,
                      ),
                      const SizedBox(height: 24),

                      // Coaching Stories Carousel
                      if (coachingCards.isNotEmpty) ...[
                        _CoachingFlashCardsCarousel(
                          cards: coachingCards,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Section Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.l10n.pocketsAiPagePocketsSectionTitle.toUpperCase()} (${data.suggestions.length})',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.pocketsAiPagePocketsSectionSubtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.8),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Pocket Suggestion Items
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.suggestions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final item = data.suggestions[index];
                          final pocket = pocketMap[item.envelopeId];
                          return _PocketSuggestionComboItem(
                            item: item,
                            pocket: pocket,
                            totalBudget: pocketsState.totalBudget,
                            usesPreviousMonthPockets:
                                data.usesPreviousMonthPockets,
                            currency: effectiveCurrency,
                            currencySymbol: currencySymbol,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      Text(
                        context.l10n.pocketsAiPageDisclaimer,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.mutedForeground
                              .withValues(alpha: 0.75),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bottom Apply Button
                      PrimaryAdaptiveButton(
                        onPressed: isApplying.value
                            ? null
                            : () async {
                                final rootNavigator =
                                    Navigator.of(context, rootNavigator: true);
                                final toastContext = rootNavigator.context;
                                isApplying.value = true;
                                var dialogOpen = false;
                                showBlockingProcessingDialog(
                                  context: toastContext,
                                  message: context.l10n.saving,
                                );
                                dialogOpen = true;

                                void closeDialog() {
                                  if (!dialogOpen) return;
                                  if (rootNavigator.canPop()) {
                                    rootNavigator.pop();
                                  }
                                  dialogOpen = false;
                                }

                                try {
                                  final sourceSuggestedMap = <String, int>{
                                    for (final s in data.suggestions)
                                      s.envelopeId: s.amountCents,
                                  };
                                  var suggestedMap = sourceSuggestedMap;

                                  if (pocketsState.editing.isEmpty &&
                                      (pocketsState.hasPreviousMonthPockets ||
                                          data.usesPreviousMonthPockets) &&
                                      scopeParams.periodMonth != null) {
                                    final prevMonth =
                                        previousFinancialCycleStart(
                                      scopeParams.periodMonth!,
                                      startDay: scopeParams
                                          .normalizedFinancialMonthStartDay,
                                    );
                                    final copiedPocketIds =
                                        await pocketsNotifier
                                            .copyPocketsFromMonth(prevMonth);
                                    suggestedMap =
                                        rebindCopiedPocketSuggestionAmounts(
                                      sourceAmountsCents: sourceSuggestedMap,
                                      copiedPocketIds: copiedPocketIds,
                                    );
                                  }

                                  pocketsNotifier.applySuggestedPocketAmounts(
                                    suggestedMap,
                                    suggestedTotalBudgetCents:
                                        data.suggestedTotalBudgetCents,
                                  );
                                  await pocketsNotifier.saveChanges();

                                  closeDialog();
                                  if (context.mounted) {
                                    AppToast.success(
                                      context,
                                      context.l10n.pocketsAiPageSuccessToast,
                                    );
                                    Navigator.of(context).pop();
                                  }
                                } catch (error) {
                                  closeDialog();
                                  if (context.mounted) {
                                    AppToast.error(context, error.toString());
                                  }
                                } finally {
                                  closeDialog();
                                  if (context.mounted) {
                                    isApplying.value = false;
                                  }
                                }
                              },
                        prefixIcon: isApplying.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2),
                              )
                            : const SizedBox(),
                        child: Text(context.l10n.apply),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditorialHeroHeader extends StatelessWidget {
  const _EditorialHeroHeader({
    required this.colorScheme,
    required this.currencySymbol,
    required this.totalSuggestedCents,
    required this.totalIncomingCarryCents,
    required this.monthLabel,
    required this.summary,
  });

  final ColorScheme colorScheme;
  final String currencySymbol;
  final int totalSuggestedCents;
  final int totalIncomingCarryCents;
  final String monthLabel;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final totalAvailableCents = totalSuggestedCents + totalIncomingCarryCents;
    final hasDebt = totalIncomingCarryCents < 0;
    final hasComposition = totalIncomingCarryCents != 0;

    final totalDisplay =
        '$currencySymbol${formatLocalizedNumber(context, totalAvailableCents.abs() / 100.0)}';
    final suggestedDisplay =
        '$currencySymbol${formatLocalizedNumber(context, totalSuggestedCents.abs() / 100.0)}';
    final carryDisplay =
        '$currencySymbol${formatLocalizedNumber(context, totalIncomingCarryCents.abs() / 100.0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$monthLabel • AI BLUEPRINT'.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalDisplay,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      height: 1.1,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.pocketsAiPageHeroAvailableLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              if (hasComposition) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: 1,
                  height: 38,
                  color: colorScheme.outline.withValues(alpha: 0.18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      suggestedDisplay,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.pocketsAiPageHeroSuggestedPartLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    hasDebt ? '−' : '+',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      carryDisplay,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: hasDebt
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasDebt
                          ? context.l10n.pocketsAiPageHeroDebtPartLabel
                          : context.l10n.pocketsAiPageHeroCarryPartLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (summary.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: colorScheme.foreground.withValues(alpha: 0.78),
            ),
          ),
        ],
      ],
    );
  }
}

class _CoachingCardItem {
  const _CoachingCardItem({
    required this.tag,
    required this.title,
    required this.body,
    required this.tagColor,
  });

  final String tag;
  final String title;
  final String body;
  final Color tagColor;
}

class _CoachingFlashCardsCarousel extends HookWidget {
  const _CoachingFlashCardsCarousel({
    required this.cards,
    required this.colorScheme,
    required this.textTheme,
  });

  final List<_CoachingCardItem> cards;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final pageController = usePageController(viewportFraction: 0.94);
    final currentPage = useState(0);
    final pageHeights = useState<Map<int, double>>({});

    useEffect(() {
      void onPageChange() {
        if (!pageController.hasClients) return;
        final page = pageController.page?.round() ?? 0;
        if (currentPage.value != page) {
          currentPage.value = page;
        }
      }

      pageController.addListener(onPageChange);
      return () => pageController.removeListener(onPageChange);
    }, [pageController]);

    final activeHeight = pageHeights.value[currentPage.value] ?? 135.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: activeHeight,
            child: PageView.builder(
              controller: pageController,
              itemCount: cards.length,
              onPageChanged: (index) => currentPage.value = index,
              itemBuilder: (context, index) {
                final card = cards[index];
                return OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: _MeasureSize(
                    onChange: (size) {
                      if (pageHeights.value[index] != size.height) {
                        pageHeights.value = {
                          ...pageHeights.value,
                          index: size.height,
                        };
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.cardSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: card.tagColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  card.tag.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: card.tagColor,
                                  ),
                                ),
                              ),
                              Text(
                                '${index + 1} / ${cards.length}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            card.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.body,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (cards.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isSelected = currentPage.value == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.25),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// A combo component: Exact PocketListTile on Top + AI Suggestion Box Outside Beneath It
class _PocketSuggestionComboItem extends StatelessWidget {
  const _PocketSuggestionComboItem({
    required this.item,
    required this.pocket,
    required this.totalBudget,
    required this.usesPreviousMonthPockets,
    required this.currency,
    required this.currencySymbol,
    required this.colorScheme,
    required this.textTheme,
  });

  final PocketsAiBudgetSuggestion item;
  final PocketEnvelope? pocket;
  final double totalBudget;
  final bool usesPreviousMonthPockets;
  final String currency;
  final String currencySymbol;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final rawColor = pocket?.color ?? item.color;
    Color baseColor = getPocketColor(rawColor, colorScheme.primary);
    baseColor = AppTheme.tunedPocketBaseColor(
      baseColor,
      colorScheme,
      hasCustomColor: rawColor != null,
    );

    final iconData = getPocketIconData(pocket?.icon ?? item.icon);
    final pocketName = pocket?.name ??
        item.pocketName ??
        context.l10n.pocketsAiSuggestionsUnknownPocket;

    final spent = pocket?.spent ??
        (item.previousSpentCents != null
            ? item.previousSpentCents! / 100.0
            : 0.0);
    final previousLimit = item.previousBudgetCents != null
        ? item.previousBudgetCents! / 100.0
        : (pocket?.getLimit(totalBudget) ?? 0.0);
    final displayLimit =
        previousLimit > 0 ? previousLimit : item.amountCents / 100.0;

    final spentNormalized = double.parse(formatAmount(spent));
    final spentLocalized = formatLocalizedNumber(context, spentNormalized);
    final spentDisplay = '$currencySymbol$spentLocalized';

    final limitNormalized = double.parse(formatAmount(displayLimit));
    final limitLocalized = formatLocalizedNumber(context, limitNormalized);
    final limitDisplay = '$currencySymbol$limitLocalized';

    // The review response may be built from last month's pocket. Prefer that
    // authoritative carry value over a current-month local row, which can be
    // newly created and therefore still report zero.
    final incomingCarryCents = item.incomingCarryCents ??
        pocket?.rolloverFromPreviousCents ??
        pocket?.openingRolloverCents ??
        0;
    final rolloverEnabled =
        item.rolloverEnabled || (pocket?.rolloverEnabled ?? false);
    final suggestedAvailableCents = item.amountCents + incomingCarryCents;

    String moneyFromCents(int cents, {bool includeSign = false}) {
      final amount = formatLocalizedNumber(context, cents.abs() / 100.0);
      final sign = !includeSign || cents == 0 ? '' : (cents > 0 ? '+' : '-');
      return '$sign$currencySymbol$amount';
    }

    final String? rolloverBadgeText = rolloverEnabled && incomingCarryCents != 0
        ? (incomingCarryCents > 0
            ? '${moneyFromCents(incomingCarryCents, includeSign: true)} carried in'
            : '${moneyFromCents(incomingCarryCents, includeSign: true)} to cover')
        : null;
    final availableAfterPlanDisplay = moneyFromCents(
      suggestedAvailableCents,
      includeSign: suggestedAvailableCents < 0,
    );

    void showPlanDetails() {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: colorScheme.sheetBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _PocketPlanDetailsSheet(
          pocketName: pocketName,
          suggestedAddDisplay: moneyFromCents(item.amountCents),
          incomingCarryDisplay: moneyFromCents(
            incomingCarryCents,
            includeSign: incomingCarryCents != 0,
          ),
          availableAfterPlanDisplay: availableAfterPlanDisplay,
          rolloverEnabled: rolloverEnabled,
          historicalSpentDisplay: spentDisplay,
          historicalPlannedDisplay: limitDisplay,
          historicalPeriodLabel: usesPreviousMonthPockets
              ? context.l10n.pocketsAiPageLastMonthLabel
              : context.l10n.pocketsAiPageThisMonthLabel,
          reason: item.reason.trim(),
          tip: item.tip?.trim(),
          colorScheme: colorScheme,
          baseColor: baseColor,
        ),
      );
    }

    return Semantics(
      container: true,
      label:
          '$pocketName. ${context.l10n.pocketsAiPageAvailableAfterPlanLabel} $availableAfterPlanDisplay. ${context.l10n.pocketsAiPageWhyThisPlanAction}',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.pocketTileFill(baseColor),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colorScheme.pocketTileBorder),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.pocketTileIconSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.pocketIconShadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(iconData, size: 20, color: baseColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
                  decoration: BoxDecoration(
                    color: colorScheme.pocketTileContentSurface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.pocketGlassShadow,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              pocketName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.pocketTitle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                availableAfterPlanDisplay,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: colorScheme.pocketTitle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (rolloverBadgeText != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            rolloverBadgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 44,
                        child: TextButton.icon(
                          key: ValueKey(
                              'pocket-suggestion-details-${item.envelopeId}'),
                          onPressed: showPlanDetails,
                          icon:
                              const Icon(Icons.auto_awesome_outlined, size: 16),
                          label:
                              Text(context.l10n.pocketsAiPageWhyThisPlanAction),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PocketPlanDetailsSheet extends StatelessWidget {
  const _PocketPlanDetailsSheet({
    required this.pocketName,
    required this.suggestedAddDisplay,
    required this.incomingCarryDisplay,
    required this.availableAfterPlanDisplay,
    required this.rolloverEnabled,
    required this.historicalSpentDisplay,
    required this.historicalPlannedDisplay,
    required this.historicalPeriodLabel,
    required this.reason,
    required this.tip,
    required this.colorScheme,
    required this.baseColor,
  });

  final String pocketName;
  final String suggestedAddDisplay;
  final String incomingCarryDisplay;
  final String availableAfterPlanDisplay;
  final bool rolloverEnabled;
  final String historicalSpentDisplay;
  final String historicalPlannedDisplay;
  final String historicalPeriodLabel;
  final String reason;
  final String? tip;
  final ColorScheme colorScheme;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final hasTip = tip != null && tip!.isNotEmpty;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      minChildSize: 0.42,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.sheetBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.pocketsAiPagePlanDetailsTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            pocketName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.mutedForeground,
                ),
          ),
          const SizedBox(height: 20),
          _PlanDetailSection(
            title: context.l10n.pocketsAiPageThisMonthLabel,
            colorScheme: colorScheme,
            children: [
              _PlanDetailRow(
                label: context.l10n.pocketsAiPageSuggestedAddLabel,
                value: suggestedAddDisplay,
                colorScheme: colorScheme,
              ),
              if (rolloverEnabled)
                _PlanDetailRow(
                  label: context.l10n.pocketsAiPageCarryIntoMonthLabel,
                  value: incomingCarryDisplay,
                  colorScheme: colorScheme,
                ),
              _PlanDetailRow(
                label: context.l10n.pocketsAiPageAvailableAfterPlanLabel,
                value: availableAfterPlanDisplay,
                emphasized: true,
                colorScheme: colorScheme,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PlanDetailSection(
            title: historicalPeriodLabel,
            colorScheme: colorScheme,
            children: [
              _PlanDetailRow(
                label: context.l10n.pocketsAiPagePreviousSpentLabel,
                value: historicalSpentDisplay,
                colorScheme: colorScheme,
              ),
              _PlanDetailRow(
                label: context.l10n.pocketsAiPagePlannedLabel,
                value: historicalPlannedDisplay,
                colorScheme: colorScheme,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.pocketsAiPageReasonTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.mutedForeground,
                  height: 1.45,
                ),
          ),
          if (hasTip) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: baseColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.foreground,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanDetailSection extends StatelessWidget {
  const _PlanDetailSection({
    required this.title,
    required this.children,
    required this.colorScheme,
  });

  final String title;
  final List<Widget> children;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _PlanDetailRow extends StatelessWidget {
  const _PlanDetailRow({
    required this.label,
    required this.value,
    required this.colorScheme,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final ColorScheme colorScheme;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
}

class _SuggestionsLoadingView extends StatelessWidget {
  const _SuggestionsLoadingView({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 30,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Analyzing your spending patterns...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Moneko AI is building tailored pocket envelopes for this month.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator.adaptive(),
        ],
      ),
    );
  }
}

class _SuggestionsErrorView extends StatelessWidget {
  const _SuggestionsErrorView({
    required this.colorScheme,
    required this.onRetry,
  });

  final ColorScheme colorScheme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 36, color: colorScheme.mutedForeground),
            const SizedBox(height: 16),
            Text(
              context.l10n.pocketsAiSuggestionsUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryAdaptiveButton(
              onPressed: onRetry,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required this.onChange,
    required super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderMeasureSize renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_oldSize != newSize) {
      _oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChange(newSize);
      });
    }
  }
}
