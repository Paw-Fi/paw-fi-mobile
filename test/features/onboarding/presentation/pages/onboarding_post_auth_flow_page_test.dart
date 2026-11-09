import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_actions.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_page.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';

final _activeSubscription = Subscription(
  id: 'subscription-1',
  userId: 'u1',
  plan: 'plus',
  status: 'active',
  currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
  createdAt: DateTime.now(),
);

final _trialSubscription = Subscription(
  id: 'subscription-trial',
  userId: 'u1',
  plan: 'plus',
  status: 'trialing',
  currentPeriodEnd: DateTime.now().add(const Duration(days: 7)),
  createdAt: DateTime.now(),
);

class _TestSubscriptionManagementNotifier
    extends SubscriptionManagementNotifier {
  void activate() {
    state = AsyncData(SubscriptionDetails(
      subscription: _activeSubscription,
      invoices: const [],
    ));
  }

  @override
  Future<SubscriptionDetails?> build() async => SubscriptionDetails(
        subscription: _trialSubscription,
        invoices: const [],
      );

  @override
  Future<void> refresh() async {
    state = AsyncData(
      SubscriptionDetails(
        subscription: _trialSubscription,
        invoices: const [],
      ),
    );
  }
}

class _DelayedSubscriptionManagementNotifier
    extends SubscriptionManagementNotifier {
  _DelayedSubscriptionManagementNotifier(this.refreshCompleter);

  final Completer<void> refreshCompleter;

  @override
  Future<SubscriptionDetails?> build() async => SubscriptionDetails(
        subscription: _trialSubscription,
        invoices: const [],
      );

  @override
  Future<void> refresh() => refreshCompleter.future;
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<Subscription?> build() async => _trialSubscription;

  @override
  Future<void> refresh() async {
    state = AsyncData(_trialSubscription);
  }
}

class _ActiveSubscriptionManagementNotifier
    extends SubscriptionManagementNotifier {
  @override
  Future<SubscriptionDetails?> build() async => SubscriptionDetails(
        subscription: _activeSubscription,
        invoices: const [],
      );
}

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

class _TestInitialization extends AppInitializationV2 {
  @override
  AppInitializationState build() =>
      const AppInitializationState(state: AppInitState.uninitialized);
}

class _TestLockRepository extends Mock implements AppLockRepository {}

class _TestLockHasher extends Mock implements AppLockPasscodeHasher {}

class _TestBiometrics extends Mock implements AppLockBiometricService {}

