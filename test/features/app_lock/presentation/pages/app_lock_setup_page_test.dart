import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/app_lock/presentation/pages/app_lock_setup_page.dart';

void main() {
  testWidgets('shows blocking processing dialog while enabling app lock',
      (tester) async {
    final enableCompleter = Completer<void>();
    final appLockController = _DelayedEnableAppLockController(enableCompleter);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockControllerProvider.overrideWith((ref) => appLockController),
          appLockBiometricServiceProvider.overrideWithValue(
            const _FakeBiometricService(),
          ),
        ],
        child: const MaterialApp(
          home: AppLockSetupPage(mode: AppLockSetupMode.enable),
        ),
      ),
    );

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(OutlinedButton, digit));
      await tester.pump();
    }
    expect(find.text('Confirm your passcode'), findsOneWidget);

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(OutlinedButton, digit));
      await tester.pump();
    }

    expect(find.text('Turning on App Lock...'), findsOneWidget);
    expect(enableCompleter.isCompleted, isFalse);

    enableCompleter.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

class _DelayedEnableAppLockController extends AppLockController {
  _DelayedEnableAppLockController(this.enableCompleter)
      : super(
          userId: 'user-1',
          repository: AppLockRepository(store: _MemoryAppLockKeyValueStore()),
          hasher: AppLockPasscodeHasher(
            saltBytesFactory: () => List<int>.filled(16, 1),
          ),
          biometricService: const _FakeBiometricService(),
          isEnabledFlagSet: false,
          setEnabledFlag: (_) async {},
        );

  final Completer<void> enableCompleter;

  @override
  Future<void> enable({
    required String passcode,
    bool biometricEnabled = false,
  }) async {
    await enableCompleter.future;
  }
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
  Future<bool> canAuthenticate() async => false;
}
