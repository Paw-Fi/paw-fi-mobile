import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

import 'package:moneko/features/home/presentation/pages/home_page.dart';
import 'package:moneko/features/insights/presentation/pages/insights_page.dart';
import 'package:moneko/features/recurring/pages/recurring_transactions_page.dart';
import 'package:moneko/features/pockets/presentation/pages/pockets_page.dart';
import 'package:moneko/features/home/presentation/widgets/home_header_sliver.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'package:moneko/features/home/presentation/services/widget_sync_manager.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/core/navigation/navigation_ready_provider.dart';
import 'package:moneko/core/notifications/notification_dispatcher.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/accounts/presentation/pages/accounts_page.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';

/// Main navigation shell with bottom navigation bar
class MainShell extends HookConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainShellTabIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final previewState = ref.watch(previewModeProvider);
    final subscriptionGateStatus = ref.watch(subscriptionGateStatusProvider);
    final showSubscriptionVerificationBanner =
        subscriptionGateStatus == SubscriptionGateStatus.graceActive ||
            subscriptionGateStatus == SubscriptionGateStatus.unknown;

    Future<void> clearPreviewDataCaches() async {
      // Always reset shell navigation first.
      ref.read(mainShellTabIndexProvider.notifier).state = 0;

      // Reset launch intent state.
      ref.read(widgetLaunchProvider.notifier).state = const WidgetLaunchEvent();

      // Reset view/scope state.
      ref.read(viewModeProvider.notifier).setPersonalMode();
      await ref.read(selectedHouseholdProvider.notifier).clearSelection();

      // Invalidate providers that can surface preview mock data so the app
      // reloads clean state after exiting preview.
      ref.invalidate(selectedHouseholdProvider);
      ref.invalidate(selectedHouseholdIdProvider);
      ref.invalidate(selectedHouseholdObjectProvider);
      ref.invalidate(userHouseholdsProvider);
      ref.invalidate(householdProvider);
      ref.invalidate(householdMembersProvider);
      ref.invalidate(householdBudgetsProvider);
      ref.invalidate(householdInvitesProvider);
      ref.invalidate(householdExpensesProvider);
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(homeFilterProvider);
      ref.invalidate(analyticsProvider);
      ref.invalidate(currencyTransactionCountsProvider);
      ref.invalidate(recurringTransactionsProvider);
      ref.invalidate(pocketsProvider);
      ref.invalidate(scopedAccountsProvider);
    }

    Future<String?> exitPreviewMode(
        {required bool restorePreauthOnExit}) async {
      final prefs = ref.read(sharedPreferencesProvider);
      final exitRoute = prefs.getString(kPreviewExitRouteKey);
      final returnToPreauth =
          prefs.getBool(kPreviewReturnToPreauthKey) ?? false;
      await prefs.setBool(kPreviewModeActiveKey, false);
      await prefs.setBool(kPreviewReturnToPreauthKey, false);
      await prefs.remove(kPreviewExitRouteKey);
      ref.read(previewModeProvider.notifier).disable();
      await clearPreviewDataCaches();
      if (exitRoute != null && exitRoute.isNotEmpty) {
        return exitRoute;
      }
      if (restorePreauthOnExit && returnToPreauth) {
        return '/onboarding?stage=save_budget';
      }
      return null;
    }

    // One-time native notification prompt logic & listeners
    useEffect(() {
      var disposed = false;
      final navigationReadyController =
          ref.read(navigationReadyProvider.notifier);
      final dispatcher = ref.read(notificationDispatcherProvider);
      final widgetLaunchNotifier = ref.read(widgetLaunchProvider.notifier);
      final tabController = ref.read(mainShellTabIndexProvider.notifier);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!disposed) {
          navigationReadyController.state = true;
        }
      });

      Future<void> maybePromptForNotifications() async {
        final user = ref.read(authProvider);
        if (user.uid.isEmpty) return;
        try {
          final prefs = ref.read(sharedPreferencesProvider);
          final promptedKey = 'notifications_prompted:${user.uid}';
          final prompted = prefs.getBool(promptedKey) ?? false;
          final deviceSvc = ref.read(deviceRegistrationServiceProvider);
          final isRegistered = await deviceSvc.isRegistered();

          if (!isRegistered && !prompted) {
            await prefs.setBool(promptedKey, true);
            try {
              await deviceSvc.initialize();
            } catch (_) {}
          }
        } catch (_) {}
      }

      unawaited(() async {
        await maybePromptForNotifications();
        // ignore: discarded_futures
        dispatcher.replayPendingIntents();
      }());

      final ProviderSubscription<AppUser> authSubscription =
          ref.listenManual<AppUser>(authProvider, (previous, next) {
        if (next.uid.isNotEmpty) {
          // ignore: discarded_futures
          dispatcher.replayPendingIntents();
        }
      });

      final ProviderSubscription<WidgetLaunchEvent> widgetLaunchSubscription =
          ref.listenManual<WidgetLaunchEvent>(
        widgetLaunchProvider,
        (previous, next) {
          if (next == previous) return;

          if (next.type == WidgetLaunchActionType.textInput ||
              next.type == WidgetLaunchActionType.cameraInput) {
            if (ref.read(mainShellTabIndexProvider) != 0) {
              tabController.state = 0;
            }
          } else if (next.type == WidgetLaunchActionType.openPockets) {
            if (ref.read(mainShellTabIndexProvider) != 2) {
              tabController.state = 2;
            }
            widgetLaunchNotifier.state = const WidgetLaunchEvent();
          } else if (next.type == WidgetLaunchActionType.configure) {
            final widgetIdStr = next.params?['widgetId'];
            if (widgetIdStr != null) {
              final widgetId = int.tryParse(widgetIdStr);
              if (widgetId != null && context.mounted) {
                _showWidgetConfigurationDialog(context, ref, widgetId);
              }
            }
            widgetLaunchNotifier.state = const WidgetLaunchEvent();
          }
        },
      );

      return () {
        disposed = true;
        authSubscription.close();
        widgetLaunchSubscription.close();
        Future<void>.microtask(() {
          try {
            navigationReadyController.state = false;
          } catch (_) {}
        });
      };
    }, const []);

    final pages = [
      const HomePage(),
      const RecurringTransactionsPage(),
      const PocketsPage(),
      const AccountsPage(),
      const AnalyticsPage(),
    ];

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
          useNativeToolbar: false,
          appBar: AppBar(
            leadingWidth: 0,
            leading: const SizedBox.shrink(),
            titleSpacing: 0,
            toolbarHeight: 0,
          )),
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              if (previewState.isActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _PreviewModeBanner(
                    currentIndex: currentIndex,
                    onRegisterTap: () {
                      unawaited(() async {
                        await exitPreviewMode(restorePreauthOnExit: false);
                        if (context.mounted) {
                          context.go('/register');
                        }
                      }());
                    },
                    onExitTap: () {
                      unawaited(() async {
                        final returnRoute = await exitPreviewMode(
                          restorePreauthOnExit: true,
                        );
                        if (context.mounted) {
                          context.go(returnRoute ?? '/paywall');
                        }
                      }());
                    },
                  ),
                ),
              if (!previewState.isActive && showSubscriptionVerificationBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _SubscriptionVerificationBanner(
                    status: subscriptionGateStatus,
                    onRetryTap: () {
                      unawaited(ref
                          .read(subscriptionNotifierProvider.notifier)
                          .refresh());
                    },
                    onManageTap: () {
                      context.push('/paywall?mode=resubscribe');
                    },
                  ),
                ),
              const HomeHeaderSliver(),
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 0.0),
                      child: IndexedStack(
                        index: currentIndex,
                        children: pages,
                      ),
                    ),
                    const WidgetSyncManager(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: false,
        items: [
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS
                ? CupertinoIcons.square_grid_2x2_fill
                : Icons.dashboard,
            label: context.l10n.overview,
          ),
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS ? CupertinoIcons.repeat : Icons.repeat,
            label: context.l10n.recurring,
          ),
          AdaptiveNavigationDestination(
  icon: PlatformInfo.isIOS
      ? CupertinoIcons.chart_pie
      : Icons.pie_chart_outline,
  label: context.l10n.budget,
),
AdaptiveNavigationDestination(
  icon: PlatformInfo.isIOS
      ? CupertinoIcons.creditcard
      : Icons.account_balance_wallet_outlined,
  label: "Wallets",
),
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS
                ? CupertinoIcons.chart_bar_alt_fill
                : Icons.bar_chart,
            label: context.l10n.insights,
          ),
        ],
        selectedIndex: currentIndex,
        onTap: (index) {
          ref.read(mainShellTabIndexProvider.notifier).state = index;
        },
      ),
    );
  }

  void _showWidgetConfigurationDialog(
      BuildContext context, WidgetRef ref, int widgetId) {
    showDialog(
      context: context,
      builder: (context) => _WidgetConfigurationDialog(widgetId: widgetId),
    );
  }
}

