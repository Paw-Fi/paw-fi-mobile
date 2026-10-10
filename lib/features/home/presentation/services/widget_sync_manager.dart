import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/services/home_widget_snapshot.dart';
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/core/sync/ios_siri_transaction_defaults_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

String normalizeWidgetSyncCurrency(String? currency) =>
    normalizeHomeWidgetCurrency(currency);

List<String> normalizeWidgetSyncSelectedCurrencies({
  required String selectedCurrency,
  List<String>? selectedCurrencies,
}) {
  final currencies = {
    normalizeWidgetSyncCurrency(selectedCurrency),
    ...?selectedCurrencies
        ?.map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty),
  }.toList()
    ..sort();
  return currencies;
}

/// Uses the same resolved month source as Home. Widget synchronization must not
/// independently interpret RPC fields, forecast rules, or foreign budgets.
HomeWidgetSnapshot? buildHomeWidgetSnapshot({
  required String userId,
  required PocketsState state,
  List<WidgetPocketData>? topCategories,
}) {
  if (!state.hasDisplayData || state.hasChanges) return null;
  // Pocket's offline-without-cache state reserves a month but has no known
  // budget. It must not erase a trustworthy native snapshot with zeroes.
  if (state.nativeBudgetByCurrency.isEmpty &&
      state.budgetId == null &&
      state.saved.isEmpty &&
      state.savedTotalBudget == 0) {
    return null;
  }
  if (!state.totalSpent.isFinite ||
      !state.savedTotalBudget.isFinite ||
      state.saved.any((pocket) =>
          !pocket.spent.isFinite || !pocket.availableBudget.isFinite)) {
    return null;
  }
  return HomeWidgetSnapshot(
    userId: userId,
    currency: state.currency,
    periodMonth: state.periodMonth.toIso8601String().substring(0, 10),
    totalSpent: state.totalSpent,
    totalBudget: state.savedTotalBudget,
    pockets: state.saved
        .map((pocket) => WidgetPocketData(
              id: pocket.id,
              name: pocket.name,
              spent: pocket.spent,
              budget: pocket.availableBudget,
              color: pocket.color ?? '#7458FF',
              currency: pocket.currency,
              icon: pocket.icon,
            ))
        .toList(growable: false),
    topCategories: topCategories,
  );
}

class WidgetSyncManager extends HookConsumerWidget {
  const WidgetSyncManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(iosSiriTransactionDefaultsSyncProvider);
    final user = ref.watch(authProvider);
    final appInit = ref.watch(appInitializationV2Provider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final households = householdsAsync.valueOrNull;
    final walletHeaders = ref.watch(walletAuthHeadersProvider);
    final wallets = <String, AsyncValue<List<WalletEntity>>>{};
    if (user.uid.isNotEmpty && walletHeaders != null && households != null) {
      wallets['personal'] =
          ref.watch(shortcutDestinationWalletsByHouseholdIdProvider(null));
      for (final household in households) {
        wallets[household.id] = ref.watch(
            shortcutDestinationWalletsByHouseholdIdProvider(household.id));
      }
    }
    final catalogReady =
        wallets.isNotEmpty && wallets.values.every((item) => item.hasValue);
    final catalogSignature = wallets.entries
        .expand((entry) => (entry.value.valueOrNull ?? const <WalletEntity>[])
            .map((wallet) =>
                '${entry.key}:${wallet.id}:${wallet.name}:${wallet.currency}'))
        .join('|');
    useEffect(() {
      if (!catalogReady || households == null || user.uid.isEmpty) return null;
      unawaited(WidgetService().saveConfigurationOptions(
        userId: user.uid,
        households: [
          {'id': 'personal', 'name': 'Personal', 'isPortfolio': false},
          ...households.map((item) => {
                'id': item.id,
                'name': item.name,
                'isPortfolio': item.isPortfolio
              }),
        ],
        wallets: wallets.entries
            .expand((entry) =>
                (entry.value.valueOrNull ?? const <WalletEntity>[])
                    .map((wallet) => {
                          'id': wallet.id,
                          'name': wallet.name,
                          'spaceId': entry.key,
                          'currency': wallet.currency.trim().toUpperCase(),
                        }))
            .toList(growable: false),
      ));
      return null;
    }, [user.uid, catalogReady, catalogSignature, households]);

    final financialDay = ref.watch(financialMonthStartDayStateProvider);
    final currency = normalizeWidgetSyncCurrency(
        ref.watch(selectedHomeCurrencyCodeProvider));
    final currencies = normalizeWidgetSyncSelectedCurrencies(
      selectedCurrency: currency,
      selectedCurrencies: ref.watch(homeFilterProvider
          .select((state) => state.normalizedSelectedCurrencies)),
    );
    final includeRecurring =
        ref.watch(includeUpcomingRecurringInPocketsProvider);
    // A bounded foreground tick covers midnight and recovery from transient
    // failures even when no other watched financial value changes.
    final now = useState(DateTime.now());
    useEffect(() {
      final timer = Timer.periodic(
          const Duration(minutes: 1), (_) => now.value = DateTime.now());
      return timer.cancel;
    }, const []);
    final userNow = now.value.toUtc().add(Duration(
        minutes: resolveUserTimezoneOffsetMinutes(
            appInit.data?.user?.preferredTimezone)));
    final range =
        financialCycleForDate(userNow, startDay: financialDay.valueOrNull ?? 1);
    final month = range.start;
    final refreshContext = {
      'userId': user.uid,
      'currency': currency,
      'currencies': currencies,
      'scopes': {
        'personal': 'personal',
        ...?households?.asMap().map((_, item) =>
            MapEntry(item.id, item.isPortfolio ? 'portfolio' : 'household')),
      },
      'timezone': appInit.data?.user?.preferredTimezone,
      'timezoneOffsetMinutes': resolveUserTimezoneOffsetMinutes(
          appInit.data?.user?.preferredTimezone),
      'financialMonthStartDay': financialDay.valueOrNull,
      'includeRecurring': includeRecurring,
      'locale': Intl.getCurrentLocale(),
    };
    final refreshSignature = jsonEncode(refreshContext);
    useEffect(() {
      if (!appInit.isReady ||
          !financialDay.hasValue ||
          households == null ||
          user.uid.isEmpty ||
          ref.read(previewModeProvider).isActive) {
        return null;
      }
      unawaited(WidgetService()
          .saveBackgroundRefreshContext(refreshContext)
          .catchError((Object error) {
        debugPrint('Widget refresh configuration failed: ${error.runtimeType}');
      }));
      return null;
    }, [refreshSignature, appInit.isReady]);

    if (!appInit.isReady ||
        user.uid.isEmpty ||
        households == null ||
        !financialDay.hasValue ||
        ref.watch(previewModeProvider).isActive) {
      return const SizedBox.shrink();
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final scope in [
        const ('personal', PocketsScopeType.personal),
        ...households.map((item) => (
              item.id,
              item.isPortfolio
                  ? PocketsScopeType.portfolio
                  : PocketsScopeType.household
            )),
      ])
        _WidgetScopeSync(
          key: ValueKey(
              '${user.uid}:${scope.$1}:$currency:${currencies.join(',')}:$month:$includeRecurring'),
          userId: user.uid,
          scopeId: scope.$1,
          params: PocketsScopeParams(
            scope: scope.$2,
            householdId: scope.$1 == 'personal' ? null : scope.$1,
            periodMonth: month,
            currency: currency,
            selectedCurrencies: currencies,
            financialMonthStartDay: financialDay.valueOrNull!,
            includeUpcomingRecurring: includeRecurring,
            isBootstrapCurrency: false,
          ),
          rangeEnd: range.end,
          tick: now.value,
        ),
    ]);
  }
}

