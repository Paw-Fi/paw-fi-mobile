import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:moneko/features/app_lock/data/app_lock_config.dart';
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

enum AppLockStatus {
  disabled,
  locked,
  unlocked,
  lockedOut,
}

enum AppLockFailureReason {
  incorrectPasscode,
  tryAgainLater,
}

class AppLockBiometricAvailability {
  const AppLockBiometricAvailability({
    required this.canAuthenticate,
    required this.types,
    required this.platform,
  });

  const AppLockBiometricAvailability.unavailable({
    TargetPlatform platform = TargetPlatform.android,
  }) : this(
          canAuthenticate: false,
          types: const [],
          platform: platform,
        );

  final bool canAuthenticate;
  final List<BiometricType> types;
  final TargetPlatform platform;

  bool get hasFace => types.contains(BiometricType.face);
  bool get hasFingerprint => types.contains(BiometricType.fingerprint);
  bool get hasIris => types.contains(BiometricType.iris);
  bool get hasOnlyStrengthClass =>
      types.any((type) =>
          type == BiometricType.strong || type == BiometricType.weak) &&
      !hasFace &&
      !hasFingerprint &&
      !hasIris;

  bool get _isApplePlatform =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  String displayName(AppLocalizations l10n) {
    if (!canAuthenticate || types.isEmpty || hasOnlyStrengthClass) {
      return l10n.biometrics;
    }

    final names = <String>[];
    if (hasFace) {
      names.add(_isApplePlatform ? l10n.faceId : l10n.faceUnlock);
    }
    if (hasFingerprint) {
      names.add(_isApplePlatform ? l10n.touchId : l10n.fingerprint);
    }
    if (hasIris) {
      names.add(l10n.irisScan);
    }

    if (names.isEmpty) {
      return l10n.biometrics;
    }
    if (names.length == 1) {
      return names.first;
    }
    return '${names.sublist(0, names.length - 1).join(', ')} '
        '${l10n.or} ${names.last}';
  }

  String actionLabel(AppLocalizations l10n) {
    final method = displayName(l10n);
    return method == l10n.biometrics
        ? l10n.useBiometrics
        : l10n.useBiometricMethod(method);
  }

  String promptTitle(AppLocalizations l10n) {
    final method = displayName(l10n);
    return method == l10n.biometrics
        ? '${l10n.useBiometrics}?'
        : l10n.useBiometricMethodQuestion(method);
  }

  String promptDescription(AppLocalizations l10n) {
    final method = displayName(l10n) == l10n.biometrics
        ? l10n.deviceBiometrics
        : displayName(l10n);
    return l10n.unlockMonekoFasterWithBiometricMethod(method);
  }

  String localizedReason(AppLocalizations l10n) {
    final method = displayName(l10n) == l10n.biometrics
        ? l10n.biometrics.toLowerCase()
        : displayName(l10n);
    return l10n.unlockMonekoWithBiometricMethod(method);
  }
}

class AppLockState {
  const AppLockState({
    required this.status,
    this.config,
    this.biometricAvailability =
        const AppLockBiometricAvailability.unavailable(),
    this.failureReason,
  });

  const AppLockState.disabled()
      : status = AppLockStatus.disabled,
        config = null,
        biometricAvailability =
            const AppLockBiometricAvailability.unavailable(),
        failureReason = null;

  final AppLockStatus status;
  final AppLockConfig? config;
  final AppLockBiometricAvailability biometricAvailability;
  final AppLockFailureReason? failureReason;

  bool get isEnabled => config != null || status != AppLockStatus.disabled;
  bool get isConfigured => config != null;
  bool get isUnlocked => status == AppLockStatus.unlocked;
  bool get biometricAvailable => biometricAvailability.canAuthenticate;
  String biometricDisplayName(AppLocalizations l10n) =>
      biometricAvailability.displayName(l10n);
  String? failedMessage(AppLocalizations l10n) {
    return switch (failureReason) {
      AppLockFailureReason.incorrectPasscode => l10n.incorrectPasscode,
      AppLockFailureReason.tryAgainLater => l10n.tryAgainLater,
      null => null,
    };
  }

  bool get shouldBlockApp =>
      status == AppLockStatus.locked || status == AppLockStatus.lockedOut;
  bool get canUseBiometrics =>
      config?.biometricEnabled == true && biometricAvailability.canAuthenticate;

  AppLockState copyWith({
    AppLockStatus? status,
    AppLockConfig? config,
    bool clearConfig = false,
    AppLockBiometricAvailability? biometricAvailability,
    AppLockFailureReason? failureReason,
    bool clearFailedMessage = false,
  }) {
    return AppLockState(
      status: status ?? this.status,
      config: clearConfig ? null : config ?? this.config,
      biometricAvailability:
          biometricAvailability ?? this.biometricAvailability,
      failureReason:
          clearFailedMessage ? null : failureReason ?? this.failureReason,
    );
  }
}

abstract class AppLockBiometricService {
  Future<AppLockBiometricAvailability> getAvailability();
  Future<bool> authenticate();
}

