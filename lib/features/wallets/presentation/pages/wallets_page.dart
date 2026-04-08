import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/pages/wallet_details_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/swipe_hint_row.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';

class AccountsPage extends HookConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonthIndexState = useState(0);
    final monthPageController = usePageController(viewportFraction: 0.96);
    final colorScheme = Theme.of(context).colorScheme;
    final walletsAsync = ref.watch(scopedWalletsProvider);
    final effectiveWallets = ref.watch(effectiveScopeWalletsProvider);
    final actions = ref.watch(walletActionsProvider);
    final auth = ref.watch(authProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
    final householdScope = ref.watch(householdScopeProvider);
    // CRITICAL: wallet history/month snapshots must anchor to the user's month.
    // STRICT REQUIREMENT: do not replace this with DateTime.now(), or
    // recurring transactions near month boundaries can land in the wrong month
    // and wallets drift away from pockets/details again.
    final effectiveNowForUser =
        effectiveNow(preferredTimezone: preferredTimezone);
    final currentMonthStart =
        DateTime(effectiveNowForUser.year, effectiveNowForUser.month);
    // CRITICAL: the wallets landing page must stay wired to recurring-aware
    // month history and month snapshot providers.
    // STRICT REQUIREMENT: if this page switches back to non-recurring month
    // data, recurring bills disappear from the main wallets cards even while
    // details and pockets still project them.
    final scopeQuery = WalletsScopeQuery(
      userId: auth.uid,
      householdId: _resolveWalletsScopeHouseholdId(householdScope),
      selectedCurrency: selectedCurrencyCode,
      currentMonthStart: currentMonthStart,
    );
    final historyAsync = ref.watch(walletsHistoryProvider(scopeQuery));
    final viewMode = ref.watch(viewModeProvider);
    final AsyncValue<List<Household>> householdsAsync =
        viewMode.mode == ViewMode.personal
            ? const AsyncValue<List<Household>>.data(<Household>[])
            : ref.watch(userHouseholdsProvider(ref.watch(authProvider).uid));

    Future<void> onRefresh() async {
      ref.invalidate(scopedWalletsProvider);
      await ref.read(scopedWalletsProvider.future);

      ref.invalidate(walletsHistoryProvider(scopeQuery));
      final history = await ref.read(walletsHistoryProvider(scopeQuery).future);
      final months = history.availableMonths.isEmpty
          ? <DateTime>[scopeQuery.currentMonthStart]
          : history.availableMonths;
      final selectedMonthIndex =
          selectedMonthIndexState.value.clamp(0, months.length - 1).toInt();
      final selectedMonthQuery = WalletsMonthQuery(
        scope: scopeQuery,
        monthStart: months[selectedMonthIndex],
      );
      ref.invalidate(walletsMonthSnapshotProvider(selectedMonthQuery));
      await ref.read(walletsMonthSnapshotProvider(selectedMonthQuery).future);
    }

    final availableMonths =
        historyAsync.valueOrNull?.availableMonths.isNotEmpty == true
            ? historyAsync.valueOrNull!.availableMonths
            : <DateTime>[scopeQuery.currentMonthStart];
    final maxMonthIndex = availableMonths.length - 1;
    final swipeHintPrefKey = _walletsMonthSwipeHintDismissedKey(auth.uid);
    final hasDismissedSwipeHintState =
        useState<bool>(prefs.getBool(swipeHintPrefKey) ?? false);
    final currentTabIndex = ref.watch(mainShellTabIndexProvider);
    final locale = Localizations.localeOf(context);
    final shouldShowConnectBankButton = _isPlaidSupportedTimezone(
      preferredTimezone,
    );

    // Spotlight keys for the wallets feature tour
    final netWorthSpotlightKey = useMemoized(() => GlobalKey(), []);
    final walletStackSpotlightKey = useMemoized(() => GlobalKey(), []);
    final newWalletSpotlightKey = useMemoized(() => GlobalKey(), []);

    // Wallets feature spotlight tour controller
    final walletsTourController = useMemoized(
      () => SpotlightTourController(
        tourId: 'wallets_feature_v1',
        steps: [
          SpotlightStep(
            id: 'wallets_net_worth',
            targetKey: netWorthSpotlightKey,
            title: context.l10n.walletsNetWorthTourTitle,
            description: context.l10n.walletsNetWorthTourDescription,
            placement: SpotlightPlacement.bottom,
            padding: 12,
            borderRadius: 24,
          ),
          SpotlightStep(
            id: 'wallets_stack',
            targetKey: walletStackSpotlightKey,
            title: context.l10n.walletsStackTourTitle,
            description: context.l10n.walletsStackTourDescription,
            placement: SpotlightPlacement.top,
            padding: 8,
            borderRadius: 24,
          ),
          SpotlightStep(
            id: 'wallets_new_wallet',
            targetKey: newWalletSpotlightKey,
            title: context.l10n.walletsNewWalletTourTitle,
            description: context.l10n.walletsNewWalletTourDescription,
            placement: SpotlightPlacement.top,
            padding: 8,
            borderRadius: 12,
          ),
        ],
      ),
      [locale],
    );

    // Start wallets spotlight tour when on wallets tab and data is loaded
    if (currentTabIndex == 3 &&
        !walletsAsync.isLoading &&
        !walletsAsync.hasError &&
        auth.uid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        walletsTourController.start(context);
      });
    }

    if (selectedMonthIndexState.value > maxMonthIndex) {
      selectedMonthIndexState.value = maxMonthIndex;
    }

    useEffect(() {
      if (availableMonths.isEmpty || auth.uid.isEmpty) {
        return null;
      }

      final selectedIndex =
          selectedMonthIndexState.value.clamp(0, availableMonths.length - 1);
      final prefetchQueries = <WalletsMonthQuery>{
        WalletsMonthQuery(
          scope: scopeQuery,
          monthStart: availableMonths[selectedIndex],
        ),
      };

      if (selectedIndex > 0) {
        prefetchQueries.add(
          WalletsMonthQuery(
            scope: scopeQuery,
            monthStart: availableMonths[selectedIndex - 1],
          ),
        );
      }
      if (selectedIndex < availableMonths.length - 1) {
        prefetchQueries.add(
          WalletsMonthQuery(
            scope: scopeQuery,
            monthStart: availableMonths[selectedIndex + 1],
          ),
        );
      }

      for (final query in prefetchQueries) {
        unawaited(ref.read(walletsMonthSnapshotProvider(query).future));
      }
      return null;
    }, [scopeQuery, availableMonths, selectedMonthIndexState.value, auth.uid]);

    Future<void> onAddAccount() async {
      final result = await showCreateEditWalletSheet(context);
      if (result == null) return;
      try {
        await actions.createAccount(
          name: result.name,
          icon: result.icon,
          color: result.color,
          openingBalanceCents: result.openingBalanceCents,
          goalAmountCents: result.goalAmountCents,
          isDefault: result.isDefault,
        );
        if (context.mounted) {
          AppToast.success(context, context.l10n.save);
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
          ? const Padding(
              padding: EdgeInsets.all(0),
              child: HomeAiExpandableFab(),
            )
          : null,
      body: SafeArea(
        child: walletsAsync.when(
          loading: () => const _WalletsPageSkeleton(),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString()),
            ),
          ),
          data: (_) {
            final wallets = effectiveWallets;
            // Show skeleton if wallets are empty but still loading
            if (wallets.isEmpty &&
                (walletsAsync.isLoading || !walletsAsync.hasValue)) {
              return const _WalletsPageSkeleton();
            }
            final selectedMonthIndex =
                selectedMonthIndexState.value.clamp(0, maxMonthIndex).toInt();
            final selectedMonth = availableMonths[selectedMonthIndex];
            final selectedMonthQuery = WalletsMonthQuery(
              scope: scopeQuery,
              monthStart: selectedMonth,
            );
            // CRITICAL: the selected month card must use the recurring-aware
            // month snapshot.
            // STRICT REQUIREMENT: replacing this with a raw non-recurring
            // snapshot makes the month carousel under-report wallet spend and
            // balance whenever recurring transactions are scheduled.
            final selectedSnapshotAsync =
                ref.watch(walletsMonthSnapshotProvider(selectedMonthQuery));
            final selectedSnapshot = selectedSnapshotAsync.valueOrNull != null
                ? _accountsSnapshotFromMonthSnapshot(
                    selectedSnapshotAsync.valueOrNull!,
                  )
                : _buildOpeningSnapshot(wallets);

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  SizedBox(
                    height: (!hasDismissedSwipeHintState.value &&
                            availableMonths.length > 1)
                        ? 290
                        : 260,
                    child: PageView.builder(
                      itemCount: availableMonths.length,
                      controller: monthPageController,
                      reverse: true,
                      onPageChanged: (index) {
                        selectedMonthIndexState.value = index;
                        if (hasDismissedSwipeHintState.value) {
                          return;
                        }
                        hasDismissedSwipeHintState.value = true;
                        unawaited(prefs.setBool(swipeHintPrefKey, true));
                      },
                      itemBuilder: (context, index) {
                        final isActive = selectedMonthIndexState.value == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            key: isActive ? netWorthSpotlightKey : null,
                            child: _WalletsOverviewCard(
                              availableMonths: availableMonths,
                              selectedMonthIndex: index,
                              isActive: isActive,
                              scopeQuery: scopeQuery,
                              history: historyAsync.valueOrNull,
                              currencyCode: selectedCurrencyCode,
                              hasDismissedSwipeHint:
                                  hasDismissedSwipeHintState.value,
                              activeSnapshot: selectedSnapshot,
                              activeMonthIndex: selectedMonthIndexState.value,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (wallets.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.sheetBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.border),
                      ),
                      child: Text(
                        context.l10n.noWalletsYet,
                        style: TextStyle(
                          color: colorScheme.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    Container(
                      key: walletStackSpotlightKey,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24, top: 12),
                        child: _WalletAccountStack(
                          wallets: wallets,
                          currencyCode: selectedCurrencyCode,
                          walletBalances: selectedSnapshot.walletBalances,
                        ),
                      ),
                    ),
                  Container(
                    key: newWalletSpotlightKey,
                    child: TextButton.icon(
                      onPressed: onAddAccount,
                      icon: Icon(Icons.add, color: colorScheme.primary),
                      label: Text(
                        context.l10n.newWallet,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (shouldShowConnectBankButton)
                    TextButton.icon(
                      onPressed: () =>
                          AppToast.info(context, context.l10n.comingSoon),
                      icon: Icon(
                        Icons.sync,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      label: Text(
                        context.l10n.connectBank,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ));
  }
}

bool _isPlaidSupportedTimezone(String? preferredTimezone) {
  final normalized =
      canonicalTimezoneValue(preferredTimezone)?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }

  if (normalized.startsWith('us/')) {
    return true;
  }

  const supportedPlaidIanaTimezones = <String>{
    'america/new_york',
    'america/detroit',
    'america/kentucky/louisville',
    'america/kentucky/monticello',
    'america/indiana/indianapolis',
    'america/indiana/vincennes',
    'america/indiana/winamac',
    'america/indiana/marengo',
    'america/indiana/petersburg',
    'america/indiana/vevay',
    'america/chicago',
    'america/indiana/tell_city',
    'america/indiana/knox',
    'america/menominee',
    'america/north_dakota/center',
    'america/north_dakota/new_salem',
    'america/north_dakota/beulah',
    'america/denver',
    'america/boise',
    'america/phoenix',
    'america/los_angeles',
    'america/anchorage',
    'america/juneau',
    'america/sitka',
    'america/metlakatla',
    'america/yakutat',
    'america/nome',
    'america/adak',
    'pacific/honolulu',
    'america/st_johns',
    'america/halifax',
    'america/glace_bay',
    'america/moncton',
    'america/goose_bay',
    'america/toronto',
    'america/iqaluit',
    'america/winnipeg',
    'america/rankin_inlet',
    'america/resolute',
    'america/regina',
    'america/swift_current',
    'america/edmonton',
    'america/cambridge_bay',
    'america/inuvik',
    'america/creston',
    'america/dawson_creek',
    'america/fort_nelson',
    'america/vancouver',
    'america/whitehorse',
    'america/dawson',
  };

  return supportedPlaidIanaTimezones.contains(normalized);
}

class _AnimatedNumberText extends StatelessWidget {
  final double value;
  final String symbol;
  final TextStyle style;

  const _AnimatedNumberText({
    required this.value,
    required this.symbol,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Text(
          '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(val)))}',
          style: style,
        );
      },
    );
  }
}

class _WalletsOverviewCard extends HookConsumerWidget {
  final List<DateTime> availableMonths;
  final int selectedMonthIndex;
  final bool isActive;
  final WalletsScopeQuery scopeQuery;
  final WalletsHistorySummary? history;
  final String currencyCode;
  final bool hasDismissedSwipeHint;
  final _AccountsSnapshot activeSnapshot;
  final int activeMonthIndex;

  const _WalletsOverviewCard({
    required this.availableMonths,
    required this.selectedMonthIndex,
    required this.isActive,
    required this.scopeQuery,
    required this.history,
    required this.currencyCode,
    required this.hasDismissedSwipeHint,
    required this.activeSnapshot,
    required this.activeMonthIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final monthLabel = MaterialLocalizations.of(context)
        .formatMonthYear(availableMonths[selectedMonthIndex]);

    final targetMonthIndex = isActive ? selectedMonthIndex : activeMonthIndex;
    final monthQuery = WalletsMonthQuery(
      scope: scopeQuery,
      monthStart: availableMonths[selectedMonthIndex],
    );
    final snapshotAsync = ref.watch(walletsMonthSnapshotProvider(monthQuery));
    final selectedSnapshot = snapshotAsync.valueOrNull != null
        ? _accountsSnapshotFromMonthSnapshot(snapshotAsync.valueOrNull!)
        : activeSnapshot;

    final spots = useMemoized(() {
      final timeAscendingMonths = availableMonths.reversed.toList();
      final pointByMonth = <DateTime, int>{
        for (final point
            in history?.netWorthSeries ?? const <WalletNetWorthPoint>[])
          DateTime(point.monthStart.year, point.monthStart.month):
              point.netWorthCents,
      };
      final newSpots = <FlSpot>[];
      final currentListSize = timeAscendingMonths.length - targetMonthIndex;
      for (int i = 0; i < currentListSize; i++) {
        final monthKey = DateTime(
          timeAscendingMonths[i].year,
          timeAscendingMonths[i].month,
        );
        final netWorthCents = pointByMonth[monthKey] ?? 0;
        newSpots.add(FlSpot(i.toDouble(), netWorthCents / 100.0));
      }
      return newSpots;
    }, [availableMonths, history, targetMonthIndex]);

    final timeAscendingMonthsSize = availableMonths.length;
    final highlightX =
        (timeAscendingMonthsSize - 1 - targetMonthIndex).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.pocketHeaderBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.pocketHeaderShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.totalNetWorth,
                    style: TextStyle(
                      color: colorScheme.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(monthLabel),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    monthLabel,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _AnimatedNumberText(
              value: isActive
                  ? selectedSnapshot.netWorth
                  : activeSnapshot.netWorth,
              symbol: symbol,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: colorScheme.foreground,
                letterSpacing: -1.0,
                height: 1.1,
              ),
            ),
          ),
          if (timeAscendingMonthsSize > 1) const SizedBox(height: 16),
          if (timeAscendingMonthsSize > 1)
            SizedBox(
              height: 60,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, animationValue, child) {
                  // Interpolate spots from 0 to actual values
                  final animatedSpots = spots.map((spot) {
                    return FlSpot(
                      spot.x,
                      spot.y * animationValue,
                    );
                  }).toList();

                  return LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (timeAscendingMonthsSize - 1).toDouble(),
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) =>
                              colorScheme.surfaceContainerHighest,
                          tooltipRoundedRadius: 12,
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          tooltipBorder: BorderSide(
                              color: colorScheme.border.withValues(alpha: 0.5)),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(spot.y)))}',
                                TextStyle(
                                  color: colorScheme.foreground,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: -0.3,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: animatedSpots,
                          isCurved: true,
                          color: colorScheme.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) {
                              return spot.x.toInt() == highlightX.toInt();
                            },
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 5,
                                color: colorScheme.cardSurface,
                                strokeWidth: 3,
                                strokeColor: colorScheme.primary,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary
                                    .withValues(alpha: 0.3 * animationValue),
                                colorScheme.primary.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.totalIncome,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _AnimatedNumberText(
                      value: isActive
                          ? selectedSnapshot.totalIncome
                          : activeSnapshot.totalIncome,
                      symbol: symbol,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.totalSpent,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _AnimatedNumberText(
                      value: isActive
                          ? selectedSnapshot.totalSpent
                          : activeSnapshot.totalSpent,
                      symbol: symbol,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!hasDismissedSwipeHint && availableMonths.length > 1) ...[
            const Spacer(),
            SwipeHintRow(text: context.l10n.swipeRightPreviousMonths),
          ],
        ],
      ),
    );
  }
}

class _WalletAccountStack extends HookConsumerWidget {
  final List<WalletEntity> wallets;
  final String currencyCode;
  final Map<String, int> walletBalances;

  const _WalletAccountStack({
    required this.wallets,
    required this.currencyCode,
    required this.walletBalances,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(sharedPreferencesProvider);
    const orderKey = 'wallet_accounts_order';

    final orderedAccountsState = useState<List<WalletEntity>>([...wallets]);
    final draggedAccountIdState = useState<String?>(null);
    final selectedAccountIdState = useState<String?>(null);

    // Sync from props/prefs
    useEffect(() {
      final savedOrder = prefs.getStringList(orderKey) ?? [];
      final list = [...wallets];
      list.sort((a, b) {
        final indexA = savedOrder.indexOf(a.id);
        final indexB = savedOrder.indexOf(b.id);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return 0; // maintain original order for new items
      });
      orderedAccountsState.value = list;

      if (selectedAccountIdState.value == null && list.isNotEmpty) {
        selectedAccountIdState.value = list.last.id;
      }
      return null;
    }, [wallets]);

    final orderedAccounts = orderedAccountsState.value;
    final selectedId = selectedAccountIdState.value;

    const tightSpacing = 70.0;
    const expandedCardHeight = 240.0;
    const unselectedCardHeight = 130.0;

    const gap = 20.0;

    const bottomBuffer = 0.0;
    final stackHeight = orderedAccounts.isEmpty
        ? 0.0
        : (orderedAccounts.length == 1)
            ? expandedCardHeight + bottomBuffer
            : (expandedCardHeight +
                gap +
                (orderedAccounts.length - 2) * tightSpacing +
                unselectedCardHeight +
                bottomBuffer);

    double getTop(int index, WalletEntity wallet) {
      if (wallet.id == selectedId) return 0.0;

      final selectedIdx = orderedAccounts.indexWhere((a) => a.id == selectedId);
      final positionInOthers = index < selectedIdx ? index : index - 1;

      return expandedCardHeight + gap + (positionInOthers * tightSpacing);
    }

    final renderAccounts = [...orderedAccounts];
    if (draggedAccountIdState.value != null) {
      final draggedAcc =
          renderAccounts.firstWhere((a) => a.id == draggedAccountIdState.value);
      renderAccounts.remove(draggedAcc);
      renderAccounts.add(draggedAcc);
    } else if (selectedId != null) {
      final selected = renderAccounts.where((a) => a.id == selectedId).toList();
      if (selected.isNotEmpty) {
        renderAccounts.remove(selected.first);
        renderAccounts.add(selected.first);
      }
    }

    return GestureDetector(
      onTap: () {
        // Background tap - could optionally collapse but following "one always expanded"
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
        height: stackHeight,
        color: colorScheme.surface.withValues(alpha: 0.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: renderAccounts.map((wallet) {
            final originalIndex = orderedAccounts.indexOf(wallet);
            final isExpanded = selectedId == wallet.id;
            final isDragging = draggedAccountIdState.value == wallet.id;

            return AnimatedPositioned(
              key: ValueKey(wallet.id),
              top: getTop(originalIndex, wallet),
              left: 0,
              right: 0,
              height: isExpanded ? expandedCardHeight : unselectedCardHeight,
              duration: isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: Curves.easeOutQuart,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (details) {
                  // Re-enable reordering logic if needed, but for now focus on Apple UI
                },
                onTap: () {},
                onTapUp: (details) {
                  if (wallet.id != selectedId) {
                    selectedAccountIdState.value = wallet.id;
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WalletDetailsPage(
                          wallet: wallet,
                        ),
                      ),
                    );
                  }
                },
                child: _WalletStackCard(
                  wallet: wallet,
                  currencyCode: currencyCode,
                  displayBalanceCents:
                      walletBalances[wallet.id] ?? wallet.currentBalanceCents,
                  isExpanded: isExpanded,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _WalletStackCard extends StatelessWidget {
  const _WalletStackCard({
    required this.wallet,
    required this.currencyCode,
    required this.displayBalanceCents,
    required this.isExpanded,
  });

  final WalletEntity wallet;
  final String currencyCode;
  final int displayBalanceCents;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final amount = displayBalanceCents / 100.0;
    final isNegative = amount < 0;

    final goal = (wallet.goalAmountCents ?? 0) / 100.0;
    final currentProgressAmount = amount < 0 ? 0.0 : amount;

    double progress = 0.0;
    if (goal > 0) {
      progress = (currentProgressAmount / goal).clamp(0.0, 1.0);
    } else if (goal == 0) {
      progress = 1.0;
    }

    final walletColorRaw = wallet.color.toUpperCase() == '#6B7280'
        ? colorScheme.primary
        : parseWalletColor(wallet.color, colorScheme.primary);
    final baseColor = AppTheme.tunedPocketBaseColor(
      walletColorRaw,
      colorScheme,
      hasCustomColor: wallet.color.toUpperCase() != '#6B7280',
    );

    final backgroundTint = colorScheme.pocketTileFill(baseColor);
    final opaqueBackground =
        Color.alphaBlend(backgroundTint, colorScheme.surface);

    final collapsedHeader = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Icon(
            resolveWalletIcon(wallet.icon),
            color: baseColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (wallet.isDefault) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: baseColor.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${isNegative ? '-' : ''}$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
          style: TextStyle(
            color:
                isNegative ? colorScheme.destructive : colorScheme.foreground,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );

    final expandedHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                wallet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (wallet.isDefault)
              Container(
                height: 36,
                padding: const EdgeInsets.only(left: 4, right: 12),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: baseColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: baseColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        resolveWalletIcon(wallet.icon),
                        color: baseColor,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.primary,
                      style: TextStyle(
                        color: baseColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resolveWalletIcon(wallet.icon),
                  color: baseColor,
                  size: 18,
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.balance,
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isNegative ? '-' : ''}$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
                  style: TextStyle(
                    color: isNegative
                        ? colorScheme.destructive
                        : colorScheme.foreground,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return PhysicalShape(
      clipper: _OrganicAccountTileClipper(),
      color: opaqueBackground,
      elevation: isExpanded ? 8.0 : 4.0,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.5),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: collapsedHeader,
              secondChild: expandedHeader,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isExpanded ? 1.0 : 0.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(currentProgressAmount)))}',
                        style: TextStyle(
                          color: colorScheme.mutedForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(goal)))}',
                        style: TextStyle(
                          color: colorScheme.mutedForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress,
                      backgroundColor: baseColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.tapToViewDetails,
                    style: TextStyle(
                      color: colorScheme.mutedForeground.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _walletsMonthSwipeHintDismissedKey(String userId) {
  return 'accounts_month_swipe_hint_dismissed:$userId';
}

_AccountsSnapshot _buildOpeningSnapshot(List<WalletEntity> wallets) {
  final walletBalances = <String, int>{
    for (final wallet in wallets) wallet.id: wallet.openingBalanceCents,
  };
  var netWorthCents = 0;
  for (final value in walletBalances.values) {
    netWorthCents += value;
  }
  return _AccountsSnapshot(
    totalIncome: 0,
    totalSpent: 0,
    netWorth: netWorthCents / 100.0,
    walletBalances: walletBalances,
  );
}

_AccountsSnapshot _accountsSnapshotFromMonthSnapshot(
  WalletsMonthSnapshot snapshot,
) {
  return _AccountsSnapshot(
    totalIncome: snapshot.incomeTotalCents / 100.0,
    totalSpent: snapshot.spentTotalCents / 100.0,
    netWorth: snapshot.netWorthCents / 100.0,
    walletBalances: snapshot.walletBalances,
  );
}

String? _resolveWalletsScopeHouseholdId(HouseholdScope scope) {
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return null;
    case ActiveWalletType.portfolio:
      return scope.activeAccountHouseholdId;
    case ActiveWalletType.household:
      return scope.selectedHouseholdId;
  }
}

class _AccountsSnapshot {
  const _AccountsSnapshot({
    required this.totalIncome,
    required this.totalSpent,
    required this.netWorth,
    required this.walletBalances,
  });

  final double totalIncome;
  final double totalSpent;
  final double netWorth;
  final Map<String, int> walletBalances;
}

class _OrganicAccountTileClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const radius = 24.0;
    const dipDepth = 16.0;
    final path = Path();

    final double holeCenter = size.width * 0.50;
    final double holeHalfWidth = size.width * 0.13;
    final double flatBottomHalfWidth = size.width * 0.02;

    final double startX = holeCenter - holeHalfWidth;
    final double flatStartX = holeCenter - flatBottomHalfWidth;
    final double flatEndX = holeCenter + flatBottomHalfWidth;
    final double endX = holeCenter + holeHalfWidth;

    final double curveWidth = flatStartX - startX;
    final double cpOffset = curveWidth * 0.45;

    path.moveTo(radius, 0);
    path.lineTo(startX, 0);

    path.cubicTo(
      startX + cpOffset,
      0,
      flatStartX - cpOffset,
      dipDepth,
      flatStartX,
      dipDepth,
    );

    path.lineTo(flatEndX, dipDepth);

    path.cubicTo(
      flatEndX + cpOffset,
      dipDepth,
      endX - cpOffset,
      0,
      endX,
      0,
    );

    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(
        size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _WalletsPageSkeleton extends StatelessWidget {
  const _WalletsPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Skeletonizer(
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Skeleton for _WalletsOverviewCard
          Container(
            width: double.infinity,
            height: 260,
            decoration: BoxDecoration(
              color: colorScheme.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.pocketHeaderBorder,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with title and month chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Bone.text(words: 2, fontSize: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Bone.text(words: 1, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Large amount
                Bone.text(words: 1, fontSize: 36),
                const SizedBox(height: 16),
                // Chart placeholder
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Income/Spent row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone.text(words: 1, fontSize: 12),
                          const SizedBox(height: 4),
                          Bone.text(words: 1, fontSize: 16),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone.text(words: 1, fontSize: 12),
                          const SizedBox(height: 4),
                          Bone.text(words: 1, fontSize: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Skeleton for wallet stack - 3 skeleton cards
          Container(
            height: 400,
            child: Stack(
              children: [
                // Skeleton card 1 (bottom)
                Positioned(
                  top: 150,
                  left: 0,
                  right: 0,
                  height: 130,
                  child: _SkeletonWalletCard(colorScheme: colorScheme),
                ),
                // Skeleton card 2 (middle)
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  height: 130,
                  child: _SkeletonWalletCard(colorScheme: colorScheme),
                ),
                // Skeleton card 3 (top, expanded)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 240,
                  child: _SkeletonWalletCard(
                    colorScheme: colorScheme,
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Skeleton buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Bone.icon(size: 20),
              const SizedBox(width: 8),
              Bone.text(words: 2, fontSize: 14),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Bone.icon(size: 20),
              const SizedBox(width: 8),
              Bone.text(words: 2, fontSize: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonWalletCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isExpanded;

  const _SkeletonWalletCard({
    required this.colorScheme,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.border.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: isExpanded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet name
                Bone.text(words: 2, fontSize: 18),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon circle
                    Bone.circle(size: 36),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Balance label
                        Bone.text(words: 1, fontSize: 10),
                        const SizedBox(height: 4),
                        // Balance amount
                        Bone.text(words: 1, fontSize: 24),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                // Progress bar placeholder
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 24),
                // Tap hint
                Center(
                  child: Bone.text(words: 3, fontSize: 12),
                ),
              ],
            )
          : Row(
              children: [
                // Icon circle
                Bone.circle(size: 36),
                const SizedBox(width: 12),
                // Wallet name
                Expanded(
                  child: Bone.text(words: 2, fontSize: 16),
                ),
                const SizedBox(width: 12),
                // Amount
                Bone.text(words: 1, fontSize: 20),
              ],
            ),
    );
  }
}
