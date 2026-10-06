import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/core/sync/ios_siri_transaction_defaults_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

const _spaceId = '11111111-1111-4111-8111-111111111111';
const _walletId = '22222222-2222-4222-8222-222222222222';

HouseholdScope _scope({String? householdId, bool portfolio = false}) =>
    HouseholdScope(
      viewMode: householdId == null ? ViewMode.personal : ViewMode.household,
      selected: SelectedHouseholdState(householdId: householdId),
      portfolioHouseholdIds: portfolio ? {householdId!} : {},
    );

WalletEntity _wallet({String? householdId, String currency = 'EUR'}) =>
    WalletEntity(
      id: _walletId,
      userId: 'user-1',
      householdId: householdId,
      name: 'Selected default',
      icon: 'wallet',
      color: '#000000',
      currency: currency,
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: true,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 0,
    );

final _scopeState = StateProvider<HouseholdScope>((ref) => _scope());
final _walletState = StateProvider<WalletEntity?>((ref) => _wallet());

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');
}

class _TestWallets extends ScopedWalletsNotifier {
  static Completer<List<WalletEntity>>? initialLoad;

  @override
  Future<List<WalletEntity>> build() async =>
      initialLoad == null ? [] : await initialLoad!.future;

  void beginUncachedRead() => state = const AsyncLoading();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('moneko/siri_shortcut_auth');
  late ProviderContainer container;
  late List<Map<Object?, Object?>> writes;
  var failWrite = false;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    writes = [];
    failWrite = false;
    _TestWallets.initialLoad = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncTransactionDefaults') {
        if (failWrite) throw PlatformException(code: 'temporarily_unavailable');
        writes.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    });
    await SiriShortcutAuthService.instance.clearAuthContext();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      homeFilterProvider.overrideWith(
          (ref) => HomeFilterNotifier()..bootstrapSelectedCurrency('EUR')),
      appPreferredCurrencyProvider.overrideWithValue(null),
      householdScopeProvider.overrideWith((ref) => ref.watch(_scopeState)),
      defaultScopedAccountProvider
          .overrideWith((ref) => ref.watch(_walletState)),
      scopedWalletsProvider.overrideWith(_TestWallets.new),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await SiriShortcutAuthService.instance.clearAuthContext();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mount() {
    final subscription =
        container.listen(iosSiriTransactionDefaultsSyncProvider, (_, __) {});
    addTearDown(subscription.close);
  }

  test(
      'publishes Home currency and selected private Space with its default wallet',
      () async {
    container.read(_scopeState.notifier).state =
        _scope(householdId: _spaceId, portfolio: true);
    container.read(_walletState.notifier).state =
        _wallet(householdId: _spaceId);
    mount();
    await container.read(scopedWalletsProvider.future);
    await pumpEventQueue();
    expect(writes.last, {
      'version': 1,
      'userId': 'user-1',
      'currency': 'EUR',
      'spaceId': _spaceId,
      'isPortfolio': true,
      'accountId': _walletId,
      'walletsReady': true,
    });
  });

  test('currency, Space and default-wallet changes update the native snapshot',
      () async {
    mount();
    await container.read(scopedWalletsProvider.future);
    await pumpEventQueue();
    container.read(homeFilterProvider.notifier).setSelectedCurrency('USD');
    await pumpEventQueue();
    expect(writes.last['currency'], 'USD');
    expect(writes.last['accountId'], isNull);
    container.read(_scopeState.notifier).state = _scope(householdId: _spaceId);
    container.read(_walletState.notifier).state =
        _wallet(householdId: _spaceId, currency: 'USD');
    await pumpEventQueue();
    expect(writes.last['spaceId'], _spaceId);
    expect(writes.last['accountId'], _walletId);
    const nextId = '33333333-3333-4333-8333-333333333333';
    container.read(_walletState.notifier).state =
        _wallet(householdId: _spaceId, currency: 'USD').copyWith(id: nextId);
    await pumpEventQueue();
    expect(writes.last['accountId'], nextId);
  });

  test(
      'foreign-currency, other-actor/Space, archived and unsynced wallets cannot bind',
      () {
    for (final wallet in [
      _wallet(currency: 'USD'),
      _wallet(householdId: _spaceId),
      _wallet().copyWith(userId: 'user-2'),
      _wallet().copyWith(isArchived: true),
      _wallet().copyWith(id: 'local-wallet'),
    ]) {
      container.read(_walletState.notifier).state = wallet;
      expect(
          container.read(siriTransactionDefaultsProvider)?.accountId, isNull);
    }
  });

  test(
      'unknown startup currency and unresolved shared selection do not overwrite defaults',
      () async {
    container.read(homeFilterProvider.notifier).setSelectedCurrency(null);
    mount();
    await pumpEventQueue();
    expect(writes, isEmpty);
    container.read(_scopeState.notifier).state = const HouseholdScope(
      viewMode: ViewMode.household,
      selected: SelectedHouseholdState(isLoading: true),
      portfolioHouseholdIds: {},
    );
    container.read(homeFilterProvider.notifier).setSelectedCurrency('EUR');
    await pumpEventQueue();
    expect(writes, isEmpty);
  });

  test(
      'uncached wallet read is marked unresolved so native can retain a matching wallet',
      () async {
    _TestWallets.initialLoad = Completer<List<WalletEntity>>();
    container.read(_walletState.notifier).state = null;
    mount();
    await pumpEventQueue();
    expect(writes.last['accountId'], isNull);
    expect(writes.last['walletsReady'], false);
    expect(writes.last['currency'], 'EUR');
    _TestWallets.initialLoad!.complete([]);
    await pumpEventQueue();
    expect(writes.last['walletsReady'], true);
  });

  test('cached wallet refresh keeps the selected default visible', () async {
    mount();
    await container.read(scopedWalletsProvider.future);
    await pumpEventQueue();
    (container.read(scopedWalletsProvider.notifier) as _TestWallets)
        .beginUncachedRead();
    await pumpEventQueue();
    expect(writes.last['accountId'], _walletId);
    expect(writes.last['walletsReady'], true);
  });

  test('preview and Android cannot publish simulated selection defaults',
      () async {
    container.read(previewModeProvider.notifier).enable();
    mount();
    await pumpEventQueue();
    expect(writes, isEmpty);
    container.read(previewModeProvider.notifier).disable();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    container.invalidate(iosSiriTransactionDefaultsSyncProvider);
    await pumpEventQueue();
    expect(writes, isEmpty);
  });

  test('failed native write retries on session sync only for its owning actor',
      () async {
    failWrite = true;
    mount();
    await pumpEventQueue();
    expect(writes, isEmpty);
    failWrite = false;
    Future<void> sync(String userId) =>
        SiriShortcutAuthService.instance.syncAuthContext(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon',
          accessToken: 'token',
          userId: userId,
          expiresAt: 2000000000,
        );
    await sync('user-2');
    expect(writes, isEmpty);
    await sync('user-1');
    expect(writes.last['currency'], 'EUR');
    final count = writes.length;
    await SiriShortcutAuthService.instance.clearAuthContext();
    await sync('user-1');
    expect(writes.length, count);
  });
}