GoRouter _createRouter({bool useProductionRedirect = false}) {
  return GoRouter(
    initialLocation: '/onboarding?stage=post',
    redirect: useProductionRedirect
        ? (context, state) => ProviderScope.containerOf(context, listen: false)
            .read(routerProvider)
            .configuration
            .topRedirect(context, state)
        : null,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            state.uri.queryParameters['stage'] == 'prepare'
                ? const Scaffold(body: Text('Account preparation'))
                : const OnboardingPostAuthFlowPage(),
      ),
      GoRoute(
        path: '/plus-locked',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => context.push(
                    '/plan-selection?mode=resubscribe&plan=plus&interval=yearly'),
                child: const Text('See all plans'),
              ),
              TextButton(
                onPressed: () {
                  (ProviderScope.containerOf(context, listen: false)
                              .read(subscriptionManagementProvider.notifier)
                          as _TestSubscriptionManagementNotifier)
                      .activate();
                  context.pop();
                },
                child: const Text('Confirm purchase'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/plan-selection',
        builder: (context, state) =>
            const Scaffold(body: Text('Plan selection')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Dashboard')),
        ),
      ),
    ],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SharedPreferences prefs,
  List<Override> overrides = const [],
  bool useProductionRedirect = false,
}) async {
  final router = _createRouter(useProductionRedirect: useProductionRedirect);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'u1', email: 'u1@example.com')),
        ),
        subscriptionManagementProvider.overrideWith(
          _TestSubscriptionManagementNotifier.new,
        ),
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
        if (useProductionRedirect) ...[
          appInitializationV2Provider.overrideWith(_TestInitialization.new),
          appLockControllerProvider.overrideWith((ref) => AppLockController(
                userId: 'u1',
                repository: _TestLockRepository(),
                hasher: _TestLockHasher(),
                biometricService: _TestBiometrics(),
                isEnabledFlagSet: false,
                setEnabledFlag: (_) async {},
              )),
        ],
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData.light(useMaterial3: true),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'view plans preserves the final step through production redirects',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_preauth_completed', true);
    await prefs.setBool('onboarding_preauth_synced:u1', true);
    await _pumpPage(tester, prefs: prefs, useProductionRedirect: true);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text("I'll do this later"));
      await tester.pumpAndSettle();
    }

    final onboardingElement =
        tester.element(find.byType(OnboardingPostAuthFlowPage));
    final router = GoRouter.of(onboardingElement);
    await tester.tap(find.text('View plans'));
    await tester.pumpAndSettle();
    expect(find.text('See all plans'), findsOneWidget);
    final introUri =
        GoRouterState.of(tester.element(find.text('See all plans'))).uri;
    expect(introUri.path, '/plus-locked');
    expect(introUri.queryParameters['feature'], 'messagingAppCapture');
    expect(prefs.getBool('onboarding_completed:u1'), isNull);

    await tester.tap(find.text('See all plans'));
    await tester.pumpAndSettle();
    expect(find.text('Plan selection'), findsOneWidget);
    expect(
        GoRouterState.of(tester.element(find.text('Plan selection'))).uri.path,
        '/plan-selection');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('See all plans'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('View plans'), findsOneWidget);
    expect(tester.element(find.byType(OnboardingPostAuthFlowPage)),
        same(onboardingElement));
    expect(prefs.getBool('onboarding_completed:u1'), isNull);

    router.go('/dashboard');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.toString(),
        '/onboarding?stage=post');
    expect(find.text('Dashboard'), findsNothing);
  });

  for (final path in ['/plus-locked', '/plan-selection']) {
    testWidgets('$path remains unavailable without authentication',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpPage(
        tester,
        prefs: prefs,
        useProductionRedirect: true,
        overrides: [
          authProvider
              .overrideWith(() => _TestAuth(const AppUser(uid: '', email: ''))),
        ],
      );
      final router =
          GoRouter.of(tester.element(find.byType(OnboardingPostAuthFlowPage)));

      router.go(path);
      await tester.pumpAndSettle();

      expect(
          router.routeInformationProvider.value.uri.toString(), '/onboarding');
      expect(find.text('See all plans'), findsNothing);
      expect(find.text('Plan selection'), findsNothing);
    });

    testWidgets('$path does not bypass unfinished account preparation',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_preauth_completed', true);
      await prefs.setBool('onboarding_preauth_synced:u1', true);
      await _pumpPage(tester, prefs: prefs, useProductionRedirect: true);
      final router =
          GoRouter.of(tester.element(find.byType(OnboardingPostAuthFlowPage)));

      await prefs.remove('onboarding_preauth_synced:u1');
      router.go(path);
      await tester.pumpAndSettle();

      expect(find.text('Account preparation'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.toString(),
          '/onboarding?stage=prepare');
    });
  }

  testWidgets('confirmed active subscription completes onboarding after plans',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_preauth_completed', true);
    await prefs.setBool('onboarding_preauth_synced:u1', true);
    await _pumpPage(tester, prefs: prefs, useProductionRedirect: true);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text("I'll do this later"));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('View plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm purchase'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(prefs.getBool('onboarding_completed:u1'), true);
  });

  testWidgets('skip completes post-auth onboarding and redirects to dashboard',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await _pumpPage(tester, prefs: prefs);

    final skipButton = find.text("I'll do this later");
    await tester.tap(skipButton);
    await tester.pumpAndSettle();
    await tester.tap(skipButton);
    await tester.pumpAndSettle();
    await tester.tap(skipButton);
    await tester.pumpAndSettle();
    await tester.tap(skipButton);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(prefs.getBool('onboarding_completed:u1'), true);
  });

  testWidgets('skips the subscription step for active subscribers',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await _pumpPage(
      tester,
      prefs: prefs,
      overrides: [
        subscriptionManagementProvider.overrideWith(
          _ActiveSubscriptionManagementNotifier.new,
        ),
      ],
    );

    expect(find.text('Plus Plan'), findsNothing);
    final skipButton = find.text("I'll do this later");
    await tester.tap(skipButton);
    await tester.pumpAndSettle();
    await tester.tap(skipButton);
    await tester.pumpAndSettle();
    await tester.tap(skipButton);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets(
      'notification action advances without waiting for notification work',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsCompleter = Completer<void>();
    final subscriptionRefreshCompleter = Completer<void>();

    await _pumpPage(
      tester,
      prefs: prefs,
      overrides: [
        onboardingPostAuthNotificationsActionProvider.overrideWithValue(
          (ref, uid) => notificationsCompleter.future,
        ),
        subscriptionManagementProvider.overrideWith(
          () => _DelayedSubscriptionManagementNotifier(
            subscriptionRefreshCompleter,
          ),
        ),
      ],
    );

    final skipButton = find.text("I'll do this later");
    await tester.tap(skipButton);
    await tester.pumpAndSettle();
    await tester.tap(skipButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn on Notifications'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Plus Plan'), findsOneWidget);
    expect(prefs.getBool('onboarding_completed:u1'), isNull);
    expect(notificationsCompleter.isCompleted, false);
    expect(subscriptionRefreshCompleter.isCompleted, false);

    await tester.tap(skipButton);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(prefs.getBool('onboarding_completed:u1'), true);

    notificationsCompleter.complete();
    subscriptionRefreshCompleter.complete();
    await tester.pump();
  });

  testWidgets('logging expense shows result before advancing', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await _pumpPage(
      tester,
      prefs: prefs,
      overrides: [
        onboardingPostAuthLogExpenseActionProvider.overrideWithValue(
          (context, ref, sourceLabel) async =>
              const OnboardingLoggedExpensePreview(
            sourceLabel: 'Text',
            amount: 24.5,
            currency: 'USD',
            description: 'Lunch',
            category: 'Uncategorized',
            items: [],
          ),
        ),
      ],
    );

    await tester.tap(find.text('Add Expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Expense logged!'), findsWidgets);
    expect(find.text('Lunch'), findsWidgets);
    expect(find.text('Experience the magic\nof Moneko AI'), findsOneWidget);
    expect(find.text('Expense Captured!'), findsWidgets);

    await tester.tap(find.text('Looks good!'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Import your expenses\nfrom another app'), findsOneWidget);
  });

  testWidgets('logging expense shows result after asynchronous AI success',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const preview = OnboardingLoggedExpensePreview(
      sourceLabel: 'Text',
      amount: 24.5,
      currency: 'USD',
      description: 'Lunch',
      category: 'Uncategorized',
      items: [],
    );

    await _pumpPage(
      tester,
      prefs: prefs,
      overrides: [
        onboardingPostAuthLogExpenseActionProvider.overrideWithValue(
          (context, ref, sourceLabel) async {
            Future<void>.delayed(Duration.zero, () {
              ref.read(onboardingPostAuthLogExpenseSuccessProvider)?.call(
                    preview,
                  );
            });
            return null;
          },
        ),
      ],
    );

    await tester.tap(find.text('Add Expense'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Expense Captured!'), findsWidgets);
    expect(find.text('Lunch'), findsWidgets);
  });
}
