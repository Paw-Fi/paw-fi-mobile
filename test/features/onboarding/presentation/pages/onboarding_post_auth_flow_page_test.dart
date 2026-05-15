import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_actions.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_page.dart';

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: '/onboarding-post',
    routes: [
      GoRoute(
        path: '/onboarding-post',
        builder: (context, state) => const OnboardingPostAuthFlowPage(),
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
}) async {
  final router = _createRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'u1', email: 'u1@example.com')),
        ),
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

  testWidgets('skip completes post-auth onboarding and redirects to paywall',
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

    expect(find.text('Dashboard'), findsOneWidget);
    expect(prefs.getBool('onboarding_completed:u1'), true);
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
}
