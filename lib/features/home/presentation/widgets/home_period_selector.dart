import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart'
    show supabaseClientProvider;
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/date_period_selector.dart';

final homePeriodVisiblePeriodsProvider = StateProvider<List<DateTime>>(
  (ref) => const [],
);

class HomePeriodSelector extends ConsumerStatefulWidget {
  const HomePeriodSelector({
    super.key,
    required this.isActive,
  });

  final bool isActive;

  @override
  ConsumerState<HomePeriodSelector> createState() => _HomePeriodSelectorState();
}

class _HomePeriodSelectorState extends ConsumerState<HomePeriodSelector> {
  int _ringAnimationRevision = 0;

  @override
  void didUpdateWidget(covariant HomePeriodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _ringAnimationRevision++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authenticatedUserId =
        ref.watch(authProvider.select((user) => user.uid));
    final previewMode = ref.watch(previewModeProvider);
    final userId = previewMode.isActive
        ? PreviewMockData.contact.userId ?? 'preview-user'
        : authenticatedUserId;
    if (userId.isEmpty) return const SizedBox.shrink();
    final state = ref.watch(homePeriodSelectionProvider(userId));
    final now = ref.watch(homePeriodNowProvider);
    final financialStartDay =
        ref.watch(homePeriodFinancialMonthStartDayProvider);
    final scope = ref.watch(householdScopeProvider);
    final filterState = ref.watch(homeFilterProvider);
    final currency = ref.watch(selectedHomeCurrencyCodeProvider);
    final selectedCurrencies = filterState.normalizedSelectedCurrencies;
    final isBootstrapCurrency = !filterState.hasExplicitCurrency;
    final includeRecurring =
        ref.watch(includeUpcomingRecurringInPocketsProvider);
    final accountCreatedAt = previewMode.isActive
        ? null
        : DateTime.tryParse(
            ref.read(supabaseClientProvider).auth.currentUser?.createdAt ?? '',
          )?.toLocal();
    final previewCurrentCycle = financialCycleStartForDate(
      now,
      startDay: financialStartDay,
    );
    final previewFirstCycle = addFinancialCycles(
      previewCurrentCycle,
      -5,
      startDay: financialStartDay,
    );
    final previewFutureCycle = addFinancialCycles(
      previewCurrentCycle,
      1,
      startDay: financialStartDay,
    );
    final visiblePeriods = ref.watch(homePeriodVisiblePeriodsProvider);
    final periodsToLoad = visiblePeriods.isEmpty
        ? homePeriodItems(
            mode: state.mode,
            selectedDate: now,
            now: now,
            financialMonthStartDay: financialStartDay,
          )
        : visiblePeriods;
    final statusByPeriod = <DateTime, DatePeriodRingStatus>{};

    if (state.mode == HomePeriodMode.monthly) {
      for (final period in periodsToLoad) {
        if (!isHomePeriodSelectable(
          period,
          mode: HomePeriodMode.monthly,
          now: now,
          financialMonthStartDay: financialStartDay,
        )) {
          continue;
        }
        if (previewMode.isActive) {
          statusByPeriod[period] = _statusForProgress(
            context,
            PreviewMockData.dashboardBudgetProgressForPeriod(
              period,
              currentPeriod: previewCurrentCycle,
            ),
          );
          continue;
        }
        final pockets = ref.watch(pocketsProvider(_scopeParams(
          scope: scope,
          period: period,
          currency: currency,
          selectedCurrencies: selectedCurrencies,
          financialMonthStartDay: financialStartDay,
          includeUpcomingRecurring: includeRecurring,
          isBootstrapCurrency: isBootstrapCurrency,
        )));
        final ratio = pockets.totalBudget <= 0
            ? 0.0
            : pockets.totalSpent / pockets.totalBudget;
        statusByPeriod[period] = _statusForProgress(context, ratio);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: DatePeriodSelector(
        mode: state.mode,
        selectedDate: state.selectedDate,
        now: now,
        financialMonthStartDay: financialStartDay,
        statusForPeriod: state.mode == HomePeriodMode.monthly
            ? (period) =>
                statusByPeriod[period] ?? _statusForProgress(context, 0)
            : null,
        minimumAvailableDate:
            previewMode.isActive ? previewFirstCycle : accountCreatedAt,
        // Use financial-cycle boundaries rather than calendar-day offsets.
        // Otherwise, a future cycle beginning after today's day-of-month is
        // incorrectly marked unavailable for users with custom cycle starts.
        maximumAvailableDate: previewMode.isActive
            ? financialCycleForMonth(
                previewFutureCycle,
                startDay: financialStartDay,
              ).end
            : null,
        ringAnimationRevision: _ringAnimationRevision,
        onVisiblePeriodsChanged: (periods) {
          ref.read(homePeriodVisiblePeriodsProvider.notifier).state = periods;
        },
        onDateSelected: (date) {
          HapticFeedback.selectionClick();
          ref.read(homePeriodSelectionProvider(userId).notifier).select(date);
        },
      ),
    );
  }

  DatePeriodRingStatus _statusForProgress(BuildContext context, double value) {
    final progress = value.clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
    // This is budget consumption, not task completion. A low spend is healthy;
    // urgency increases as the user approaches their budget limit.
    final color = progress < 0.5
        ? colors.success
        : progress < 0.75
            ? colors.warning
            : progress < 0.9
                ? colors.progressOrange
                : colors.error;
    return DatePeriodRingStatus(
      progress: progress,
      color: color,
      percentage: (progress * 100).round(),
    );
  }

  PocketsScopeParams _scopeParams({
    required HouseholdScope scope,
    required DateTime period,
    required String? currency,
    required List<String>? selectedCurrencies,
    required int financialMonthStartDay,
    required bool includeUpcomingRecurring,
    required bool isBootstrapCurrency,
  }) {
    final scopeType = switch (scope.activeAccountType) {
      ActiveWalletType.personal => PocketsScopeType.personal,
      ActiveWalletType.portfolio => PocketsScopeType.portfolio,
      ActiveWalletType.household => PocketsScopeType.household,
    };
    return buildHomePeriodPocketsScopeParams(
      scopeType: scopeType,
      householdId: scopeType == PocketsScopeType.personal
          ? null
          : scope.activeAccountHouseholdId,
      period: period,
      currency: currency,
      selectedCurrencies: selectedCurrencies,
      financialMonthStartDay: financialMonthStartDay,
      includeUpcomingRecurring: includeUpcomingRecurring,
      isBootstrapCurrency: isBootstrapCurrency,
    );
  }
}

PocketsScopeParams buildHomePeriodPocketsScopeParams({
  required PocketsScopeType scopeType,
  required String? householdId,
  required DateTime period,
  required String? currency,
  required List<String>? selectedCurrencies,
  required int financialMonthStartDay,
  required bool includeUpcomingRecurring,
  required bool isBootstrapCurrency,
}) {
  return PocketsScopeParams(
    scope: scopeType,
    householdId: householdId,
    periodMonth: period,
    currency: currency,
    selectedCurrencies: selectedCurrencies,
    financialMonthStartDay: financialMonthStartDay,
    isBootstrapCurrency: isBootstrapCurrency,
    includeUpcomingRecurring: includeUpcomingRecurring,
  );
}