class LocalAuthAppLockBiometricService implements AppLockBiometricService {
  LocalAuthAppLockBiometricService({
    LocalAuthentication? localAuthentication,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<AppLockBiometricAvailability> getAvailability() async {
    final platform = defaultTargetPlatform;
    if (kIsWeb) {
      return AppLockBiometricAvailability.unavailable(platform: platform);
    }
    try {
      final deviceSupported = await _localAuthentication.isDeviceSupported();
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      final available = await _localAuthentication.getAvailableBiometrics();
      return AppLockBiometricAvailability(
        canAuthenticate:
            deviceSupported && canCheckBiometrics && available.isNotEmpty,
        types: available,
        platform: platform,
      );
    } catch (_) {
      return AppLockBiometricAvailability.unavailable(platform: platform);
    }
  }

  @override
  Future<bool> authenticate() async {
    final availability = await getAvailability();
    if (!availability.canAuthenticate) {
      return false;
    }
    try {
      return _localAuthentication.authenticate(
        localizedReason: availability.localizedReason(AppLocalizationsEn()),
        options: const AuthenticationOptions(
          biometricOnly: true,
          sensitiveTransaction: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController({
    required String userId,
    required AppLockRepository repository,
    required AppLockPasscodeHasher hasher,
    required AppLockBiometricService biometricService,
    required bool isEnabledFlagSet,
    required Future<void> Function(bool enabled) setEnabledFlag,
    DateTime Function()? now,
  })  : _userId = userId,
        _repository = repository,
        _hasher = hasher,
        _biometricService = biometricService,
        _setEnabledFlag = setEnabledFlag,
        _now = now ?? DateTime.now,
        super(
          userId.isEmpty
              ? const AppLockState.disabled()
              : isEnabledFlagSet
                  ? const AppLockState(status: AppLockStatus.locked)
                  : const AppLockState.disabled(),
        );

  static const int maxFailedAttempts = 5;
  static const Duration failedAttemptLockout = Duration(minutes: 1);

  final String _userId;
  final AppLockRepository _repository;
  final AppLockPasscodeHasher _hasher;
  final AppLockBiometricService _biometricService;
  final Future<void> Function(bool enabled) _setEnabledFlag;
  final DateTime Function() _now;

  DateTime? _backgroundedAt;

  Future<void> initialize() async {
    if (_userId.isEmpty) {
      state = const AppLockState.disabled();
      return;
    }

    final config = await _repository.loadConfig(_userId);
    if (!mounted) {
      return;
    }
    if (config == null) {
      await _setEnabledFlag(false);
      if (!mounted) {
        return;
      }
      state = const AppLockState.disabled();
      return;
    }

    final biometricAvailability = await _biometricService.getAvailability();
    if (!mounted) {
      return;
    }
    state = AppLockState(
      status: config.isLockedOut(_now())
          ? AppLockStatus.lockedOut
          : AppLockStatus.locked,
      config: config,
      biometricAvailability: biometricAvailability,
    );
  }

  Future<void> enable({
    required String passcode,
    bool biometricEnabled = false,
  }) async {
    final passcodeHash = await _hasher.hashPasscode(passcode);
    final biometricAvailability = await _biometricService.getAvailability();
    final config = AppLockConfig(
      userId: _userId,
      passcodeHashBase64: passcodeHash.hashBase64,
      saltBase64: passcodeHash.saltBase64,
      hashVersion: passcodeHash.version,
      biometricEnabled:
          biometricEnabled && biometricAvailability.canAuthenticate,
      lockTimeout: AppLockTimeout.immediately,
    );
    await _repository.saveConfig(config);
    await _setEnabledFlag(true);
    state = AppLockState(
      status: AppLockStatus.unlocked,
      config: config,
      biometricAvailability: biometricAvailability,
    );
  }

  Future<bool> verifyPasscode(String passcode) async {
    final config = state.config ?? await _repository.loadConfig(_userId);
    if (config == null) {
      state = const AppLockState.disabled();
      return false;
    }

    if (config.isLockedOut(_now())) {
      state = state.copyWith(
        status: AppLockStatus.lockedOut,
        config: config,
        failureReason: AppLockFailureReason.tryAgainLater,
      );
      return false;
    }

    final storedHash = AppLockPasscodeHash(
      version: config.hashVersion,
      saltBase64: config.saltBase64,
      hashBase64: config.passcodeHashBase64,
    );

    final verified = await _hasher.verifyPasscode(passcode, storedHash);
    if (verified) {
      final updated = config.copyWith(
        failedAttempts: 0,
        clearLockoutUntil: true,
      );
      await _repository.saveConfig(updated);
      state = state.copyWith(
        status: AppLockStatus.unlocked,
        config: updated,
        clearFailedMessage: true,
      );
      return true;
    }

    final failedAttempts = config.failedAttempts + 1;
    final lockedOut = failedAttempts >= maxFailedAttempts;
    final updated = config.copyWith(
      failedAttempts: failedAttempts,
      lockoutUntil:
          lockedOut ? _now().add(failedAttemptLockout) : config.lockoutUntil,
    );
    await _repository.saveConfig(updated);
    state = state.copyWith(
      status: lockedOut ? AppLockStatus.lockedOut : AppLockStatus.locked,
      config: updated,
      failureReason: lockedOut
          ? AppLockFailureReason.tryAgainLater
          : AppLockFailureReason.incorrectPasscode,
    );
    return false;
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!state.canUseBiometrics) {
      return false;
    }
    final authenticated = await _biometricService.authenticate();
    if (!authenticated) {
      return false;
    }
    final config = state.config;
    if (config == null) {
      return false;
    }
    final updated = config.copyWith(
      failedAttempts: 0,
      clearLockoutUntil: true,
    );
    await _repository.saveConfig(updated);
    state = state.copyWith(
      status: AppLockStatus.unlocked,
      config: updated,
      clearFailedMessage: true,
    );
    return true;
  }

  void lock() {
    if (state.config == null) {
      return;
    }
    state = state.copyWith(status: AppLockStatus.locked);
  }

  void markBackgrounded() {
    _backgroundedAt = _now();
  }

  void handleResumed() {
    final config = state.config;
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (config == null ||
        state.status != AppLockStatus.unlocked ||
        backgroundedAt == null) {
      return;
    }
    if (config.lockTimeout.duration == Duration.zero ||
        _now().difference(backgroundedAt) >= config.lockTimeout.duration) {
      lock();
    }
  }

  Future<bool> disableWithPasscode(String passcode) async {
    final verified = await verifyPasscode(passcode);
    if (!verified) {
      return false;
    }
    await _repository.deleteConfig(_userId);
    await _setEnabledFlag(false);
    state = const AppLockState.disabled();
    return true;
  }

  Future<void> clearForRecovery() async {
    await _repository.deleteConfig(_userId);
    await _setEnabledFlag(false);
    if (!mounted) {
      return;
    }
    state = const AppLockState.disabled();
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    final config = state.config;
    if (config == null) {
      return false;
    }
    final biometricAvailability = await _biometricService.getAvailability();
    if (enabled) {
      if (!biometricAvailability.canAuthenticate) {
        state = state.copyWith(biometricAvailability: biometricAvailability);
        return false;
      }
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        state = state.copyWith(biometricAvailability: biometricAvailability);
        return false;
      }
    }
    final updated = config.copyWith(
      biometricEnabled: enabled && biometricAvailability.canAuthenticate,
    );
    await _repository.saveConfig(updated);
    if (!mounted) {
      return false;
    }
    state = state.copyWith(
      config: updated,
      biometricAvailability: biometricAvailability,
    );
    return updated.biometricEnabled == enabled;
  }

  Future<void> setLockTimeout(AppLockTimeout timeout) async {
    final config = state.config;
    if (config == null) {
      return;
    }
    final updated = config.copyWith(lockTimeout: timeout);
    await _repository.saveConfig(updated);
    state = state.copyWith(config: updated);
  }

  Future<bool> changePasscode({
    required String currentPasscode,
    required String newPasscode,
  }) async {
    final verified = await verifyPasscode(currentPasscode);
    if (!verified) {
      return false;
    }
    final config = state.config;
    if (config == null) {
      return false;
    }
    final passcodeHash = await _hasher.hashPasscode(newPasscode);
    final updated = config.copyWith(
      passcodeHashBase64: passcodeHash.hashBase64,
      saltBase64: passcodeHash.saltBase64,
      hashVersion: passcodeHash.version,
      failedAttempts: 0,
      clearLockoutUntil: true,
    );
    await _repository.saveConfig(updated);
    state = state.copyWith(
      status: AppLockStatus.unlocked,
      config: updated,
      clearFailedMessage: true,
    );
    return true;
  }
}

String appLockEnabledPreferenceKey(String userId) {
  return 'moneko_app_lock_enabled:$userId';
}

final appLockRepositoryProvider = Provider<AppLockRepository>((ref) {
  return AppLockRepository(store: FlutterSecureAppLockStore());
});

final appLockPasscodeHasherProvider = Provider<AppLockPasscodeHasher>((ref) {
  return AppLockPasscodeHasher();
});

final appLockBiometricServiceProvider =
    Provider<AppLockBiometricService>((ref) {
  return LocalAuthAppLockBiometricService();
});

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  final auth = ref.watch(authProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final userId = auth.uid;
  final controller = AppLockController(
    userId: userId,
    repository: ref.watch(appLockRepositoryProvider),
    hasher: ref.watch(appLockPasscodeHasherProvider),
    biometricService: ref.watch(appLockBiometricServiceProvider),
    isEnabledFlagSet: userId.isNotEmpty &&
        (prefs.getBool(appLockEnabledPreferenceKey(userId)) ?? false),
    setEnabledFlag: (enabled) async {
      if (userId.isEmpty) {
        return;
      }
      await prefs.setBool(appLockEnabledPreferenceKey(userId), enabled);
    },
  );
  unawaited(controller.initialize());
  return controller;
});