class _SubscriptionVerificationBanner extends StatelessWidget {
  const _SubscriptionVerificationBanner({
    required this.status,
    required this.onRetryTap,
    required this.onManageTap,
  });

  final SubscriptionGateStatus status;
  final VoidCallback onRetryTap;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGraceAccess = status == SubscriptionGateStatus.graceActive;
    final title = isGraceAccess
        ? 'You are in offline grace access'
        : 'We can’t verify your subscription right now';
    final subtitle = isGraceAccess
        ? 'Your previous active subscription is kept for up to 72 hours while we reconnect.'
        : 'You still have full access while we retry in the background. Your subscription is not removed.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.warning,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: colorScheme.foreground,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: colorScheme.onPrimary,
                  backgroundColor: colorScheme.warning,
                  minimumSize: const Size(0, 34),
                ),
                onPressed: onRetryTap,
                child: const Text('Retry now'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.foreground,
                  side: BorderSide(color: colorScheme.border),
                  minimumSize: const Size(0, 34),
                ),
                onPressed: onManageTap,
                child: const Text('Manage plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewModeBanner extends StatefulWidget {
  const _PreviewModeBanner({
    required this.onRegisterTap,
    required this.onExitTap,
    required this.currentIndex,
  });

  final VoidCallback onRegisterTap;
  final VoidCallback onExitTap;
  final int currentIndex;

  @override
  State<_PreviewModeBanner> createState() => _PreviewModeBannerState();
}

