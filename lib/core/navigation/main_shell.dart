import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
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
      const AnalyticsPage(),
      const PocketsPage(),
    ];

    final currentPage = pages[currentIndex.value];

    return AdaptiveScaffold(
      body: ZoomDrawer(
        controller: zoomController,
        menuScreen: const MainMenuScreen(),
        mainScreen: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    ImpersonationBanner(),
                    HomeHeaderSliver(),
                  ],
                ),
              ),
              Expanded(child: currentPage),
            ],
          ),
        ),
        borderRadius: 24.0,
        showShadow: true,
        angle: -12.0,
        mainScreenTapClose: true,
        menuBackgroundColor: colorScheme.appBackground,
        drawerShadowsBackgroundColor: Colors.black.withOpacity(0.2),
        slideWidth: MediaQuery.of(context).size.width * 0.85,
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
                ? 'chart.bar.fill'
                : PlatformInfo.isIOS
                    ? CupertinoIcons.chart_bar_alt_fill
                    : Icons.bar_chart,
            label: context.l10n.insights,
          ),
          AdaptiveNavigationDestination(
            icon: PlatformInfo.isIOS26OrHigher()
                ? 'wallet.pass'
                : PlatformInfo.isIOS
                    ? CupertinoIcons.creditcard
                    : Icons.account_balance_wallet_outlined,
            label: 'Pockets',
          ),
        ],
        selectedIndex: currentIndex.value,
        onTap: (index) {
          debugPrint('🔄 Switching to index $index');
          currentIndex.value = index;
        },
      ),
    );
  }
}
