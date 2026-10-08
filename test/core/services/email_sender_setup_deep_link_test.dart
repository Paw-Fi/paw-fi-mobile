import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';

import '../../features/profile/presentation/providers/email_import_settings_provider_test.dart'
    show TestAuth, userId;

class TestLockRepository extends Mock implements AppLockRepository {}

class TestLockHasher extends Mock implements AppLockPasscodeHasher {}

class TestBiometrics extends Mock implements AppLockBiometricService {}

class TestLock extends AppLockController {
  TestLock()
      : super(
          userId: userId,
          repository: TestLockRepository(),
          hasher: TestLockHasher(),
          biometricService: TestBiometrics(),
          isEnabledFlagSet: false,
          setEnabledFlag: (_) async {},
        );
}

void main() {
  for (final waitingFor in ['ready', 'sign-in', 'unlock', 'onboarding']) {
    testWidgets(
        'sender setup waits for $waitingFor and consumes the intent once',
        (tester) async {
      final service = DeepLinkService();
      final lock = TestLock();
      var settingsBuilds = 0;
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation:
            waitingFor == 'onboarding' ? '/onboarding' : '/dashboard',
        routes: [
          for (final path in ['/dashboard', '/login', '/onboarding'])
            GoRoute(path: path, builder: (_, __) => Scaffold(body: Text(path))),
          GoRoute(
              path: '/email-import-settings',
              builder: (_, state) {
                settingsBuilds++;
                return Scaffold(
                    body:
                        Text('Sender: ${state.uri.queryParameters['email']}'));
              }),
        ],
      );
      late WidgetRef widgetRef;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(TestAuth.new),
          routerProvider.overrideWithValue(router),
          appLockControllerProvider.overrideWith((ref) => lock),
        ],
        child: Consumer(builder: (context, ref, _) {
          widgetRef = ref;
          return MaterialApp.router(routerConfig: router);
        }),
      ));
      await tester.pumpAndSettle();
      if (waitingFor == 'sign-in') {
        widgetRef.read(authProvider.notifier).state =
            const AppUser(uid: '', email: '');
      } else if (waitingFor == 'unlock') {
        lock.state = const AppLockState(status: AppLockStatus.locked);
      }
      service.handleDeepLinkUri(
          Uri.parse('moneko://add-email-sender?email=sender%40example.com'),
          widgetRef);
      await tester.pumpAndSettle();
      if (waitingFor != 'ready') {
        expect(settingsBuilds, 0);
        if (waitingFor == 'sign-in') {
          expect(find.text('/login'), findsOneWidget);
          widgetRef.read(authProvider.notifier).state =
              const AppUser(uid: userId, email: 'relay@example.com');
        } else if (waitingFor == 'unlock') {
          lock.state = const AppLockState.disabled();
        }
        router.go('/dashboard');
        await tester.pumpAndSettle();
      }
      expect(find.text('Sender: sender@example.com'), findsOneWidget);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('/dashboard'), findsOneWidget);
      service.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  }
}
