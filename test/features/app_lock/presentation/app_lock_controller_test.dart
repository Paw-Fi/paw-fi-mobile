import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('AppLockBiometricAvailability', () {
    test('uses Face ID wording for iOS face biometrics', () {
      const availability = AppLockBiometricAvailability(
        canAuthenticate: true,
        types: [BiometricType.face],
        platform: TargetPlatform.iOS,
      );

      expect(availability.displayName(l10n), 'Face ID');
      expect(availability.actionLabel(l10n), 'Use Face ID');
    });

    test('uses Touch ID wording for iOS fingerprint biometrics', () {
      const availability = AppLockBiometricAvailability(
        canAuthenticate: true,
        types: [BiometricType.fingerprint],
        platform: TargetPlatform.iOS,
      );

      expect(availability.displayName(l10n), 'Touch ID');
      expect(availability.actionLabel(l10n), 'Use Touch ID');
    });

    test('uses Android face unlock wording for Android face biometrics', () {
      const availability = AppLockBiometricAvailability(
        canAuthenticate: true,
        types: [BiometricType.face],
        platform: TargetPlatform.android,
      );

      expect(availability.displayName(l10n), 'Face unlock');
      expect(availability.actionLabel(l10n), 'Use Face unlock');
    });

    test('falls back to biometrics for strength-only Android results', () {
      const availability = AppLockBiometricAvailability(
        canAuthenticate: true,
        types: [BiometricType.strong],
        platform: TargetPlatform.android,
      );

      expect(availability.displayName(l10n), 'Biometrics');
      expect(availability.actionLabel(l10n), 'Use biometrics');
    });

    test('combines multiple precise Android methods', () {
      const availability = AppLockBiometricAvailability(
        canAuthenticate: true,
        types: [BiometricType.face, BiometricType.fingerprint],
        platform: TargetPlatform.android,
      );

      expect(availability.displayName(l10n), 'Face unlock or Fingerprint');
      expect(availability.actionLabel(l10n), 'Use Face unlock or Fingerprint');
    });
  });

  group('AppLockController', () {
    test('starts disabled when no config exists for the user', () async {
      final controller = _createController();

      await controller.initialize();

      expect(controller.state.status, AppLockStatus.disabled);
      expect(controller.state.shouldBlockApp, isFalse);
    });

    test('enables app lock and stores an unlocked config for the user',
        () async {
      final controller = _createController();

      await controller.enable(passcode: '123456', biometricEnabled: true);

      expect(controller.state.status, AppLockStatus.unlocked);
      expect(controller.state.config?.biometricEnabled, isTrue);
      expect(controller.state.shouldBlockApp, isFalse);
    });

    test('reports configured only after a secure config exists', () {
      const pendingState = AppLockState(status: AppLockStatus.locked);

      expect(pendingState.isConfigured, isFalse);
      expect(pendingState.isEnabled, isTrue);
    });

    test('locks and unlocks with the configured passcode', () async {
      final controller = _createController();
      await controller.enable(passcode: '123456');

      controller.lock();
      final unlocked = await controller.verifyPasscode('123456');

      expect(unlocked, isTrue);
      expect(controller.state.status, AppLockStatus.unlocked);
      expect(controller.state.failedMessage(l10n), isNull);
    });

    test('records failed attempts and applies lockout after five failures',
        () async {
      var now = DateTime.utc(2026, 6, 7, 12);
      final controller = _createController(now: () => now);
      await controller.enable(passcode: '123456');
      controller.lock();

      for (var i = 0; i < 5; i++) {
        expect(await controller.verifyPasscode('000000'), isFalse);
      }

      expect(controller.state.status, AppLockStatus.lockedOut);
      expect(controller.state.config?.failedAttempts, 5);

      now = DateTime.utc(2026, 6, 7, 12, 0, 30);
      expect(await controller.verifyPasscode('123456'), isFalse);

      now = DateTime.utc(2026, 6, 7, 12, 2);
      expect(await controller.verifyPasscode('123456'), isTrue);
    });

    test('initialize ignores late storage results after dispose', () async {
      final readCompleter = Completer<void>();
      final controller = AppLockController(
        userId: 'user-1',
        repository: AppLockRepository(
          store: _DelayedEmptyAppLockKeyValueStore(readCompleter),
        ),
        hasher: AppLockPasscodeHasher(
          saltBytesFactory: () => List<int>.filled(16, 9),
        ),
        biometricService: const _FakeBiometricService(),
        isEnabledFlagSet: true,
        setEnabledFlag: (_) async {},
      );

      final initializeFuture = controller.initialize();
      controller.dispose();
      readCompleter.complete();

      await expectLater(initializeFuture, completes);
    });

    test('clearForRecovery ignores late storage results after dispose',
        () async {
      final deleteCompleter = Completer<void>();
      final controller = AppLockController(
        userId: 'user-1',
        repository: AppLockRepository(
          store: _DelayedDeleteAppLockKeyValueStore(deleteCompleter),
        ),
        hasher: AppLockPasscodeHasher(
          saltBytesFactory: () => List<int>.filled(16, 9),
        ),
        biometricService: const _FakeBiometricService(),
        isEnabledFlagSet: true,
        setEnabledFlag: (_) async {},
      );

      final recoveryFuture = controller.clearForRecovery();
      controller.dispose();
      deleteCompleter.complete();

      await expectLater(recoveryFuture, completes);
    });

    test('authenticates before enabling biometric unlock', () async {
      final biometricService = _RecordingBiometricService(
        canAuthenticateResult: true,
        authenticateResult: true,
      );
      final controller = _createController(biometricService: biometricService);
      await controller.enable(passcode: '123456');

      await controller.setBiometricEnabled(true);

      expect(biometricService.authenticateCalls, 1);
      expect(controller.state.config?.biometricEnabled, isTrue);
    });

    test('does not enable biometric unlock when authentication fails',
        () async {
      final biometricService = _RecordingBiometricService(
        canAuthenticateResult: true,
        authenticateResult: false,
      );
      final controller = _createController(biometricService: biometricService);
      await controller.enable(passcode: '123456');

      await controller.setBiometricEnabled(true);

      expect(biometricService.authenticateCalls, 1);
      expect(controller.state.config?.biometricEnabled, isFalse);
    });
  });
}

