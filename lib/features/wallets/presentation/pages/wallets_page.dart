import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/plaid/pages/plaid_sync_walkthrough_page.dart';
import 'package:moneko/core/plaid/plaid_countries.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/subscription/plan_access.dart'
    show hasPremiumFeatureAccess;
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_debug_tracing.dart';
import 'package:moneko/features/wallets/presentation/pages/wallet_details_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transaction_binding.dart';
import 'package:moneko/features/wallets/presentation/widgets/add_wallet_option_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_stack_card.dart';
import 'package:moneko/features/home/presentation/state/bank_accounts_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
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
    final previewSelectedMonthState = useState<DateTime?>(null);
    final monthPageController = usePageController(viewportFraction: 0.96);
    final colorScheme = Theme.of(context).colorScheme;
    final isPreviewMode = ref.watch(previewModeProvider).isActive;
    final actions = ref.watch(walletActionsProvider);
    final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
    final auth = ref.watch(authProvider);
    final walletAuthHeaders = ref.watch(walletAuthHeadersProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final pageTraceRef = useRef<WalletsDebugTrace?>(null);
    pageTraceRef.value ??= WalletsDebugTrace(
      label: 'WalletsPageOpen',
      enabled: ref.read(walletsDebugLoggingEnabledProvider),
      logSink: ref.read(walletsDebugLogSinkProvider),
      contextFields: {
        'user': auth.uid.isEmpty ? '<empty>' : auth.uid,
      },
    );
    final pageTrace = pageTraceRef.value!;

    useEffect(() {
      pageTrace.mark('page-mounted');
      return null;
    }, const []);

    useEffect(() {
      pageTrace.mark('auth-state', {
        'hasUser': auth.uid.isNotEmpty,
        'hasWalletAuthHeaders': walletAuthHeaders != null,
      });
      return null;
    }, [auth.uid, walletAuthHeaders != null]);

    if (!isPreviewMode && auth.uid.isEmpty) {
      pageTrace.mark('page-blocked-before-wallet-load', {
        'reason': 'empty-user',
      });
      return const StatusBarOverlayRegion(
        child: AdaptiveScaffold(
          body: SafeArea(
            child: _WalletsPageSkeleton(),
          ),
        ),
      );
    }

    if (!isPreviewMode && walletAuthHeaders == null) {
      pageTrace.mark('page-blocked-before-wallet-load', {
        'reason': 'missing-auth-headers',
      });
      return const StatusBarOverlayRegion(
        child: AdaptiveScaffold(
          body: SafeArea(
            child: _WalletsPageSkeleton(),
          ),
        ),
      );
    }

    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
    final householdScope = ref.watch(householdScopeProvider);
    // CRITICAL: wallet history/month snapshots must anchor to the user's month.
    // STRICT REQUIREMENT: do not replace this with DateTime.now(), or
    // recurring transactions near month boundaries can land in the wrong month
    // and wallets drift away from pockets/details again.
    final effectiveNowForUser =
        effectiveNow(preferredTimezone: preferredTimezone);
    // CRITICAL: the wallets landing page must stay wired to recurring-aware
    // month history and month snapshot providers.
    // STRICT REQUIREMENT: if this page switches back to non-recurring month
    // data, recurring bills disappear from the main wallets cards even while
    // details and pockets still project them.
    final scopeQuery = ref.watch(walletsScopeQueryProvider);

    final previewWalletsData = isPreviewMode
        ? _buildPreviewWalletsPageData(
            selectedCurrencyCode: selectedCurrencyCode,
            effectiveNow: effectiveNowForUser,
            financialMonthStartDay: scopeQuery.financialMonthStartDay,
          )
        : null;
    final AsyncValue<List<WalletEntity>> walletsAsync = isPreviewMode
        ? AsyncValue.data(previewWalletsData!.wallets)
        : ref.watch(scopedWalletsProvider);
    final effectiveWallets = isPreviewMode
        ? previewWalletsData!.wallets
        : ref.watch(effectiveScopeWalletsProvider);
    final walletsPageStateAsync =
        isPreviewMode ? null : ref.watch(walletsPageStateProvider(scopeQuery));

    Future<void> onRefresh() async {
      if (isPreviewMode) {
        return;
      }

      await Future.wait([
        ref.read(scopedWalletsProvider.notifier).refreshFromNetwork(),
        ref.read(walletsPageStateProvider(scopeQuery).notifier).refresh(),
      ]);
    }

    final walletsPageState = walletsPageStateAsync?.valueOrNull;
    final availableMonths = isPreviewMode
        ? previewWalletsData!.history.availableMonths
        : walletsPageState?.visibleMonths ??
            <DateTime>[scopeQuery.currentMonthStart];
    final activeCarouselMonth = isPreviewMode
        ? (previewSelectedMonthState.value ?? availableMonths.first)
        : walletsPageState?.selectedMonthStart ?? availableMonths.first;
    final activeCarouselMonthIndex =
        availableMonths.indexOf(activeCarouselMonth);
    final selectedMonthIndex =
        activeCarouselMonthIndex >= 0 ? activeCarouselMonthIndex : 0;
    final swipeHintPrefKey = _walletsMonthSwipeHintDismissedKey(auth.uid);
    final hasDismissedSwipeHintState =
        useState<bool>(prefs.getBool(swipeHintPrefKey) ?? false);
    final currentTabIndex = ref.watch(mainShellTabIndexProvider);
    final locale = Localizations.localeOf(context);
    final shouldShowConnectBankButton = isPlaidSupportedTimezone(
      preferredTimezone,
    );
    final bankConnectionsAsync = isPreviewMode
        ? const AsyncValue<List<BankConnection>>.data(<BankConnection>[])
        : ref.watch(bankConnectionsProvider);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!monthPageController.hasClients ||
            selectedMonthIndex >= availableMonths.length) {
          return;
        }
        final currentPage = monthPageController.page?.round() ??
            monthPageController.initialPage;
        if (currentPage != selectedMonthIndex) {
          monthPageController.jumpToPage(selectedMonthIndex);
        }
      });
      return null;
    }, [selectedMonthIndex, availableMonths.length]);

    useEffect(() {
      pageTrace.mark('wallets-async-state', {
        'loading': walletsAsync.isLoading,
        'hasValue': walletsAsync.hasValue,
        'hasError': walletsAsync.hasError,
        'error': walletsAsync.hasError ? walletsAsync.error : null,
        'walletCount': walletsAsync.valueOrNull?.length,
      });
      return null;
    }, [
      walletsAsync.isLoading,
      walletsAsync.hasValue,
      walletsAsync.hasError,
      walletsAsync.valueOrNull?.length,
    ]);

    useEffect(() {
      pageTrace.mark('wallets-page-state-async', {
        'enabled': !isPreviewMode,
        'loading': walletsPageStateAsync?.isLoading ?? false,
        'hasValue': walletsPageStateAsync?.hasValue ?? false,
        'hasError': walletsPageStateAsync?.hasError ?? false,
        'error': walletsPageStateAsync?.hasError == true
            ? walletsPageStateAsync?.error
            : null,
        'visibleMonths':
            walletsPageStateAsync?.valueOrNull?.visibleMonths.length,
      });
      return null;
    }, [
      isPreviewMode,
      walletsPageStateAsync?.isLoading ?? false,
      walletsPageStateAsync?.hasValue ?? false,
      walletsPageStateAsync?.hasError ?? false,
      walletsPageStateAsync?.valueOrNull?.visibleMonths.length,
    ]);

    useEffect(() {
      pageTrace.mark('bank-connections-async-state', {
        'loading': bankConnectionsAsync.isLoading,
        'hasValue': bankConnectionsAsync.hasValue,
        'hasError': bankConnectionsAsync.hasError,
        'error':
            bankConnectionsAsync.hasError ? bankConnectionsAsync.error : null,
        'count': bankConnectionsAsync.valueOrNull?.length,
      });
      return null;
    }, [
      bankConnectionsAsync.isLoading,
      bankConnectionsAsync.hasValue,
      bankConnectionsAsync.hasError,
      bankConnectionsAsync.valueOrNull?.length,
    ]);
    final plaidConnections =
        (bankConnectionsAsync.valueOrNull ?? const <BankConnection>[])
            .where(
              (connection) =>
                  connection.provider?.toLowerCase().trim() == 'plaid',
            )
            .toList(growable: false);
    final scopedPlaidConnections = plaidConnections
        .where(
          (connection) =>
              _isConnectionInWalletsScope(connection, householdScope),
        )
        .toList(growable: false);
    final hasPendingPlaidRemoval = scopedPlaidConnections.any(
      (connection) => connection.isPendingRemoval,
    );
    Future<void> refreshWalletsAfterPlaidFlow() async {
      ref.invalidate(bankConnectionsProvider);
      ref.invalidate(bankAccountsProvider);
      await Future.wait([
        ref.read(scopedWalletsProvider.notifier).refreshFromNetwork(),
        ref.read(walletsPageStateProvider(scopeQuery).notifier).refresh(),
      ]);
    }

    final readyForUsefulPaint =
        walletsAsync.hasValue || isPreviewMode || walletsPageState != null;
    final didLogUsefulPaintRef = useRef<bool>(false);

    useEffect(() {
      if (!readyForUsefulPaint || didLogUsefulPaintRef.value) {
        return null;
      }
      didLogUsefulPaintRef.value = true;
      pageTrace.mark('first-useful-paint', {
        'hasOverview': isPreviewMode || walletsPageState != null,
        'hasWallets': walletsAsync.hasValue,
        'walletCount': effectiveWallets.length,
        'visibleMonths': walletsPageState?.visibleMonths.length ?? 0,
        'selectedMonth': walletsPageState?.selectedMonthStart,
      });
      return null;
    }, [
      readyForUsefulPaint,
      isPreviewMode || walletsPageState != null,
      walletsAsync.hasValue,
      effectiveWallets.length,
      walletsPageState?.visibleMonths.length,
      walletsPageState?.selectedMonthStart,
    ]);

    useEffect(() {
      final targetIndex = availableMonths.indexOf(activeCarouselMonth);
      if (targetIndex < 0) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!monthPageController.hasClients) {
          return;
        }
        final currentPage = monthPageController.page?.round() ?? 0;
        if (currentPage == targetIndex) {
          return;
        }
        monthPageController.jumpToPage(targetIndex);
      });

      return null;
    }, [availableMonths, activeCarouselMonth, monthPageController]);

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

    Future<bool> canUsePlusFeatures() async {
      if (subscriptionAsync.hasValue) {
        return hasPremiumFeatureAccess(subscriptionAsync.valueOrNull);
      }
      try {
        final subscription =
            await ref.read(subscriptionNotifierProvider.future);
        return hasPremiumFeatureAccess(subscription);
      } catch (_) {
        // Do not downgrade an unknown entitlement state to free. The backend
        // remains authoritative and limit failures are handled below.
        return true;
      }
    }

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

    Future<void> onCreateManualAccount() async {
      if (isPreviewMode) {
        AppToast.info(context, context.l10n.previewMockUpdatesApplied);
        return;
      }

      final activeWalletCount =
          effectiveWallets.where((wallet) => !wallet.isArchived).length;
      final hasPlusAccess = await canUsePlusFeatures();
      if (!context.mounted) return;
      if (!hasPlusAccess && activeWalletCount >= 2) {
        await PlusLockedSheet.show(
          context,
          highlightedFeature: PlusFeature.walletCreation,
        );
        return;
      }

      final result = await showCreateEditWalletSheet(context);
      if (result == null) return;
      try {
        await actions.createAccount(
          name: result.name,
          icon: result.icon,
          color: result.color,
          logoUrl: result.logoUrl,
          currency: result.currency,
          openingBalanceCents: result.openingBalanceCents,
          goalAmountCents: result.goalAmountCents,
          isDefault: result.isDefault,
          excludeFromAnalytics: result.excludeFromAnalytics,
        );
        if (context.mounted) {
          AppToast.success(context, context.l10n.save);
        }
      } catch (error) {
        if (context.mounted) {
          if (ErrorHandler.isPlusFeatureLimitError(error)) {
            await PlusLockedSheet.show(
              context,
              highlightedFeature: PlusFeature.walletCreation,
            );
            return;
          }
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> onConnectBankAccount() async {
      final hasPlusAccess = await canUsePlusFeatures();
      if (!context.mounted) return;
      if (!hasPlusAccess) {
        await PlusLockedSheet.show(
          context,
          highlightedFeature: PlusFeature.bankSync,
        );
        return;
      }
      if (isPreviewMode) {
        AppToast.info(
          context,
          context.l10n.previewMockUpdatesApplied,
        );
        return;
      }

      if (hasPendingPlaidRemoval) {
        await MonekoAlertDialog.show(
            context: context,
            title: context.l10n.disconnectPending,
            description: context.l10n.bankStillFinishingDisconnect,
            confirmLabel: context.l10n.gotIt,
            showCancelButton: false);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaidSyncWalkthroughPage(
            targetHouseholdId: _resolveWalletsScopeHouseholdId(
              householdScope,
            ),
          ),
        ),
      );
      if (!context.mounted) {
        return;
      }
      await refreshWalletsAfterPlaidFlow();
    }

    Future<void> onAddAccount() async {
      final selectedOption = await showAddWalletOptionSheet(
        context,
        showBankConnectionOption: shouldShowConnectBankButton,
      );
      if (selectedOption == null || !context.mounted) {
        return;
      }

      switch (selectedOption) {
        case AddWalletOption.manual:
          await onCreateManualAccount();
          break;
        case AddWalletOption.bank:
          await onConnectBankAccount();
          break;
      }
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Builder(builder: (context) {
              final wallets = effectiveWallets;
              final hasWalletsContent =
                  walletsAsync.hasValue || wallets.isNotEmpty;
              final hasOverviewContent =
                  isPreviewMode || walletsPageState != null;

              if (!hasWalletsContent && !hasOverviewContent) {
                final walletsError = walletsAsync.error;
                final pageError = walletsPageStateAsync?.error;
                if (walletsError != null || pageError != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text((walletsError ?? pageError).toString()),
                    ),
                  );
                }
                return const _WalletsPageSkeleton();
              }

              final selectedMonth = activeCarouselMonth;
              final currencyRates =
                  ref.watch(currencyRateTableProvider).valueOrNull ??
                      const CurrencyRateTable(
                        baseCurrency: 'USD',
                        rates: CurrencyRates.rates,
                        isStale: true,
                      );
              _AccountsSnapshot accountsSnapshotForMonth(
                WalletsMonthSnapshot snapshot,
              ) {
                final isCurrentMonth = _normalizeWalletMonth(
                      snapshot.monthStart,
                      financialMonthStartDay: scopeQuery.financialMonthStartDay,
                    ) ==
                    _normalizeWalletMonth(
                      scopeQuery.currentMonthStart,
                      financialMonthStartDay: scopeQuery.financialMonthStartDay,
                    );
                if (!isPreviewMode && isCurrentMonth && wallets.isNotEmpty) {
                  return _accountsSnapshotFromCurrentWalletBalances(
                    snapshot,
                    wallets,
                    targetCurrency: selectedCurrencyCode,
                    rates: currencyRates,
                  );
                }
                return _accountsSnapshotFromMonthSnapshot(snapshot);
              }

              final previewSelectedSnapshot = isPreviewMode
                  ? previewWalletsData?.snapshotForMonth(selectedMonth)
                  : null;
              final rawSelectedSnapshot = previewSelectedSnapshot != null
                  ? accountsSnapshotForMonth(previewSelectedSnapshot)
                  : walletsPageState?.displayedSnapshot != null
                      ? accountsSnapshotForMonth(
                          walletsPageState!.displayedSnapshot!,
                        )
                      : _buildOpeningSnapshot(
                          wallets,
                          targetCurrency: selectedCurrencyCode,
                          rates: currencyRates,
                        );
              final displayedSelectedSnapshot = rawSelectedSnapshot;

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    RepaintBoundary(
                      child: SizedBox(
                        height: (!hasDismissedSwipeHintState.value &&
                                availableMonths.length > 1)
                            ? 290
                            : 260,
                        child: PageView.builder(
                          itemCount: availableMonths.length,
                          controller: monthPageController,
                          reverse: true,
                          onPageChanged: (index) {
                            final monthStart = availableMonths[index];
                            if (isPreviewMode) {
                              previewSelectedMonthState.value = monthStart;
                            } else {
                              unawaited(ref
                                  .read(walletsPageStateProvider(scopeQuery)
                                      .notifier)
                                  .selectMonth(monthStart));
                            }
                            if (hasDismissedSwipeHintState.value) {
                              return;
                            }
                            hasDismissedSwipeHintState.value = true;
                            unawaited(prefs.setBool(swipeHintPrefKey, true));
                          },
                          itemBuilder: (context, index) {
                            final monthStart = availableMonths[index];
                            final isActive = selectedMonthIndex == index;
                            final monthSnapshot = isPreviewMode
                                ? previewWalletsData
                                    ?.snapshotForMonth(monthStart)
                                : walletsPageState
                                    ?.cachedSnapshotsByMonth[monthStart];
                            final canUseCurrentWalletBalanceFallback =
                                !isPreviewMode &&
                                    _normalizeWalletMonth(
                                          monthStart,
                                          financialMonthStartDay:
                                              scopeQuery.financialMonthStartDay,
                                        ) ==
                                        _normalizeWalletMonth(
                                          scopeQuery.currentMonthStart,
                                          financialMonthStartDay:
                                              scopeQuery.financialMonthStartDay,
                                        ) &&
                                    wallets.isNotEmpty;
                            final isOverviewLoading = !isPreviewMode &&
                                isActive &&
                                monthSnapshot == null &&
                                !canUseCurrentWalletBalanceFallback &&
                                (walletsPageState?.isSelectedMonthLoading ??
                                    false);
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Container(
                                key: isActive ? netWorthSpotlightKey : null,
                                child: _WalletsOverviewCard(
                                  availableMonths: availableMonths,
                                  monthStart: monthStart,
                                  selectedMonthStart: selectedMonth,
                                  snapshot: monthSnapshot != null
                                      ? accountsSnapshotForMonth(
                                          monthSnapshot,
                                        )
                                      : displayedSelectedSnapshot,
                                  history: isPreviewMode
                                      ? previewWalletsData?.history
                                      : walletsPageState?.history,
                                  currencyCode: selectedCurrencyCode,
                                  hasDismissedSwipeHint:
                                      hasDismissedSwipeHintState.value,
                                  error: !isPreviewMode && isActive
                                      ? walletsPageState?.selectedMonthError
                                      : null,
                                  isLoading: isOverviewLoading,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!hasWalletsContent && walletsAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24, top: 12),
                        child: _WalletStackLoadingSection(),
                      )
                    else if (wallets.isEmpty)
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
                      RepaintBoundary(
                        key: walletStackSpotlightKey,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24, top: 12),
                          child: _WalletAccountStack(
                            wallets: wallets,
                            isPreviewMode: isPreviewMode,
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
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    ));
  }
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
  final DateTime monthStart;
  final DateTime selectedMonthStart;
  final _AccountsSnapshot snapshot;
  final WalletsHistorySummary? history;
  final String currencyCode;
  final bool hasDismissedSwipeHint;
  final bool isLoading;
  final Object? error;

  const _WalletsOverviewCard({
    required this.availableMonths,
    required this.monthStart,
    required this.selectedMonthStart,
    required this.snapshot,
    required this.history,
    required this.currencyCode,
    required this.hasDismissedSwipeHint,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final monthLabel =
        MaterialLocalizations.of(context).formatMonthYear(monthStart);
    final rawTargetMonthIndex = availableMonths.indexOf(selectedMonthStart);
    final targetMonthIndex = rawTargetMonthIndex >= 0 ? rawTargetMonthIndex : 0;

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
          Container(
            key: isLoading
                ? const ValueKey('wallets-overview-loading')
                : ValueKey('wallets-overview-loaded-$monthLabel'),
            child: Skeletonizer(
              enabled: isLoading,
              child: error != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error.toString(),
                        style: TextStyle(
                          color: colorScheme.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _AnimatedNumberText(
                            value: snapshot.netWorth,
                            symbol: symbol,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.foreground,
                              letterSpacing: 0,
                              height: 1.1,
                            ),
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
                                    value: snapshot.totalIncome,
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
                                    value: snapshot.totalSpent,
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
                      ],
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
                                  letterSpacing: 0,
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
  final bool isPreviewMode;

  const _WalletAccountStack({
    required this.wallets,
    required this.isPreviewMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(sharedPreferencesProvider);
    final selectedCurrencyFilters = ref.watch(
      homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
    );
    final shouldShowExpandedCurrencyFlag =
        (selectedCurrencyFilters?.length ?? 0) > 1;
    const orderKey = 'wallet_accounts_order';

    final orderedAccountsState = useState<List<WalletEntity>>([...wallets]);
    final draggedAccountIdState = useState<String?>(null);
    final selectedAccountIdState = useState<String?>(null);

    // Sync from props/prefs
    useEffect(() {
      final savedOrder = prefs.getStringList(orderKey) ?? [];
      final list = [...wallets];
      final inputOrder = <String, int>{
        for (var index = 0; index < wallets.length; index++)
          wallets[index].id: index,
      };
      list.sort((a, b) {
        final indexA = savedOrder.indexOf(a.id);
        final indexB = savedOrder.indexOf(b.id);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        return (inputOrder[a.id] ?? 0).compareTo(inputOrder[b.id] ?? 0);
      });
      orderedAccountsState.value = list;

      if (selectedAccountIdState.value == null && list.isNotEmpty) {
        selectedAccountIdState.value = isPreviewMode
            ? list[(list.length >= 3) ? 2 : list.length - 1].id
            : list.last.id;
      }
      return null;
    }, [wallets, isPreviewMode]);

    final orderedAccounts = orderedAccountsState.value;
    final selectedId = selectedAccountIdState.value;

    const tightSpacing = 70.0;
    const expandedCardHeight = 240.0;
    const unselectedCardHeight = 115.0;

    const gap = 20.0;

    const bottomBuffer = 0.0;

    int safeSelectedIdx = orderedAccounts.indexWhere((a) => a.id == selectedId);
    if (safeSelectedIdx == -1 && orderedAccounts.isNotEmpty) {
      safeSelectedIdx = orderedAccounts.length - 1;
    }

    double calculateStackHeight() {
      if (orderedAccounts.isEmpty) return 0.0;
      if (orderedAccounts.length == 1) return expandedCardHeight + bottomBuffer;

      if (safeSelectedIdx == orderedAccounts.length - 1) {
        return safeSelectedIdx * tightSpacing +
            expandedCardHeight +
            bottomBuffer;
      }
      return safeSelectedIdx * tightSpacing +
          expandedCardHeight +
          gap +
          (orderedAccounts.length - 2 - safeSelectedIdx) * tightSpacing +
          unselectedCardHeight +
          bottomBuffer;
    }

    final stackHeight = calculateStackHeight();

    double getTop(int index, WalletEntity wallet) {
      if (index <= safeSelectedIdx) {
        return index * tightSpacing;
      } else {
        return safeSelectedIdx * tightSpacing +
            expandedCardHeight +
            gap +
            (index - safeSelectedIdx - 1) * tightSpacing;
      }
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
                  } else if (isPreviewMode) {
                    AppToast.info(
                      context,
                      context.l10n.previewMockUpdatesApplied,
                    );
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
                child: WalletStackCard(
                  wallet: wallet,
                  currencyCode: wallet.currency,
                  displayBalanceCents: wallet.currentBalanceCents,
                  isExpanded: isExpanded,
                  headerAction: isExpanded && shouldShowExpandedCurrencyFlag
                      ? _WalletCurrencyFlagBadge(currencyCode: wallet.currency)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _WalletCurrencyFlagBadge extends StatelessWidget {
  const _WalletCurrencyFlagBadge({
    required this.currencyCode,
  });

  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final flagPath = getCurrencyFlagPath(normalizedCurrency);
    final fallbackLabel = normalizedCurrency.isNotEmpty
        ? normalizedCurrency.substring(0, 1)
        : '?';

    return SizedBox(
      width: 15,
      height: 15,
      child: ClipOval(
        child: flagPath != null
            ? Image.asset(flagPath, fit: BoxFit.cover)
            : Center(
                child: Text(
                  fallbackLabel,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

String _walletsMonthSwipeHintDismissedKey(String userId) {
  return 'accounts_month_swipe_hint_dismissed:$userId';
}

_PreviewWalletsPageData _buildPreviewWalletsPageData({
  required String selectedCurrencyCode,
  required DateTime effectiveNow,
  required int financialMonthStartDay,
}) {
  final wallets = PreviewMockData.wallets;
  final transactions = _buildPreviewWalletTransactions(
    wallets: wallets,
    selectedCurrencyCode: selectedCurrencyCode,
  );
  final availableMonths = buildWalletAvailableMonths(
    now: effectiveNow,
    transactions: transactions,
    financialMonthStartDay: financialMonthStartDay,
  );
  final monthSnapshots = <DateTime, WalletsMonthSnapshot>{};
  const rates = CurrencyRateTable(
    baseCurrency: 'USD',
    rates: CurrencyRates.rates,
    isStale: true,
  );

  for (final monthStart in availableMonths) {
    final normalizedMonthStart = _normalizeWalletMonth(
      monthStart,
      financialMonthStartDay: financialMonthStartDay,
    );
    final monthEndExclusive = _previewWalletSnapshotEndExclusive(
      monthStart: normalizedMonthStart,
      effectiveNow: effectiveNow,
      financialMonthStartDay: financialMonthStartDay,
    );
    final snapshot = buildWalletSnapshot(
      wallets: wallets,
      transactions: transactions,
      endExclusive: monthEndExclusive,
      periodStart: normalizedMonthStart,
      periodEndExclusive: monthEndExclusive,
      targetCurrency: selectedCurrencyCode,
      rates: rates,
    );
    monthSnapshots[normalizedMonthStart] = WalletsMonthSnapshot(
      monthStart: normalizedMonthStart,
      monthEndExclusive: monthEndExclusive,
      incomeTotalCents: snapshot.totalIncomeCents,
      spentTotalCents: snapshot.totalSpentCents,
      netWorthCents: snapshot.netWorthCents,
      walletBalances: snapshot.walletBalances,
    );
  }

  final history = WalletsHistorySummary(
    availableMonths: availableMonths,
    netWorthSeries: availableMonths.reversed.map((monthStart) {
      final snapshot = monthSnapshots[_normalizeWalletMonth(
        monthStart,
        financialMonthStartDay: financialMonthStartDay,
      )];
      return WalletNetWorthPoint(
        monthStart: monthStart,
        netWorthCents: snapshot?.netWorthCents ?? 0,
      );
    }).toList(growable: false),
  );

  return _PreviewWalletsPageData(
    wallets: wallets,
    history: history,
    monthSnapshots: monthSnapshots,
    financialMonthStartDay: financialMonthStartDay,
  );
}

List<ExpenseEntry> _buildPreviewWalletTransactions({
  required List<WalletEntity> wallets,
  required String selectedCurrencyCode,
}) {
  if (wallets.isEmpty) {
    return const <ExpenseEntry>[];
  }

  final defaultWalletId = resolveDefaultWalletId(wallets);
  final walletsById = <String, WalletEntity>{
    for (final wallet in wallets) wallet.id: wallet,
  };

  return PreviewMockData.expenses
      .where((expense) {
        final normalizedCurrency = expense.currency?.trim().toUpperCase();
        if (normalizedCurrency != selectedCurrencyCode) {
          return false;
        }
        return true;
      })
      .map((expense) {
        final walletId = _resolvePreviewTransactionWalletId(
          expense: expense,
          defaultWalletId: defaultWalletId,
        );
        if (walletId == null) {
          return null;
        }

        final wallet = walletsById[walletId];
        if (wallet == null) {
          return null;
        }

        return expense.copyWith(
          accountId: wallet.id,
          accountName: wallet.name,
          accountIcon: wallet.icon,
          accountColor: wallet.color,
        );
      })
      .whereType<ExpenseEntry>()
      .toList(growable: false);
}

String? _resolvePreviewTransactionWalletId({
  required ExpenseEntry expense,
  required String? defaultWalletId,
}) {
  final householdId = expense.householdId?.trim();
  if (householdId == null || householdId.isEmpty) {
    return defaultWalletId;
  }

  return householdId;
}

DateTime _previewWalletSnapshotEndExclusive({
  required DateTime monthStart,
  required DateTime effectiveNow,
  required int financialMonthStartDay,
}) {
  final normalizedMonthStart = _normalizeWalletMonth(
    monthStart,
    financialMonthStartDay: financialMonthStartDay,
  );
  final currentMonthStart = _normalizeWalletMonth(
    effectiveNow,
    financialMonthStartDay: financialMonthStartDay,
  );
  if (normalizedMonthStart == currentMonthStart) {
    return DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day + 1,
    );
  }

  return addFinancialCycles(
    normalizedMonthStart,
    1,
    startDay: financialMonthStartDay,
  );
}

DateTime _normalizeWalletMonth(
  DateTime date, {
  int financialMonthStartDay = 1,
}) {
  return normalizeWalletMonthStart(
    date,
    financialMonthStartDay: financialMonthStartDay,
  );
}

_AccountsSnapshot _buildOpeningSnapshot(
  List<WalletEntity> wallets, {
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final walletBalances = <String, int>{
    for (final wallet in wallets)
      wallet.id: _convertWalletCents(
        wallet.currentBalanceCents,
        fromCurrency: wallet.currency,
        targetCurrency: targetCurrency,
        rates: rates,
      ),
  };
  var netWorthCents = 0;
  final excludedWalletIds = wallets
      .where((wallet) => wallet.excludeFromAnalytics)
      .map((wallet) => wallet.id)
      .toSet();
  for (final entry in walletBalances.entries) {
    if (!excludedWalletIds.contains(entry.key)) {
      netWorthCents += entry.value;
    }
  }
  return _AccountsSnapshot(
    totalIncome: 0,
    totalSpent: 0,
    netWorth: netWorthCents / 100.0,
    walletBalances: walletBalances,
  );
}

_AccountsSnapshot _accountsSnapshotFromCurrentWalletBalances(
  WalletsMonthSnapshot snapshot,
  List<WalletEntity> wallets, {
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final walletBalances = <String, int>{
    for (final wallet in wallets)
      wallet.id: _convertWalletCents(
        wallet.currentBalanceCents,
        fromCurrency: wallet.currency,
        targetCurrency: targetCurrency,
        rates: rates,
      ),
  };
  var netWorthCents = 0;
  final excludedWalletIds = wallets
      .where((wallet) => wallet.excludeFromAnalytics)
      .map((wallet) => wallet.id)
      .toSet();
  for (final entry in walletBalances.entries) {
    if (!excludedWalletIds.contains(entry.key)) {
      netWorthCents += entry.value;
    }
  }
  return _AccountsSnapshot(
    totalIncome: snapshot.incomeTotalCents / 100.0,
    totalSpent: snapshot.spentTotalCents / 100.0,
    netWorth: netWorthCents / 100.0,
    walletBalances: walletBalances,
  );
}

int _convertWalletCents(
  int amountCents, {
  required String? fromCurrency,
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final normalizedFrom = fromCurrency?.trim().toUpperCase();
  final normalizedTarget = targetCurrency.trim().toUpperCase();
  if (normalizedFrom == null ||
      normalizedFrom.isEmpty ||
      normalizedTarget.isEmpty) {
    return amountCents;
  }
  final sign = amountCents < 0 ? -1 : 1;
  final converted = rates.convert(
    amountCents.abs() / 100.0,
    normalizedFrom,
    normalizedTarget,
  );
  return (converted * 100).round() * sign;
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

bool _isConnectionInWalletsScope(
  BankConnection connection,
  HouseholdScope scope,
) {
  final scopeHouseholdId = _resolveWalletsScopeHouseholdId(scope);
  if (scopeHouseholdId == null) {
    return connection.householdId == null || connection.householdId!.isEmpty;
  }

  return connection.householdId == scopeHouseholdId;
}

class _PreviewWalletsPageData {
  const _PreviewWalletsPageData({
    required this.wallets,
    required this.history,
    required this.monthSnapshots,
    required this.financialMonthStartDay,
  });

  final List<WalletEntity> wallets;
  final WalletsHistorySummary history;
  final Map<DateTime, WalletsMonthSnapshot> monthSnapshots;
  final int financialMonthStartDay;

  WalletsMonthSnapshot? snapshotForMonth(DateTime monthStart) {
    return monthSnapshots[_normalizeWalletMonth(
      monthStart,
      financialMonthStartDay: financialMonthStartDay,
    )];
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
                    const Bone.text(words: 2, fontSize: 15),
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
                      child: const Bone.text(words: 1, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Large amount
                const Bone.text(words: 1, fontSize: 36),
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
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone.text(words: 1, fontSize: 12),
                          SizedBox(height: 4),
                          Bone.text(words: 1, fontSize: 16),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone.text(words: 1, fontSize: 12),
                          SizedBox(height: 4),
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
          SizedBox(
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Bone.icon(size: 20),
              SizedBox(width: 8),
              Bone.text(words: 2, fontSize: 14),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Bone.icon(size: 20),
              SizedBox(width: 8),
              Bone.text(words: 2, fontSize: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletStackLoadingSection extends StatelessWidget {
  const _WalletStackLoadingSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Skeletonizer(
      effect: ShimmerEffect(
        baseColor: colorScheme.skeletonBase,
        highlightColor: colorScheme.skeletonHighlight,
      ),
      child: SizedBox(
        height: 400,
        child: Stack(
          children: [
            Positioned(
              top: 150,
              left: 0,
              right: 0,
              height: 130,
              child: _SkeletonWalletCard(colorScheme: colorScheme),
            ),
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              height: 130,
              child: _SkeletonWalletCard(colorScheme: colorScheme),
            ),
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
                const Bone.text(words: 2, fontSize: 18),
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon circle
                    Bone.circle(size: 36),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Balance label
                        Bone.text(words: 1, fontSize: 10),
                        SizedBox(height: 4),
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
                const Center(
                  child: Bone.text(words: 3, fontSize: 12),
                ),
              ],
            )
          : const Row(
              children: [
                // Icon circle
                Bone.circle(size: 36),
                SizedBox(width: 12),
                // Wallet name
                Expanded(
                  child: Bone.text(words: 2, fontSize: 16),
                ),
                SizedBox(width: 12),
                // Amount
                Bone.text(words: 1, fontSize: 20),
              ],
            ),
    );
  }
}