class _PreviewModeBannerState extends State<_PreviewModeBanner> {
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant _PreviewModeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && _expanded) {
      setState(() {
        _expanded = false;
      });
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = Text(
      'Preview mode is on · Demo data only',
      style: TextStyle(
        color: colorScheme.warning,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.warningSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.warningBorder),
      ),
      child: _expanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: title),
                                IconButton(
                                  icon: Icon(
                                    _expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: colorScheme.warning,
                                  ),
                                  onPressed: _toggle,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            Text(
                              'Your progress won’t be saved. Create an account to keep your changes.',
                              style: TextStyle(
                                color: colorScheme.foreground,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                foregroundColor: colorScheme.onPrimary,
                                backgroundColor: colorScheme.warning,
                              ),
                              onPressed: widget.onExitTap,
                              child: const Text('Exit tour'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Preview Mode - Data won\'t be saved',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onExitTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.warning,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Exit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.expand_more,
                    color: colorScheme.warning,
                    size: 20,
                  ),
                  onPressed: _toggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
    );
  }
}

class _WidgetConfigurationDialog extends HookConsumerWidget {
  final int widgetId;

  const _WidgetConfigurationDialog({required this.widgetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final availableCurrencies = ref.watch(availableCurrenciesProvider);

    final selectedScope = useState<String>('personal');
    final selectedCurrency = useState<String>('USD');

    return AlertDialog(
      title: Text(context.l10n.configureWidgetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scope Selector
          DropdownButtonFormField<String>(
            initialValue: selectedScope.value,
            decoration: InputDecoration(
              labelText: context.l10n.widgetHouseholdLabel,
            ),
            items: [
              DropdownMenuItem(
                value: 'personal',
                child: Text(context.l10n.personalScope),
              ),
              ...?householdsAsync.valueOrNull?.map((h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name),
                  )),
            ],
            onChanged: (value) {
              if (value != null) selectedScope.value = value;
            },
          ),
          const SizedBox(height: 16),
          // Currency Selector
          DropdownButtonFormField<String>(
            initialValue: selectedCurrency.value,
            decoration: InputDecoration(
              labelText: context.l10n.currencyLabel,
            ),
            items: (availableCurrencies.isNotEmpty
                    ? availableCurrencies
                    : ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'])
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) selectedCurrency.value = value;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            await WidgetService().saveWidgetConfiguration(
              widgetId: widgetId,
              scopeId: selectedScope.value,
              currency: selectedCurrency.value,
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
