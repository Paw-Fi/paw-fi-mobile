import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/app_lock/presentation/widgets/app_lock_passcode_prompt.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

enum AppLockSetupMode {
  enable,
  change,
  disable,
}

enum _AppLockSetupStep {
  current,
  create,
  confirm,
}

class AppLockSetupPage extends HookConsumerWidget {
  const AppLockSetupPage({
    required this.mode,
    super.key,
  });

  final AppLockSetupMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final step = useState(_initialStep(mode));
    final currentPasscode = useState<String?>(null);
    final newPasscode = useState<String?>(null);
    final errorText = useState<String?>(null);
    final promptRevision = useState(0);
    final biometricEnabled = useState(false);
    final isSubmitting = useState(false);
    final biometricAvailability = useFuture(
      useMemoized(
        () => ref.read(appLockBiometricServiceProvider).canAuthenticate(),
      ),
    );
    final biometricAvailable = biometricAvailability.data ?? false;

    void advanceTo(_AppLockSetupStep nextStep) {
      errorText.value = null;
      step.value = nextStep;
      promptRevision.value++;
    }

    void resetStep(String message) {
      errorText.value = message;
      promptRevision.value++;
    }

    NavigatorState showProcessing(String message) {
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      showBlockingProcessingDialog(
        context: context,
        message: message,
      );
      return rootNavigator;
    }

    void hideProcessing(NavigatorState rootNavigator) {
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }

    Future<void> finish({
      required String processingMessage,
      required Future<bool> Function() operation,
    }) async {
      if (isSubmitting.value) {
        return;
      }

      isSubmitting.value = true;
      final rootNavigator = showProcessing(processingMessage);
      try {
        final success = await operation();

        if (!context.mounted) {
          return;
        }
        hideProcessing(rootNavigator);
        if (!success) {
          resetStep('Incorrect passcode.');
          return;
        }
        AppToast.success(context, _successMessage(mode));
        Navigator.of(context).pop(true);
      } catch (_) {
        if (context.mounted) {
          hideProcessing(rootNavigator);
          resetStep('Could not update app lock.');
        }
      } finally {
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }
    }

    Future<void> handlePasscode(String passcode) async {
      final controller = ref.read(appLockControllerProvider.notifier);
      errorText.value = null;

      if (mode == AppLockSetupMode.disable) {
        await finish(
          processingMessage: 'Turning off App Lock...',
          operation: () => controller.disableWithPasscode(passcode),
        );
        return;
      }

      if (mode == AppLockSetupMode.change &&
          step.value == _AppLockSetupStep.current) {
        if (isSubmitting.value) {
          return;
        }
        isSubmitting.value = true;
        final rootNavigator = showProcessing('Checking passcode...');
        try {
          final verified = await controller.verifyPasscode(passcode);
          if (!context.mounted) {
            return;
          }
          hideProcessing(rootNavigator);
          if (!verified) {
            resetStep('Incorrect passcode.');
            return;
          }
          currentPasscode.value = passcode;
          advanceTo(_AppLockSetupStep.create);
        } catch (_) {
          if (context.mounted) {
            hideProcessing(rootNavigator);
            resetStep('Could not verify passcode.');
          }
        } finally {
          if (context.mounted) {
            isSubmitting.value = false;
          }
        }
        return;
      }

      if (step.value == _AppLockSetupStep.create) {
        newPasscode.value = passcode;
        advanceTo(_AppLockSetupStep.confirm);
        return;
      }

      if (step.value == _AppLockSetupStep.confirm) {
        if (newPasscode.value != passcode) {
          newPasscode.value = null;
          step.value = _AppLockSetupStep.create;
          resetStep('Passcodes do not match. Create a new passcode.');
          return;
        }

        await finish(
          processingMessage: mode == AppLockSetupMode.enable
              ? 'Turning on App Lock...'
              : 'Changing passcode...',
          operation: () async {
            if (mode == AppLockSetupMode.enable) {
              await controller.enable(
                passcode: passcode,
                biometricEnabled: biometricEnabled.value,
              );
              return true;
            }

            final current = currentPasscode.value;
            if (current == null) {
              return false;
            }
            return controller.changePasscode(
              currentPasscode: current,
              newPasscode: passcode,
            );
          },
        );
      }
    }

