import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_order_provider.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_account_stack.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_stack_card.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const scope = (userId: 'u1', householdId: null, isPreview: false);
WalletEntity wallet(String id) => WalletEntity(
      id: id,
      userId: 'u1',
      householdId: null,
      name: id,
      icon: 'wallet',
      color: '#6B7280',
      openingBalanceCents: 1000,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 1000,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ProviderContainer> pumpStack(WidgetTester tester,
      {bool dark = false,
      List<String> ids = const ['a', 'b', 'c'],
      ValueChanged<WalletEntity>? onOpen}) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(16),
          child: WalletAccountStack(
            wallets: ids.map(wallet).toList(),
            scope: scope,
            onOpenWallet: onOpen ?? (_) {},
            cardBuilder: (wallet, expanded) => WalletStackCard(
              key: ValueKey('card-${wallet.id}'),
              wallet: wallet,
              currencyCode: wallet.currency,
              displayBalanceCents: wallet.currentBalanceCents,
              isExpanded: expanded,
            ),
          ),
        ))),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  WalletStackCard card(WidgetTester tester, String id) =>
      tester.widget(find.byKey(ValueKey('card-$id')).first);
  Future<void> drag(WidgetTester tester, String id, Offset delta) async {
    final finder = find.byKey(ValueKey(id));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(finder) + const Offset(80, 36);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 550));
    await gesture.moveBy(delta);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('last wallet stays expanded when another opens (dark=$dark)',
        (tester) async {
      String? opened;
      await pumpStack(tester,
          dark: dark, onOpen: (wallet) => opened = wallet.id);
      expect(card(tester, 'c').isExpanded, isTrue);
      expect(card(tester, 'a').isExpanded, isFalse);
      await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('a'))) +
          const Offset(80, 36));
      await tester.pumpAndSettle();
      expect(card(tester, 'a').isExpanded, isTrue);
      expect(card(tester, 'c').isExpanded, isTrue);
      final aBottom = tester.getBottomLeft(find.byKey(const ValueKey('a'))).dy;
      expect(tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
          greaterThan(aBottom));
      await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('a'))) +
          const Offset(80, 36));
      expect(opened, 'a');
    });
  }

  testWidgets('long press drag saves order and expands the new last wallet',
      (tester) async {
    final container = await pumpStack(tester);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    await drag(tester, 'a', const Offset(0, 160));
    expect(container.read(walletOrderProvider(scope)), ['b', 'c', 'a']);
    expect(card(tester, 'a').isExpanded, isTrue);
    expect(card(tester, 'c').isExpanded, isFalse);
    expect(tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('c'))).dy));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(walletOrderStorageKey(scope)), ['b', 'c', 'a']);
    await drag(tester, 'a', const Offset(0, -150));
    expect(container.read(walletOrderProvider(scope)), ['a', 'b', 'c']);
    expect(card(tester, 'c').isExpanded, isTrue);
  });

  testWidgets(
      'saved order renders on first frame and single wallet stays expanded',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(walletOrderStorageKey(scope), ['c', 'b', 'a']);
    await pumpStack(tester);
    expect(card(tester, 'a').isExpanded, isTrue);
    expect(tester.getTopLeft(find.byKey(const ValueKey('c'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('a'))).dy));
    await pumpStack(tester, ids: ['a']);
    expect(card(tester, 'a').isExpanded, isTrue);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
  });

  testWidgets('drag autoscroll reaches wallets below the viewport',
      (tester) async {
    final container =
        await pumpStack(tester, ids: List.generate(12, (i) => 'w$i'));
    final gesture = await tester.startGesture(
        tester.getTopLeft(find.byKey(const ValueKey('w0'))) +
            const Offset(80, 36));
    await tester.pump(const Duration(milliseconds: 550));
    await gesture.moveTo(const Offset(100, 595));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(walletOrderProvider(scope)).last, 'w0',
        reason:
            'order=${container.read(walletOrderProvider(scope))}; scroll=${tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels}');
    expect(card(tester, 'w0').isExpanded, isTrue);
  });
  testWidgets('leaving the stack during edge scrolling stops the drag safely',
      (tester) async {
    await pumpStack(tester, ids: List.generate(12, (i) => 'w$i'));
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byKey(const ValueKey('w0'))) +
          const Offset(80, 36),
    );
    await tester.pump(const Duration(milliseconds: 550));
    await gesture.moveTo(const Offset(100, 595));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    expect(tester.takeException(), isNull);
  });
}
