import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moneko/core/navigation/route_aware_native_tab_bar.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/text_input_drawer.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: '', email: '');
}

class _NativeTabBarDrawerHarness extends StatelessWidget {
  const _NativeTabBarDrawerHarness();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showTextInputDrawer(
                context,
                (text, target) async {},
              ),
              child: const Text('Open text drawer'),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RouteAwareNativeTabBar(
            builder: (isTopRoute) => IOS26NativeTabBar(
              key: const ValueKey('ios26-native-tab-bar'),
              destinations: const [
                AdaptiveNavigationDestination(
                    icon: 'house.fill', label: 'Home'),
                AdaptiveNavigationDestination(
                    icon: 'repeat', label: 'Recurring'),
              ],
              selectedIndex: 0,
              onTap: (_) {},
              showNativeView: true,
              hidden: !isTopRoute,
            ),
          ),
        ),
      ],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native iOS tab bar does not cover the text input drawer',
      (tester) async {
    expect(Platform.isIOS, isTrue);
    expect(PlatformInfo.isIOS26OrHigher(), isTrue);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuth.new),
          sharedPreferencesProvider.overrideWithValue(preferences),
          householdScopeProvider.overrideWithValue(const HouseholdScope(
            viewMode: ViewMode.personal,
            selected: SelectedHouseholdState(),
            portfolioHouseholdIds: {},
          )),
          walletsByHouseholdIdProvider(null).overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _NativeTabBarDrawerHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nativeViewState = tester.state(find.byType(UiKitView));
    await tester.tap(find.text('Open text drawer'));
    await tester.pumpAndSettle();

    final offstage = find.byKey(
      const ValueKey('route-aware-native-tab-bar-offstage'),
      skipOffstage: false,
    );
    expect(tester.widget<Offstage>(offstage).offstage, isTrue);
    expect(find.byType(IOS26NativeTabBar), findsNothing);
    expect(find.byType(IOS26NativeTabBar, skipOffstage: false), findsOneWidget);

    const drawerInput = ValueKey('textField');
    await tester.tap(find.byKey(drawerInput));
    await tester.enterText(find.byKey(drawerInput), 'Coffee');
    expect(find.text('Coffee'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<Offstage>(offstage).offstage, isFalse);
    expect(tester.state(find.byType(UiKitView)), same(nativeViewState));
  });
}
