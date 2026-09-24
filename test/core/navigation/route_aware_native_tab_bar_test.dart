import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/navigation/route_aware_native_tab_bar.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/text_input_drawer.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: '', email: '');
}

class _NativeTabBarProbe extends StatefulWidget {
  const _NativeTabBarProbe();

  @override
  State<_NativeTabBarProbe> createState() => _NativeTabBarProbeState();
}

class _NativeTabBarProbeState extends State<_NativeTabBarProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 72);
}

void main() {
  testWidgets('modal drawer hides the native bar host and leaves input usable',
      (tester) async {
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
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () =>
                          showTextInputDrawer(context, (text, target) async {}),
                      child: const Text('Open drawer'),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RouteAwareNativeTabBar(
                    builder: _buildTabBar,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final nativeBarState = tester.state(find.byType(_NativeTabBarProbe));
    final offstage = find.byKey(
      const ValueKey('route-aware-native-tab-bar-offstage'),
      skipOffstage: false,
    );
    expect(tester.widget<Offstage>(offstage).offstage, isFalse);

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    expect(tester.widget<Offstage>(offstage).offstage, isTrue);
    expect(find.byType(_NativeTabBarProbe), findsNothing);
    expect(
        find.byType(_NativeTabBarProbe, skipOffstage: false), findsOneWidget);

    const drawerInput = ValueKey('textField');
    await tester.tap(find.byKey(drawerInput));
    await tester.enterText(find.byKey(drawerInput), 'Coffee');
    expect(find.text('Coffee'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<Offstage>(offstage).offstage, isFalse);
    expect(tester.state(find.byType(_NativeTabBarProbe)), same(nativeBarState));
  });
}

Widget _buildTabBar(bool isTopRoute) => const _NativeTabBarProbe();
