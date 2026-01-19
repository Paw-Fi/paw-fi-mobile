import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_flow_page.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class _MockDeviceRegistrationService extends Mock
    implements DeviceRegistrationService {}

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

class _TestHomeFilterNotifier extends HomeFilterNotifier {
  _TestHomeFilterNotifier() : super() {
    state = HomeFilterState(selectedCurrency: 'USD');
  }
}

class _TestPocketsNotifier extends PocketsNotifier {
  _TestPocketsNotifier(super.ref, super.params, {this.saveDelay});

  final Duration? saveDelay;

  @override
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: false,
      saved: const [],
      editing: const [],
      periodMonth: DateTime(1970, 1, 1),
      previousBudget: 0,
      totalBudget: 0,
      savedTotalBudget: 0,
      unallocatedSpend: 0,
      uncategorized: const [],
      uncategorizedExpenses: const {},
      clearError: true,
    );
  }

  @override
  Future<void> saveChanges() async {
    final delay = saveDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
  }
}

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowPage(),
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

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required DeviceRegistrationService deviceRegistrationService,
  Duration? pocketsSaveDelay,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1200));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final router = _createRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'u1', email: 'u1@example.com')),
        ),
        deviceRegistrationServiceProvider
            .overrideWithValue(deviceRegistrationService),
        homeFilterProvider.overrideWith(
          (ref) => _TestHomeFilterNotifier(),
        ),
        pocketsProvider.overrideWith(
          (ref, params) => _TestPocketsNotifier(
            ref,
            params,
            saveDelay: pocketsSaveDelay,
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData.light(useMaterial3: true),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _tapPrimary(WidgetTester tester) async {
  final primary = find.byType(PrimaryAdaptiveButton);
  expect(primary, findsOneWidget);
  await tester.tap(primary);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Skip completes onboarding and navigates to dashboard',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    final deviceService = _MockDeviceRegistrationService();
    when(() => deviceService.initialize()).thenAnswer((_) async {});
    when(() => deviceService.unregisterDevice()).thenAnswer((_) async {});

    await _pumpOnboarding(
      tester,
      prefs: prefs,
      deviceRegistrationService: deviceService,
    );

    // Skip now advances to the next step, not exit.
    // Tap through all onboarding steps via Skip.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.textContaining('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    // Last skip opens the finish page; complete it.
    final startButton = find.byType(PrimaryAdaptiveButton);
    expect(startButton, findsOneWidget);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(prefs.getBool('onboarding_completed:u1'), true);
  });

  testWidgets('Primary advances through steps and prompts notifications flag',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    final deviceService = _MockDeviceRegistrationService();
    when(() => deviceService.initialize()).thenAnswer((_) async {});
    when(() => deviceService.unregisterDevice()).thenAnswer((_) async {});

    await _pumpOnboarding(
      tester,
      prefs: prefs,
      deviceRegistrationService: deviceService,
    );

    await _tapPrimary(tester);
    expect(find.byType(PocketsHeaderCard), findsOneWidget);

    await _tapPrimary(tester);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

    await _tapPrimary(tester);
    expect(find.byType(TextField), findsOneWidget);

    expect(prefs.getBool('notifications_prompted:u1'), true);
  });

  testWidgets(
      'Regression: unmount during async primary does not throw FlutterError',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    final deviceService = _MockDeviceRegistrationService();
    when(() => deviceService.initialize()).thenAnswer((_) async {});
    when(() => deviceService.unregisterDevice()).thenAnswer((_) async {});

    final previousOnError = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      errors.add(details);
      previousOnError?.call(details);
    };

    await _pumpOnboarding(
      tester,
      prefs: prefs,
      deviceRegistrationService: deviceService,
      pocketsSaveDelay: const Duration(milliseconds: 50),
    );

    await _tapPrimary(tester);
    expect(find.byType(PocketsHeaderCard), findsOneWidget);

    final primary = find.byType(PrimaryAdaptiveButton);
    await tester.tap(primary);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));

    FlutterError.onError = previousOnError;

    final exception = tester.takeException();
    expect(exception, isNull);
    expect(errors, isEmpty);
  });
}
