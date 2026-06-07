import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/app_lock/presentation/widgets/app_lock_passcode_prompt.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
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
    final isSubmitting = useState(false);
    final biometricAvailability = useFuture(
      useMemoized(
        () => ref.read(appLockBiometricServiceProvider).getAvailability(),
      ),
    );
    final availableBiometrics = biometricAvailability.data ??
        const AppLockBiometricAvailability.unavailable();

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

    Future<bool> askForBiometricOptIn() async {
      if (mode != AppLockSetupMode.enable ||
          !availableBiometrics.canAuthenticate) {
        return false;
      }

      final result = await MonekoAlertDialog.show(
        context: context,
        title: availableBiometrics.promptTitle(context.l10n),
        description: availableBiometrics.promptDescription(context.l10n),
        confirmLabel: availableBiometrics.actionLabel(context.l10n),
        cancelLabel: context.l10n.notNow,
      );

      if (!context.mounted || result?.confirmed != true) {
        return false;
      }

      final authenticated =
          await ref.read(appLockBiometricServiceProvider).authenticate();
      if (!authenticated && context.mounted) {
        AppToast.info(
          context,
          context.l10n.biometricUnlockNotEnabledPasscodeSaved,
        );
      }
      return authenticated;
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
          resetStep(context.l10n.incorrectPasscodeSentence);
          return;
        }
        AppToast.success(context, _successMessage(context.l10n, mode));
        Navigator.of(context).pop(true);
      } catch (_) {
        if (context.mounted) {
          hideProcessing(rootNavigator);
          resetStep(context.l10n.couldNotUpdateAppLock);
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
          processingMessage: context.l10n.turningOffAppLock,
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
        final rootNavigator = showProcessing(context.l10n.checkingPasscode);
        try {
          final verified = await controller.verifyPasscode(passcode);
          if (!context.mounted) {
            return;
          }
          hideProcessing(rootNavigator);
          if (!verified) {
            resetStep(context.l10n.incorrectPasscodeSentence);
            return;
          }
          currentPasscode.value = passcode;
          advanceTo(_AppLockSetupStep.create);
        } catch (_) {
          if (context.mounted) {
            hideProcessing(rootNavigator);
            resetStep(context.l10n.couldNotVerifyPasscode);
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
          resetStep(context.l10n.passcodesDoNotMatchCreateNewPasscode);
          return;
        }

        final processingMessage = mode == AppLockSetupMode.enable
            ? context.l10n.turningOnAppLock
            : context.l10n.changingPasscode;
        final biometricOptedIn = await askForBiometricOptIn();

        await finish(
          processingMessage: processingMessage,
          operation: () async {
            if (mode == AppLockSetupMode.enable) {
              await controller.enable(
                passcode: passcode,
                biometricEnabled: biometricOptedIn,
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
        appBar: AdaptiveAppBar(title: _title(context.l10n, mode)),
        body: Material(
          color: colorScheme.appBackground,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                getSubPageTopPadding(context) + 24,
                16,
                32,
              ),
              child: AppLockPasscodePrompt(
                key: ValueKey(
                  'app-lock-setup-${mode.name}-${step.value.name}'
                  '-${promptRevision.value}',
                ),
                title: _headline(context.l10n, mode, step.value),
                subtitle: _description(context.l10n, mode, step.value),
                errorText: errorText.value,
                enabled: !isSubmitting.value,
                isSubmitting: isSubmitting.value,
                onComplete: handlePasscode,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _title(
    AppLocalizations l10n,
    AppLockSetupMode mode,
  ) {
    return switch (mode) {
      AppLockSetupMode.enable => l10n.appLock,
      AppLockSetupMode.change => l10n.changePasscode,
      AppLockSetupMode.disable => l10n.turnOffAppLock,
    };
  }

  static _AppLockSetupStep _initialStep(AppLockSetupMode mode) {
    return switch (mode) {
      AppLockSetupMode.enable => _AppLockSetupStep.create,
      AppLockSetupMode.change => _AppLockSetupStep.current,
      AppLockSetupMode.disable => _AppLockSetupStep.current,
    };
  }

  static String _headline(
    AppLocalizations l10n,
    AppLockSetupMode mode,
    _AppLockSetupStep step,
  ) {
    return switch ((mode, step)) {
      (AppLockSetupMode.enable, _AppLockSetupStep.create) =>
        l10n.createMonekoPasscode,
      (AppLockSetupMode.enable, _AppLockSetupStep.confirm) =>
        l10n.confirmYourPasscode,
      (AppLockSetupMode.change, _AppLockSetupStep.current) =>
        l10n.enterCurrentPasscode,
      (AppLockSetupMode.change, _AppLockSetupStep.create) =>
        l10n.chooseNewPasscode,
      (AppLockSetupMode.change, _AppLockSetupStep.confirm) =>
        l10n.confirmNewPasscode,
      (AppLockSetupMode.disable, _) => l10n.confirmYourPasscode,
      (_, _) => l10n.createMonekoPasscode,
    };
  }

  static String _successMessage(
    AppLocalizations l10n,
    AppLockSetupMode mode,
  ) {
    return switch (mode) {
      AppLockSetupMode.enable => l10n.appLockIsOn,
      AppLockSetupMode.change => l10n.passcodeChanged,
      AppLockSetupMode.disable => l10n.appLockIsOff,
    };
  }

  static String _description(
    AppLocalizations l10n,
    AppLockSetupMode mode,
    _AppLockSetupStep step,
  ) {
    return switch ((mode, step)) {
      (AppLockSetupMode.enable, _AppLockSetupStep.create) =>
        l10n.enterSixDigitsToProtectMoneko,
      (AppLockSetupMode.enable, _AppLockSetupStep.confirm) =>
        l10n.enterSameSixDigitsAgain,
      (AppLockSetupMode.change, _AppLockSetupStep.current) =>
        l10n.verifyCurrentSixDigitPasscodeFirst,
      (AppLockSetupMode.change, _AppLockSetupStep.create) =>
        l10n.enterNewSixDigitPasscode,
      (AppLockSetupMode.change, _AppLockSetupStep.confirm) =>
        l10n.enterSameNewPasscodeAgain,
      (AppLockSetupMode.disable, _) => l10n.appLockDisableRequiresPasscode,
      (_, _) => l10n.enterSixDigitsToContinue,
    };
  }
}
