import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_account_preparing_page.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

Future<http.Response>? _pendingAccountRead;

Future<void> pumpPage(
  WidgetTester tester, {
  required SharedPreferences prefs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'u1', email: 'u1@example.com')),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const OnboardingAccountPreparingPage(autoStart: false),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        final pending = _pendingAccountRead;
        return pending != null ? await pending : http.Response('[]', 200);
      }),
    );
  });

  testWidgets('closing during account preparation skips later widget reads',
      (tester) async {
    final pending = Completer<http.Response>();
    _pendingAccountRead = pending.future;
    addTearDown(() => _pendingAccountRead = null);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => _TestAuth(
              const AppUser(uid: 'u1', email: 'u1@example.com'),
            )),
      ],
      child: const MaterialApp(home: OnboardingAccountPreparingPage()),
    ));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(http.Response('[]', 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue stays hidden while setup is still in progress',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await pumpPage(tester, prefs: prefs);

    expect(find.text('Continue'), findsNothing);
  });

  test(
      'subscription preparation progress advances gradually and remains capped',
      () {
    expect(
      onboardingSubscriptionPreparationVisualProgress(Duration.zero),
      0.1,
    );
    expect(
      onboardingSubscriptionPreparationVisualProgress(
        const Duration(seconds: 10),
      ),
      closeTo(0.35, 0.001),
    );
    expect(
      onboardingSubscriptionPreparationVisualProgress(
        const Duration(seconds: 30),
      ),
      0.6,
    );
  });

  test('completion copy explains Family Sharing access', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final copy = onboardingCompletionCopyForSubscription(
      l10n: l10n,
      details: SubscriptionDetails(
        subscription: Subscription(
          id: 'sub_family',
          userId: 'u1',
          provider: 'app_store',
          appStoreInAppOwnershipType: 'FAMILY_SHARED',
          plan: 'plus',
          status: 'active',
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        ),
        invoices: const [],
      ),
    );

    expect(copy.progressLabel,
        l10n.onboardingPreparingProgressFamilySharingRestored);
    expect(copy.title, l10n.onboardingPreparingTitleFamilySharingRestored);
    expect(copy.body, l10n.onboardingPreparingBodyFamilySharingRestored);
  });

  test('completion copy explains Family Sharing access without provider', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final copy = onboardingCompletionCopyForSubscription(
      l10n: l10n,
      details: SubscriptionDetails(
        subscription: Subscription(
          id: 'sub_family',
          userId: 'u1',
          appStoreInAppOwnershipType: 'FAMILY_SHARED',
          plan: 'plus',
          status: 'active',
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        ),
        invoices: const [],
      ),
    );

    expect(copy.progressLabel,
        l10n.onboardingPreparingProgressFamilySharingRestored);
    expect(copy.title, l10n.onboardingPreparingTitleFamilySharingRestored);
    expect(copy.body, l10n.onboardingPreparingBodyFamilySharingRestored);
  });

  test('completion copy explains owned App Store subscription restore', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final copy = onboardingCompletionCopyForSubscription(
      l10n: l10n,
      details: SubscriptionDetails(
        subscription: Subscription(
          id: 'sub_owned',
          userId: 'u1',
          provider: 'app_store',
          appStoreInAppOwnershipType: 'PURCHASED',
          plan: 'plus',
          status: 'active',
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
        ),
        invoices: const [],
      ),
    );

    expect(
        copy.progressLabel, l10n.onboardingPreparingProgressAppStoreRestored);
    expect(copy.title, l10n.onboardingPreparingTitleAppStoreRestored);
    expect(copy.body, l10n.onboardingPreparingBodyAppStoreRestored);
  });
}
