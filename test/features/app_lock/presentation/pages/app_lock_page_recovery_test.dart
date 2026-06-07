import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/app_lock/presentation/pages/app_lock_page.dart';
import 'package:moneko/features/auth/auth.dart';

void main() {
  testWidgets('forgot passcode routes to login while sign out is still pending',
      (tester) async {
    final signOutCompleter = Completer<void>();
    final recoveryCompleter = Completer<void>();
    final appLockController = _RecoveryAppLockController(recoveryCompleter);

    final router = GoRouter(
      initialLocation: '/app-lock',
      routes: [
        GoRoute(
          path: '/app-lock',
          builder: (context, state) => const AppLockPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Text('Login page'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockControllerProvider.overrideWith((ref) => appLockController),
          authProvider
              .overrideWith(() => _DelayedSignOutAuth(signOutCompleter)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Forgot passcode? Sign out'));
    await tester.pump();

    expect(find.text('Signing out...'), findsOneWidget);
    expect(find.text('Login page'), findsOneWidget);
    expect(signOutCompleter.isCompleted, isFalse);

    recoveryCompleter.complete();
    signOutCompleter.complete();
    await tester.pumpAndSettle();
  });
}

class _DelayedSignOutAuth extends Auth {
  _DelayedSignOutAuth(this.signOutCompleter);

  final Completer<void> signOutCompleter;

  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'test@example.com');

  @override
  Future<void> signOut() => signOutCompleter.future;
}

class _RecoveryAppLockController extends AppLockController {
  _RecoveryAppLockController(this.recoveryCompleter)
      : super(
          userId: 'user-1',
          repository: AppLockRepository(store: _MemoryAppLockKeyValueStore()),
          hasher: AppLockPasscodeHasher(
            saltBytesFactory: () => List<int>.filled(16, 1),
          ),
          biometricService: const _FakeBiometricService(),
          isEnabledFlagSet: true,
          setEnabledFlag: (_) async {},
        );

  final Completer<void> recoveryCompleter;

  @override
  Future<void> clearForRecovery() => recoveryCompleter.future;
}

class _MemoryAppLockKeyValueStore implements AppLockKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _FakeBiometricService implements AppLockBiometricService {
  const _FakeBiometricService();

  @override
  Future<bool> authenticate() async => false;

  @override
  Future<AppLockBiometricAvailability> getAvailability() async =>
      const AppLockBiometricAvailability(
        canAuthenticate: false,
        types: <BiometricType>[],
        platform: TargetPlatform.android,
      );
}
