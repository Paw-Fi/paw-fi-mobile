import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/pages/account_details_page.dart';
import 'package:moneko/features/accounts/presentation/pages/accounts_history_page.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_icon_resolver.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_transfer_sheet.dart';
import 'package:moneko/features/accounts/presentation/widgets/create_edit_account_sheet.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/swipe_hint_row.dart';

class AccountsPage extends HookConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonthIndexState = useState(0);
    final monthPageController = usePageController(viewportFraction: 0.96);
    final colorScheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(scopedAccountsProvider);
    final effectiveAccounts = ref.watch(effectiveScopedAccountsProvider);
    final actions = ref.watch(accountActionsProvider);
    final analytics = ref.watch(analyticsProvider);
    final auth = ref.watch(authProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final viewMode = ref.watch(viewModeProvider);
    final AsyncValue<List<Household>> householdsAsync =
        viewMode.mode == ViewMode.personal
            ? const AsyncValue<List<Household>>.data(<Household>[])
            : ref.watch(userHouseholdsProvider(ref.watch(authProvider).uid));

    Future<void> onRefresh() async {
      ref.invalidate(scopedAccountsProvider);
      await ref.read(scopedAccountsProvider.future);

      final userId = ref.read(authProvider).uid;
      if (userId.isNotEmpty) {
        await ref.read(analyticsProvider.notifier).loadData(
              userId,
              forceReload: true,
            );
      }
    }

    final scopedTransactions = analytics.allExpenses.where((expense) {
      return _isInActiveScope(expense, householdScope) && !expense.isRecurring;
    }).where((expense) {
      return _isInSelectedCurrency(expense, selectedCurrencyCode);
    }).toList(growable: false);

    final availableMonths = _buildAvailableMonths(scopedTransactions);
    final maxMonthIndex = availableMonths.length - 1;
    final swipeHintPrefKey = _accountsMonthSwipeHintDismissedKey(auth.uid);
    final hasDismissedSwipeHintState =
        useState<bool>(prefs.getBool(swipeHintPrefKey) ?? false);

    if (selectedMonthIndexState.value > maxMonthIndex) {
      selectedMonthIndexState.value = maxMonthIndex;
    }

    Future<void> onAddAccount() async {
      final result = await showCreateEditAccountSheet(context);
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

    Future<void> onTransfer(List<AccountEntity> accounts) async {
      final result = await showAccountTransferSheet(
        context,
        accounts: accounts,
      );
      if (result == null) return;
      try {
        await actions.createTransfer(
          fromAccountId: result.fromAccountId,
          toAccountId: result.toAccountId,
          amountCents: result.amountCents,
          currency: selectedCurrencyCode,
          date: result.date,
          note: result.note,
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

    return AdaptiveScaffold(
      floatingActionButton: shouldShowHomeFab(viewMode, householdsAsync)
          ? const Padding(
              padding: EdgeInsets.all(0),
              child: HomeAiExpandableFab(),
            )
          : null,
      body: SafeArea(
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString()),
            ),
          ),
          data: (_) {
            final accounts = effectiveAccounts;
            final selectedMonthIndex =
                selectedMonthIndexState.value.clamp(0, maxMonthIndex).toInt();
            final selectedMonth = availableMonths[selectedMonthIndex];
            final selectedSnapshot = _buildSnapshot(
              accounts: accounts,
              transactions: scopedTransactions,
              endExclusive: _startOfNextMonth(selectedMonth),
            );

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  SizedBox(
                    height: 290,
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
                          child: _AccountsOverviewCard(
                            availableMonths: availableMonths,
                            selectedMonthIndex: index,
                            isActive: isActive,
                            accounts: accounts,
                            scopedTransactions: scopedTransactions,
                            currencyCode: selectedCurrencyCode,
                            hasDismissedSwipeHint:
                                hasDismissedSwipeHintState.value,
                            activeSnapshot: selectedSnapshot,
                            activeMonthIndex: selectedMonthIndexState.value,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (accounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.sheetBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.border),
                      ),
                      child: Text(
                        'No accounts yet',
                        style: TextStyle(
                          color: colorScheme.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24, top: 12),
                      child: _WalletAccountStack(
                        accounts: accounts,
                        currencyCode: selectedCurrencyCode,
                        accountBalances: selectedSnapshot.accountBalances,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: onAddAccount,
                    icon: Icon(Icons.add, color: colorScheme.primary),
                    label: Text(
                      'New Account',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (accounts.length > 1)
                    TextButton.icon(
                      onPressed: () => onTransfer(accounts),
                      icon: Icon(Icons.swap_horiz, color: colorScheme.primary),
                      label: Text(
                        'Transfer',
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
    );
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

class _AccountsOverviewCard extends HookWidget {
  final List<DateTime> availableMonths;
  final int selectedMonthIndex;
  final bool isActive;
  final List<AccountEntity> accounts;
  final List<ExpenseEntry> scopedTransactions;
  final String currencyCode;
  final bool hasDismissedSwipeHint;
  final _AccountsSnapshot activeSnapshot;
  final int activeMonthIndex;

  const _AccountsOverviewCard({
    required this.availableMonths,
    required this.selectedMonthIndex,
    required this.isActive,
    required this.accounts,
    required this.scopedTransactions,
    required this.currencyCode,
    required this.hasDismissedSwipeHint,
    required this.activeSnapshot,
    required this.activeMonthIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final monthLabel = MaterialLocalizations.of(context)
        .formatMonthYear(availableMonths[selectedMonthIndex]);

    final targetMonthIndex = isActive ? selectedMonthIndex : activeMonthIndex;

    final selectedSnapshot = useMemoized(() {
      return _buildSnapshot(
        accounts: accounts,
        transactions: scopedTransactions,
        endExclusive: _startOfNextMonth(availableMonths[selectedMonthIndex]),
      );
    }, [availableMonths, selectedMonthIndex, accounts, scopedTransactions]);

    final spots = useMemoized(() {
      final timeAscendingMonths = availableMonths.reversed.toList();
      final newSpots = <FlSpot>[];
      final currentListSize = timeAscendingMonths.length - targetMonthIndex;
      for (int i = 0; i < currentListSize; i++) {
        final snap = _buildSnapshot(
          accounts: accounts,
          transactions: scopedTransactions,
          endExclusive: _startOfNextMonth(timeAscendingMonths[i]),
        );
        newSpots.add(FlSpot(i.toDouble(), snap.netWorth));
      }
      return newSpots;
    }, [availableMonths, accounts, scopedTransactions, targetMonthIndex]);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountsHistoryPage(),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      'Total Net Worth',
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.mutedForeground,
                      size: 20,
                    ),
                  ],
                ),
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
              value: isActive ? selectedSnapshot.netWorth : activeSnapshot.netWorth,
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
              child: LineChart(
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
                      spots: spots,
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
                            colorScheme.primary.withValues(alpha: 0.3),
                            colorScheme.primary.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
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
                      value: isActive ? selectedSnapshot.totalIncome : activeSnapshot.totalIncome,
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
                      value: isActive ? selectedSnapshot.totalSpent : activeSnapshot.totalSpent,
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
            const SwipeHintRow(text: 'Swipe right for previous months'),
          ],
        ],
      ),
    );
  }
}

class _WalletAccountStack extends HookConsumerWidget {
  final List<AccountEntity> accounts;
  final String currencyCode;
  final Map<String, int> accountBalances;

  const _WalletAccountStack({
    required this.accounts,
    required this.currencyCode,
    required this.accountBalances,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    const orderKey = 'wallet_accounts_order';

    final orderedAccountsState = useState<List<AccountEntity>>([...accounts]);
    final draggedAccountIdState = useState<String?>(null);
    final dragOffsetYState = useState<double>(0.0);
    final dragOriginalIndexState = useState<int>(0);

    // Sync from props/prefs
    useEffect(() {
      final savedOrder = prefs.getStringList(orderKey) ?? [];
      final list = [...accounts];
      list.sort((a, b) {
        final indexA = savedOrder.indexOf(a.id);
        final indexB = savedOrder.indexOf(b.id);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return 0; // maintain original order for new items
      });
      orderedAccountsState.value = list;
      return null;
    }, [accounts]);

    final orderedAccounts = orderedAccountsState.value;

    final selectedAccountIdState = useState<String?>(null);
    final isAnySelected = selectedAccountIdState.value != null;

    final selectedAccIndex = isAnySelected
        ? orderedAccounts
            .indexWhere((a) => a.id == selectedAccountIdState.value)
        : -1;

    const collapsedSpacing = 85.0;
    const tightSpacing = 16.0;
    const expandedCardHeight = 240.0;
    const unselectedCardHeight = 130.0;

    double stackHeight;
    if (!isAnySelected) {
      stackHeight = (orderedAccounts.isEmpty ? 0 : orderedAccounts.length - 1) *
              collapsedSpacing +
          unselectedCardHeight;
    } else {
      final cardsAfter = orderedAccounts.length - 1 - selectedAccIndex;
      if (cardsAfter <= 0) {
        stackHeight = selectedAccIndex * collapsedSpacing + expandedCardHeight;
      } else {
        stackHeight = selectedAccIndex * collapsedSpacing +
            expandedCardHeight +
            10.0 +
            (cardsAfter - 1) * tightSpacing +
            unselectedCardHeight;
      }
    }

    double getTop(int index, AccountEntity account) {
      if (!isAnySelected) {
        if (draggedAccountIdState.value == account.id) {
          return index * collapsedSpacing + dragOffsetYState.value;
        }
        return index * collapsedSpacing;
      }

      if (index == selectedAccIndex) {
        return index * collapsedSpacing; // STAY WHERE IT IS
      }

      if (index < selectedAccIndex) {
        // Expand to the top
        return index * tightSpacing;
      } else {
        // index > selectedAccIndex => Expand to bottom
        final positionInBottom = index - selectedAccIndex - 1;
        return selectedAccIndex * collapsedSpacing +
            expandedCardHeight +
            10.0 +
            (positionInBottom * tightSpacing);
      }
    }

    final renderAccounts = [...orderedAccounts];
    if (draggedAccountIdState.value != null) {
      final draggedAcc =
          renderAccounts.firstWhere((a) => a.id == draggedAccountIdState.value);
      renderAccounts.remove(draggedAcc);
      renderAccounts.add(draggedAcc);
    }

    return GestureDetector(
      onTap: () {
        selectedAccountIdState.value = null; // Background tap
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
        height: stackHeight,
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: renderAccounts.map((account) {
            final originalIndex = orderedAccounts.indexOf(account);
            final isExpanded = selectedAccountIdState.value == account.id;
            final isDragging = draggedAccountIdState.value == account.id;

            return AnimatedPositioned(
              key: ValueKey(account.id),
              top: getTop(originalIndex, account),
              left: 0,
              right: 0,
              height: isAnySelected ? expandedCardHeight : unselectedCardHeight,
              duration: isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: isAnySelected
                    ? null
                    : (details) {
                        draggedAccountIdState.value = account.id;
                        dragOffsetYState.value = 0.0;
                        dragOriginalIndexState.value = orderedAccounts
                            .indexWhere((a) => a.id == account.id);
                      },
                onLongPressMoveUpdate: isAnySelected
                    ? null
                    : (details) {
                        final originalIdx = dragOriginalIndexState.value;
                        final totalFingerDisplacement =
                            details.localOffsetFromOrigin.dy;

                        final absoluteDragPos = originalIdx * collapsedSpacing +
                            totalFingerDisplacement;

                        final targetIndex = (absoluteDragPos / collapsedSpacing)
                            .round()
                            .clamp(0, orderedAccounts.length - 1);
                        final currentIndex = orderedAccounts
                            .indexWhere((a) => a.id == account.id);

                        if (targetIndex != currentIndex) {
                          final newList = [...orderedAccounts];
                          final item = newList.removeAt(currentIndex);
                          newList.insert(targetIndex, item);
                          orderedAccountsState.value = newList;
                          unawaited(prefs.setStringList(
                              orderKey, newList.map((a) => a.id).toList()));
                        }

                        dragOffsetYState.value = absoluteDragPos -
                            (orderedAccounts
                                    .indexWhere((a) => a.id == account.id) *
                                collapsedSpacing);
                      },
                onLongPressEnd: isAnySelected
                    ? null
                    : (details) {
                        draggedAccountIdState.value = null;
                        dragOffsetYState.value = 0.0;
                      },
                onTap:
                    () {}, // Consume tap to prevent outer GestureDetector from collapsing immediately
                onTapUp: (details) {
                  if (!isAnySelected) {
                    // In collapse mode: clicking ANY card expands all cards.
                    selectedAccountIdState.value = account.id;
                  } else {
                    // In expanded mode:
                    if (details.localPosition.dy < 100) {
                      // Tap on edge of the card -> EVERYTHING should collapse
                      selectedAccountIdState.value = null;
                    } else {
                      // Click on the body of the card -> go into details page
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                          builder: (_) => AccountDetailsPage(
                            account: account,
                          ),
                        ),
                      )
                          .then((_) {
                        // Keep expanded on return
                      });
                    }
                  }
                },
                child: _AccountStackCard(
                  account: account,
                  currencyCode: currencyCode,
                  displayBalanceCents: accountBalances[account.id] ??
                      account.currentBalanceCents,
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

class _AccountStackCard extends StatelessWidget {
  const _AccountStackCard({
    required this.account,
    required this.currencyCode,
    required this.displayBalanceCents,
    required this.isExpanded,
  });

  final AccountEntity account;
  final String currencyCode;
  final int displayBalanceCents;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final amount = displayBalanceCents / 100.0;
    final isNegative = amount < 0;

    final goal = (account.goalAmountCents ?? 0) / 100.0;
    final currentProgressAmount = amount < 0 ? 0.0 : amount;

    double progress = 0.0;
    if (goal > 0) {
      progress = (currentProgressAmount / goal).clamp(0.0, 1.0);
    } else if (goal == 0) {
      progress = 1.0;
    }

    final accountColorRaw = account.color.toUpperCase() == '#6B7280'
        ? colorScheme.primary
        : parseAccountColor(account.color, colorScheme.primary);
    final baseColor = AppTheme.tunedPocketBaseColor(
      accountColorRaw,
      colorScheme,
      hasCustomColor: account.color.toUpperCase() != '#6B7280',
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
            resolveAccountIcon(account.icon),
            color: baseColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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

    final expandedHeader = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      resolveAccountIcon(account.icon),
                      color: baseColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(height: 12),
            Text(
              'BALANCE',
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
            const SizedBox(height: 6),
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
                    'Tap to view details',
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

String? _resolveDefaultAccountId(List<AccountEntity> accounts) {
  for (final account in accounts) {
    if (account.isDefault && !account.isArchived) {
      return account.id;
    }
  }
  for (final account in accounts) {
    if (account.isSystem &&
        account.name.trim().toLowerCase() == 'spending' &&
        !account.isArchived) {
      return account.id;
    }
  }
  return accounts.isNotEmpty ? accounts.first.id : null;
}

String? _resolveTransactionAccountId({
  required ExpenseEntry transaction,
  required String? defaultAccountId,
}) {
  final raw = transaction.accountId?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  return defaultAccountId;
}

bool _isInSelectedCurrency(ExpenseEntry expense, String currencyCode) {
  final normalized = expense.currency?.trim().toUpperCase();
  return normalized == currencyCode;
}

List<DateTime> _buildAvailableMonths(List<ExpenseEntry> transactions) {
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  if (transactions.isEmpty) {
    return <DateTime>[currentMonth];
  }

  var earliest = currentMonth;
  for (final tx in transactions) {
    final txMonth = DateTime(tx.date.year, tx.date.month);
    if (txMonth.isBefore(earliest)) {
      earliest = txMonth;
    }
  }

  final months = <DateTime>[];
  var cursor = currentMonth;
  while (!cursor.isBefore(earliest)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month - 1);
  }
  return months;
}

String _accountsMonthSwipeHintDismissedKey(String userId) {
  return 'accounts_month_swipe_hint_dismissed:$userId';
}

DateTime _startOfNextMonth(DateTime month) {
  return DateTime(month.year, month.month + 1);
}

_AccountsSnapshot _buildSnapshot({
  required List<AccountEntity> accounts,
  required List<ExpenseEntry> transactions,
  required DateTime endExclusive,
}) {
  final filteredTransactions = transactions.where((expense) {
    return expense.date.isBefore(endExclusive);
  }).toList(growable: false);

  var totalIncome = 0.0;
  var totalSpent = 0.0;
  for (final expense in filteredTransactions) {
    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    if (isIncome) {
      totalIncome += expense.amount.abs();
    } else {
      totalSpent += expense.amount.abs();
    }
  }

  final defaultAccountId = _resolveDefaultAccountId(accounts);
  final accountBalances = <String, int>{
    for (final account in accounts) account.id: account.openingBalanceCents,
  };
  for (final tx in filteredTransactions) {
    final resolvedAccountId = _resolveTransactionAccountId(
      transaction: tx,
      defaultAccountId: defaultAccountId,
    );
    if (resolvedAccountId == null ||
        !accountBalances.containsKey(resolvedAccountId)) {
      continue;
    }
    final amountCents = tx.amountCents.abs();
    final isIncome = (tx.type ?? 'expense').toLowerCase() == 'income';
    final current = accountBalances[resolvedAccountId] ?? 0;
    accountBalances[resolvedAccountId] =
        isIncome ? current + amountCents : current - amountCents;
  }

  final netWorth =
      accountBalances.values.fold<int>(0, (sum, value) => sum + value) / 100.0;

  return _AccountsSnapshot(
    totalIncome: totalIncome,
    totalSpent: totalSpent,
    netWorth: netWorth,
    accountBalances: accountBalances,
  );
}

class _AccountsSnapshot {
  const _AccountsSnapshot({
    required this.totalIncome,
    required this.totalSpent,
    required this.netWorth,
    required this.accountBalances,
  });

  final double totalIncome;
  final double totalSpent;
  final double netWorth;
  final Map<String, int> accountBalances;
}

class _OrganicAccountTileClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const radius = 24.0;
    const dipDepth = 16.0;
    final path = Path();

    final double holeCenter = size.width * 0.50;
    final double holeHalfWidth = size.width * 0.16;
    final double flatBottomHalfWidth = size.width * 0.03;

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
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

bool _isInActiveScope(ExpenseEntry expense, HouseholdScope scope) {
  final householdId = expense.householdId;
  switch (scope.activeAccountType) {
    case ActiveAccountType.personal:
      return householdId == null || householdId.isEmpty;
    case ActiveAccountType.portfolio:
      final selected = scope.activeAccountHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
    case ActiveAccountType.household:
      final selected = scope.selectedHouseholdId;
      return selected != null && selected.isNotEmpty && householdId == selected;
  }
}