class _WidgetScopeSync extends HookConsumerWidget {
  const _WidgetScopeSync(
      {super.key,
      required this.userId,
      required this.scopeId,
      required this.params,
      required this.rangeEnd,
      required this.tick});
  final String userId;
  final String scopeId;
  final PocketsScopeParams params;
  final DateTime rangeEnd;
  final DateTime tick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(params));
    final categories =
        ref.watch(budgetCompanionPeriodSummaryProvider(DashboardScopeQuery(
      userId: userId,
      householdId: params.householdId,
      selectedCurrency: params.currency,
      selectedCurrencies: params.selectedCurrencies,
      startDate: params.periodMonth,
      endDate: rangeEnd,
    )));
    final topCategories = categories.valueOrNull?.categorySummaries
        .where((item) => item.amount > 0)
        .toList()
      ?..sort((a, b) => b.amount.compareTo(a.amount));
    final snapshot = state.currency != params.currency ||
            state.periodMonth != params.periodMonth
        ? null
        : buildHomeWidgetSnapshot(
            userId: userId,
            state: state,
            topCategories: topCategories?.take(4).map((item) {
              final color = getCategoryColor(item.category);
              final hex = '#${[
                color.r,
                color.g,
                color.b
              ].map((value) => (value * 255).round().toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
              return WidgetPocketData(
                  id: item.category,
                  name: item.category,
                  spent: item.amount,
                  budget: 0,
                  color: hex,
                  currency: params.currency,
                  icon: item.category);
            }).toList(growable: false),
          );
    final signature = snapshot == null ? null : jsonEncode(snapshot.toJson());
    final published = useRef<String?>(null);
    final mutationRevision = ref.watch(widgetSyncVersionProvider);
    useEffect(() {
      if (snapshot == null || signature == published.value) return null;
      var disposed = false;
      Future<void>(() async {
        try {
          bool isCurrent() => !disposed && ref.read(authProvider).uid == userId;
          final service = WidgetService();
          // Retry a failed initial owner transport together with publication.
          await service.synchronizeOwner(userId, isCurrent: isCurrent);
          final saved = await service.publishSnapshot(
            scopeId: scopeId,
            snapshot: snapshot,
            isCurrent: isCurrent,
          );
          if (saved && !disposed) published.value = signature;
        } catch (error) {
          debugPrint('Home widget publication failed: ${error.runtimeType}');
        }
      });
      return () => disposed = true;
    }, [signature, tick, mutationRevision]);
    // Keep committed transaction revisions subscribed: canonical Pocket state
    // overlays local mutations and owns all transaction/dashboard invalidation.
    ref.watch(localTransactionRevisionProvider);
    return const SizedBox.shrink();
  }
}
