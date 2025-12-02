import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/navigation/custom_drawer.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/navigation/zoom_drawer_provider.dart';
import 'package:moneko/features/auth/presentation/widgets/impersonation_banner.dart';
import 'package:moneko/features/home/presentation/pages/home_page.dart';
import 'package:moneko/features/home/presentation/widgets/home_header_sliver.dart';
import 'package:moneko/features/insights/presentation/pages/insights_page.dart';
import 'package:moneko/features/recurring/pages/recurring_transactions_page.dart';
import 'package:moneko/features/pockets/presentation/pages/pockets_page.dart';
import 'package:moneko/features/home/presentation/state/widget_launch_provider.dart';
import 'main_menu_screen.dart';

/// Main navigation shell with bottom navigation bar
class MainShell extends HookConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = useState(0);
    final colorScheme = Theme.of(context).colorScheme;
    final zoomController = ref.read(zoomDrawerControllerProvider);

    final pages = [
      const HomePage(),
      const RecurringTransactionsPage(),
      const PocketsPage(),
      const AnalyticsPage(),
    ];

    // Keep the HomePage mounted so its listener can respond to widget launches
    // even when another tab is selected. Also auto-switch to Overview on a widget action.
    ref.listen<WidgetLaunchAction>(widgetLaunchProvider, (previous, next) {
      if (next == WidgetLaunchAction.textInput ||
          next == WidgetLaunchAction.cameraInput) {
        if (currentIndex.value != 0) {
          currentIndex.value = 0;
        }
      }
    });

    final currentPage = pages[currentIndex.value];

    return CustomDrawer(
      controller: zoomController,
      menuScreen: const MainMenuScreen(),
      borderRadius: 24.0,
      showShadow: false,
      angle: 0,
      menuBackgroundColor: colorScheme.drawerBackground,
      drawerShadowsBackgroundColor: Colors.black.withOpacity(0.2),
      slideWidth: MediaQuery.of(context).size.width * 0.75,
      menuScreenWidth: MediaQuery.of(context).size.width * 0.75,
      mainScreen: AdaptiveScaffold(
                appBar: AdaptiveAppBar(
            useNativeToolbar: false,
            cupertinoNavigationBar: const CupertinoNavigationBar(
              leading: HomeHeaderSliver(),           
            ),
            appBar: AppBar(
              leadingWidth: 0,
              leading: const SizedBox.shrink(),
              titleSpacing: 0,
              toolbarHeight: 65,
              title: const HomeHeaderSliver(),
            )),
        body: Material(
          color: colorScheme.appBackground,
          child: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: IndexedStack(
              index: currentIndex.value,
              children: pages,
            ),
          ),
        ),
        bottomNavigationBar: AdaptiveBottomNavigationBar(
          useNativeBottomBar: true,
          items: [
            AdaptiveNavigationDestination(
              icon: PlatformInfo.isIOS26OrHigher()
                  ? 'square.grid.2x2.fill'
                  : PlatformInfo.isIOS
                      ? CupertinoIcons.square_grid_2x2_fill
                      : Icons.dashboard,
              label: context.l10n.overview,
            ),
            AdaptiveNavigationDestination(
              icon: PlatformInfo.isIOS26OrHigher()
                  ? 'repeat'
                  : PlatformInfo.isIOS
                      ? CupertinoIcons.repeat
                      : Icons.repeat,
              label: context.l10n.recurring,
            ),
            AdaptiveNavigationDestination(
              icon: PlatformInfo.isIOS26OrHigher()
                  ? 'wallet.pass'
                  : PlatformInfo.isIOS
                      ? CupertinoIcons.creditcard
                      : Icons.account_balance_wallet_outlined,
              label: context.l10n.pockets,
            ),
            AdaptiveNavigationDestination(
              icon: PlatformInfo.isIOS26OrHigher()
                  ? 'chart.bar.fill'
                  : PlatformInfo.isIOS
                      ? CupertinoIcons.chart_bar_alt_fill
                      : Icons.bar_chart,
              label: context.l10n.insights,
            ),
          ],
          selectedIndex: currentIndex.value,
          onTap: (index) {
            debugPrint('🔄 Switching to index $index');
            currentIndex.value = index;
          },
        ),
      ),
    );
  }
}