    return StatusBarOverlayRegion(
      child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: _title(mode)),
        body: Material(
          color: colorScheme.appBackground,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppLockPasscodePrompt(
                    key: ValueKey(
                      'app-lock-setup-${mode.name}-${step.value.name}'
                      '-${promptRevision.value}',
                    ),
                    title: _headline(mode, step.value),
                    subtitle: _description(mode, step.value),
                    errorText: errorText.value,
                    enabled: !isSubmitting.value,
                    isSubmitting: isSubmitting.value,
                    onComplete: handlePasscode,
                  ),
                  if (mode == AppLockSetupMode.enable &&
                      biometricAvailable) ...[
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colorScheme.border),
                      ),
                      child: SwitchListTile.adaptive(
                        value: biometricEnabled.value,
                        onChanged: (value) => biometricEnabled.value = value,
                        title: Text(
                          'Use Face ID or fingerprint',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        subtitle: Text(
                          'You can still use your passcode if biometrics fail.',
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _title(AppLockSetupMode mode) {
    return switch (mode) {
      AppLockSetupMode.enable => 'App Lock',
      AppLockSetupMode.change => 'Change Passcode',
      AppLockSetupMode.disable => 'Turn Off App Lock',
    };
  }

  static _AppLockSetupStep _initialStep(AppLockSetupMode mode) {
    return switch (mode) {
      AppLockSetupMode.enable => _AppLockSetupStep.create,
      AppLockSetupMode.change => _AppLockSetupStep.current,
      AppLockSetupMode.disable => _AppLockSetupStep.current,
    };
  }

  static String _headline(AppLockSetupMode mode, _AppLockSetupStep step) {
    return switch ((mode, step)) {
      (AppLockSetupMode.enable, _AppLockSetupStep.create) =>
        'Create a Moneko passcode',
      (AppLockSetupMode.enable, _AppLockSetupStep.confirm) =>
        'Confirm your passcode',
      (AppLockSetupMode.change, _AppLockSetupStep.current) =>
        'Enter current passcode',
      (AppLockSetupMode.change, _AppLockSetupStep.create) =>
        'Choose a new passcode',
      (AppLockSetupMode.change, _AppLockSetupStep.confirm) =>
        'Confirm new passcode',
      (AppLockSetupMode.disable, _) => 'Confirm your passcode',
      (_, _) => 'Create a Moneko passcode',
    };
  }

  static String _successMessage(AppLockSetupMode mode) {
    return switch (mode) {
      AppLockSetupMode.enable => 'App Lock is on.',
      AppLockSetupMode.change => 'Passcode changed.',
      AppLockSetupMode.disable => 'App Lock is off.',
    };
  }

  static String _description(AppLockSetupMode mode, _AppLockSetupStep step) {
    return switch ((mode, step)) {
      (AppLockSetupMode.enable, _AppLockSetupStep.create) =>
        'Enter six digits to protect Moneko on this device.',
      (AppLockSetupMode.enable, _AppLockSetupStep.confirm) =>
        'Enter the same six digits again.',
      (AppLockSetupMode.change, _AppLockSetupStep.current) =>
        'Verify your current six-digit passcode first.',
      (AppLockSetupMode.change, _AppLockSetupStep.create) =>
        'Enter the new six-digit passcode.',
      (AppLockSetupMode.change, _AppLockSetupStep.confirm) =>
        'Enter the same new passcode again.',
      (AppLockSetupMode.disable, _) =>
        'App Lock can only be turned off after verifying your passcode.',
      (_, _) => 'Enter six digits to continue.',
    };
  }
}
