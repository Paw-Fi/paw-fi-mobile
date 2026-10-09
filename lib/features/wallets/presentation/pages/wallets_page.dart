import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
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
import 'package:moneko/core/theme/moneko_text_scaling.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';
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

import 'package:moneko/features/wallets/presentation/pages/wallet_details_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transaction_binding.dart';
import 'package:moneko/features/wallets/presentation/widgets/add_wallet_option_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_stack_card.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_account_stack.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/features/home/presentation/state/bank_accounts_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/swipe_hint_row.dart';
import 'package:moneko/shared/widgets/atmospheric_header_lines.dart';
import 'package:moneko/shared/widgets/seamless_header_action.dart';
import 'package:moneko/shared/widgets/header_month_label.dart';
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
    final measuredOverviewHeight = useState<MapEntry<String, double>?>(null);
    final isExpandedHeader = MonekoTextScale.isAtLeast(context, 1.2);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final isPreviewMode = ref.watch(previewModeProvider).isActive;
    final actions = ref.watch(walletActionsProvider);
    final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
    final auth = ref.watch(authProvider);
    final walletAuthHeaders = ref.watch(walletAuthHeadersProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    if (!isPreviewMode && auth.uid.isEmpty) {
      return const StatusBarOverlayRegion(
        child: AdaptiveScaffold(
          body: SafeArea(
            child: _WalletsPageSkeleton(),
          ),
        ),
      );
    }

    if (!isPreviewMode && walletAuthHeaders == null) {
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
      if (isPreviewMode || !context.mounted) {
        return;
      }

      try {
        await Future.wait([
          ref.read(scopedWalletsProvider.notifier).refreshFromNetwork(),
          ref.read(walletsPageStateProvider(scopeQuery).notifier).refresh(),
        ]);
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
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
    final addWalletSheetRequest =
        ref.watch(walletsAddWalletSheetRequestProvider);
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
    if (!isPreviewMode &&
        currentTabIndex == 3 &&
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
          onLocallyPersisted: () {
            if (context.mounted) {
              AppToast.success(context, context.l10n.walletCreatedSuccessfully);
            }
          },
        );
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

    Future<void> onTransfer() async {
      if (isPreviewMode) {
        AppToast.info(context, context.l10n.previewMockUpdatesApplied);
        return;
      }
      final wallets = ref.read(effectiveScopeWalletsProvider);
      final transferWallets = wallets
          .where((wallet) => wallets.any((other) =>
              other.id != wallet.id && other.currency == wallet.currency))
          .toList(growable: false);
      if (transferWallets.length < 2) {
        AppToast.info(context, context.l10n.needTwoWalletsForTransfer);
        return;
      }

      final result = await showWalletTransferSheet(
        context,
        wallets: transferWallets,
        onSubmit: (result) async {
          final operation = await actions.createTransfer(
            fromAccountId: result.fromAccountId,
            toAccountId: result.toAccountId,
            amountCents: result.amountCents,
            currency: result.currency,
            date: result.date,
            time: result.time,
            note: result.note,
          );
          unawaited(operation.completion.then((result) {
            if (context.mounted &&
                result != null &&
                result is! List<ExpenseEntry>) {
              AppToast.error(
                  context, ErrorHandler.getUserFriendlyMessage(result));
            }
          }));
        },
      );
      if (result != null && context.mounted) {
        AppToast.success(context, context.l10n.transferCompletedSuccessfully);
      }
    }

    useEffect(() {
      if (addWalletSheetRequest == 0 || currentTabIndex != 3) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(walletsAddWalletSheetRequestProvider.notifier).state = 0;
        onAddAccount();
      });
      return null;
    }, [addWalletSheetRequest, currentTabIndex]);

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AtmosphericHeaderBackground(),
          ),
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
              final overviewHeightKey = '${selectedMonth.toIso8601String()}|'
                  '$textScale|${MediaQuery.sizeOf(context).width}|'
                  '${Localizations.localeOf(context)}|'
                  '${hasDismissedSwipeHintState.value}';
              final overviewHeight =
                  measuredOverviewHeight.value?.key == overviewHeightKey
                      ? measuredOverviewHeight.value!.value
                      : null;
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
              final isWalletStackLoading = !isPreviewMode &&
                  (walletsPageState?.isSelectedMonthLoading ?? false) &&
                  walletsPageState?.selectedSnapshot == null &&
                  walletsPageState?.displayedSnapshot != null;

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, PlatformInfo.isIOS26OrHigher() ? 120 : 24),
                  children: [
                    RepaintBoundary(
                      child: SizedBox(
                        height: overviewHeight ??
                            (isExpandedHeader
                                ? 400
                                : (!hasDismissedSwipeHintState.value &&
                                        availableMonths.length > 1)
                                    ? 240
                                    : 210),
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
                                child: OverflowBox(
                                  key: isActive
                                      ? const ValueKey(
                                          'wallets-overview-active')
                                      : null,
                                  minHeight: 0,
                                  maxHeight: double.infinity,
                                  alignment: Alignment.topCenter,
                                  child: _WalletsOverviewCard(
                                    onHeightChanged: isActive
                                        ? (height) {
                                            final current =
                                                measuredOverviewHeight.value;
                                            if (current?.key ==
                                                    overviewHeightKey &&
                                                (current!.value - height)
                                                        .abs() <
                                                    1) {
                                              return;
                                            }
                                            measuredOverviewHeight.value =
                                                MapEntry(
                                                    overviewHeightKey, height);
                                          }
                                        : null,
                                    availableMonths: availableMonths,
                                    monthStart: monthStart,
                                    snapshot: monthSnapshot != null
                                        ? accountsSnapshotForMonth(
                                            monthSnapshot,
                                          )
                                        : displayedSelectedSnapshot,
                                    currencyCode: selectedCurrencyCode,
                                    hasDismissedSwipeHint:
                                        hasDismissedSwipeHintState.value,
                                    error: !isPreviewMode && isActive
                                        ? walletsPageState?.selectedMonthError
                                        : null,
                                    isLoading: isOverviewLoading,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (!isPreviewMode)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              KeyedSubtree(
                                key: newWalletSpotlightKey,
                                child: SeamlessHeaderAction(
                                  label: context.l10n.addWallet,
                                  icon: Icons.add_rounded,
                                  onPressed: onAddAccount,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SeamlessHeaderAction(
                                label: context.l10n.transfer,
                                icon: Icons.swap_horiz_rounded,
                                onPressed: onTransfer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!hasWalletsContent && walletsAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24, top: 12),
                        child: _WalletStackLoadingSection(),
                      )
                    else if (wallets.isEmpty)
                      EmptyWalletStackCard(
                        key: const ValueKey('wallets-empty-add-card'),
                        onAddWallet: onAddAccount,
                      )
                    else
                      RepaintBoundary(
                        key: walletStackSpotlightKey,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24, top: 12),
                          child: Skeletonizer(
                            key: const ValueKey('wallet-stack-loading'),
                            enabled: isWalletStackLoading,
                            child: _WalletAccountStack(
                              wallets: wallets,
                              isPreviewMode: isPreviewMode,
                              walletBalances:
                                  displayedSelectedSnapshot.walletBalances,
                              displayCurrency: selectedCurrencyCode,
                              rates: currencyRates,
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
  final bool singleLine;

  const _AnimatedNumberText({
    required this.value,
    required this.symbol,
    required this.style,
    this.singleLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Text(
          '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(val)))}',
          style: WidgetTextStyles.roundedNumber(
            Theme.of(context),
            baseStyle: style,
          ),
          maxLines: singleLine ? 1 : null,
          softWrap: !singleLine,
        );
      },
    );
  }
}

class _WalletsOverviewCard extends HookConsumerWidget {
  final ValueChanged<double>? onHeightChanged;
  final List<DateTime> availableMonths;
  final DateTime monthStart;
  final _AccountsSnapshot snapshot;
  final String currencyCode;
  final bool hasDismissedSwipeHint;
  final bool isLoading;
  final Object? error;

  const _WalletsOverviewCard({
    this.onHeightChanged,
    required this.availableMonths,
    required this.monthStart,
    required this.snapshot,
    required this.currencyCode,
    required this.hasDismissedSwipeHint,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardKey = useMemoized(() => GlobalKey(), []);
    final contentEndKey = useMemoized(() => GlobalKey(), []);
    if (onHeightChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final card = cardKey.currentContext?.findRenderObject();
        final contentEnd = contentEndKey.currentContext?.findRenderObject();
        if (card is RenderBox && contentEnd is RenderBox) {
          final contentBottom =
              contentEnd.localToGlobal(Offset.zero, ancestor: card).dy;
          onHeightChanged!(contentBottom + 21);
        }
      });
    }
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final monthLabel = HeaderMonthLabel.format(context, monthStart);
    Widget buildMetric(String label, double value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: colorScheme.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          _AnimatedNumberText(
            value: value,
            symbol: symbol,
            singleLine: true,
            style: TextStyle(
              color: colorScheme.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      );
    }

    return KeyedSubtree(
      key: cardKey,
      child: Container(
        key: const ValueKey('wallets-overview-surface'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  context.l10n.totalNetWorth,
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                HeaderMonthLabel(
                  month: monthStart,
                  textKey: const ValueKey('wallets-overview-month-label'),
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
                            key:
                                const ValueKey('wallets-overview-total-amount'),
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: _AnimatedNumberText(
                              value: snapshot.netWorth,
                              symbol: symbol,
                              singleLine: true,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.foreground,
                                letterSpacing: -1.2,
                                height: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FittedBox(
                            key: const ValueKey('wallets-overview-metrics'),
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildMetric(
                                  context.l10n.income,
                                  snapshot.totalIncome,
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 15,
                                  child: VerticalDivider(
                                    width: 1,
                                    color: colorScheme.controlBorder,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                buildMetric(
                                  context.l10n.spent,
                                  snapshot.totalSpent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (!hasDismissedSwipeHint && availableMonths.length > 1) ...[
              const SizedBox(height: 12),
              SwipeHintRow(text: context.l10n.swipeRightPreviousMonths),
            ],
            SizedBox(key: contentEndKey, height: 0),
          ],
        ),
      ),
    );
  }
}

class _WalletAccountStack extends ConsumerWidget {
  final List<WalletEntity> wallets;
  final bool isPreviewMode;
  final Map<String, int> walletBalances;
  final String displayCurrency;
  final CurrencyRateTable rates;

  const _WalletAccountStack({
    required this.wallets,
    required this.isPreviewMode,
    required this.walletBalances,
    required this.displayCurrency,
    required this.rates,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCurrencies = ref.watch(
      homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
    );
    final householdScope = ref.watch(householdScopeProvider);
    final userId = ref.watch(authProvider).uid;
    final orderScope = (
      userId: userId,
      householdId: householdScope.activeAccountHouseholdId,
      isPreview: isPreviewMode,
    );
    return WalletAccountStack(
      key: ValueKey(orderScope),
      wallets: wallets,
      scope: orderScope,
      onOpenWallet: (wallet) {
        if (isPreviewMode) {
          AppToast.info(context, context.l10n.previewMockUpdatesApplied);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WalletDetailsPage(wallet: wallet),
            ),
          );
        }
      },
      cardBuilder: (wallet, isExpanded) => WalletStackCard(
        wallet: wallet,
        currencyCode: wallet.currency,
        displayBalanceCents: walletBalances[wallet.id] == null
            ? wallet.currentBalanceCents
            : _convertWalletCents(
                walletBalances[wallet.id]!,
                fromCurrency: displayCurrency,
                targetCurrency: wallet.currency,
                rates: rates,
              ),
        isExpanded: isExpanded,
        headerAction: isExpanded && (selectedCurrencies?.length ?? 0) > 1
            ? _WalletCurrencyFlagBadge(currencyCode: wallet.currency)
            : null,
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
      wallet.id: snapshot.walletBalances[wallet.id] ??
          _convertWalletCents(
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
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, PlatformInfo.isIOS26OrHigher() ? 120 : 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flex(
                  direction: MonekoTextScale.isAtLeast(context, 1.2)
                      ? Axis.vertical
                      : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Bone.text(words: 2, fontSize: 13),
                    if (MonekoTextScale.isAtLeast(context, 1.2))
                      const SizedBox(height: 8),
                    const Bone.text(words: 2, fontSize: 12),
                  ],
                ),
                const SizedBox(height: 12),
                const Bone.text(words: 1, fontSize: 40),
                const SizedBox(height: 16),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Bone.text(words: 1, fontSize: 12),
                      SizedBox(width: 4),
                      Bone.text(words: 1, fontSize: 15),
                      SizedBox(width: 12),
                      Bone(width: 1, height: 15),
                      SizedBox(width: 12),
                      Bone.text(words: 1, fontSize: 12),
                      SizedBox(width: 4),
                      Bone.text(words: 1, fontSize: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 28),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Bone(
                    height: 48,
                    width: 144,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                  Bone(
                    height: 48,
                    width: 128,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                ],
              ),
            ),
          ),
          // Skeleton for wallet stack - 3 skeleton cards
          SizedBox(
            height: 380,
            child: Stack(
              children: [
                // Skeleton card 1 (bottom)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 115,
                  child: _SkeletonWalletCard(colorScheme: colorScheme),
                ),
                // Skeleton card 2 (middle)
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  height: 115,
                  child: _SkeletonWalletCard(colorScheme: colorScheme),
                ),
                // Skeleton card 3 (top, expanded)
                Positioned(
                  top: 140,
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
        height: 380,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 115,
              child: _SkeletonWalletCard(colorScheme: colorScheme),
            ),
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              height: 115,
              child: _SkeletonWalletCard(colorScheme: colorScheme),
            ),
            Positioned(
              top: 140,
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
