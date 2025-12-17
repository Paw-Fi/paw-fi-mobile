import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'main_menu_screen.dart';

/// Main navigation shell with bottom navigation bar
class MainShell extends HookConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainShellTabIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final pages = [
      const HomePage(),
      const RecurringTransactionsPage(),
      const PocketsPage(),
      const AnalyticsPage(),
    ];

    // Keep the HomePage mounted so its listener can respond to widget launches
    // even when another tab is selected. Also auto-switch to Overview on a widget action.
    // Keep the HomePage mounted so its listener can respond to widget launches
    // even when another tab is selected. Also auto-switch to Overview on a widget action.
    ref.listen<WidgetLaunchEvent>(widgetLaunchProvider, (previous, next) {
      if (next.type == WidgetLaunchActionType.textInput ||
          next.type == WidgetLaunchActionType.cameraInput) {
        // Quick actions stay on Overview (index 0) as before.
        if (ref.read(mainShellTabIndexProvider) != 0) {
          ref.read(mainShellTabIndexProvider.notifier).state = 0;
        }
      } else if (next.type == WidgetLaunchActionType.openPockets) {
        // Any tap on the widget surface should open the Pockets tab.
        if (ref.read(mainShellTabIndexProvider) != 2) {
          ref.read(mainShellTabIndexProvider.notifier).state = 2;
        }
        // Reset state
        ref.read(widgetLaunchProvider.notifier).state =
            const WidgetLaunchEvent();
      } else if (next.type == WidgetLaunchActionType.configure) {
        final widgetIdStr = next.params?['widgetId'];
        if (widgetIdStr != null) {
          final widgetId = int.tryParse(widgetIdStr);
          if (widgetId != null) {
            _showWidgetConfigurationDialog(context, ref, widgetId);
          }
        }
        // Reset state
        ref.read(widgetLaunchProvider.notifier).state =
            const WidgetLaunchEvent();
      }
    });

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
                ? CupertinoIcons.creditcard
                : Icons.account_balance_wallet_outlined,
            label: context.l10n.pockets,
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