AppLockController _createController({
  DateTime Function()? now,
  AppLockBiometricService biometricService = const _FakeBiometricService(),
}) {
  return AppLockController(
    userId: 'user-1',
    repository: AppLockRepository(store: _MemoryAppLockKeyValueStore()),
    hasher: AppLockPasscodeHasher(
      saltBytesFactory: () => List<int>.filled(16, 9),
    ),
    biometricService: biometricService,
    isEnabledFlagSet: false,
    setEnabledFlag: (_) async {},
    now: now,
  );
}

class _MemoryAppLockKeyValueStore implements AppLockKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedEmptyAppLockKeyValueStore implements AppLockKeyValueStore {
  _DelayedEmptyAppLockKeyValueStore(this.readCompleter);

  final Completer<void> readCompleter;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async {
    await readCompleter.future;
    return null;
  }

  @override
  Future<void> write(String key, String value) async {}
}

class _DelayedDeleteAppLockKeyValueStore implements AppLockKeyValueStore {
  _DelayedDeleteAppLockKeyValueStore(this.deleteCompleter);

  final Completer<void> deleteCompleter;

  @override
  Future<void> delete(String key) async {
    await deleteCompleter.future;
  }

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

class _FakeBiometricService implements AppLockBiometricService {
  const _FakeBiometricService();

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<AppLockBiometricAvailability> getAvailability() async =>
      const AppLockBiometricAvailability(
        canAuthenticate: true,
        types: [BiometricType.fingerprint],
        platform: TargetPlatform.android,
      );
}

class _RecordingBiometricService implements AppLockBiometricService {
  _RecordingBiometricService({
    required this.canAuthenticateResult,
    required this.authenticateResult,
  });

  final bool canAuthenticateResult;
  final bool authenticateResult;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticate() async {
    authenticateCalls++;
    return authenticateResult;
  }

  @override
  Future<AppLockBiometricAvailability> getAvailability() async =>
      AppLockBiometricAvailability(
        canAuthenticate: canAuthenticateResult,
        types: canAuthenticateResult
            ? const [BiometricType.fingerprint]
            : const [],
        platform: TargetPlatform.android,
      );
}
