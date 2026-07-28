import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/app_lock/presentation/widgets/app_lock_passcode_prompt.dart';
import 'package:moneko/features/app_lock/presentation/widgets/app_lock_visual_shell.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/app/user_financial_cache_cleanup.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class AppLockPage extends HookConsumerWidget {
  const AppLockPage({
    this.from,
    this.onUnlocked,
    this.renderAsOverlay = false,
    super.key,
  });

  final String? from;
  final VoidCallback? onUnlocked;
  final bool renderAsOverlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLockState = ref.watch(appLockControllerProvider);
    final isSubmitting = useState(false);
    final promptRevision = useState(0);
    final biometricAvailability = appLockState.biometricAvailability;
    final canUnlockWithBiometrics =
        appLockState.shouldBlockApp && appLockState.canUseBiometrics;
    final hasFaceId = biometricAvailability.hasFace &&
        (biometricAvailability.platform == TargetPlatform.iOS ||
            biometricAvailability.platform == TargetPlatform.macOS);
    final biometricIcon = hasFaceId
        ? SvgPicture.asset(
            'lib/assets/images/face-id.svg',
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          )
        : Icon(
            Icons.fingerprint_rounded,
            size: 26,
            color: Theme.of(context).colorScheme.onSurface,
          );

    Future<void> unlockWithPasscode(String passcode) async {
      if (isSubmitting.value) {
        return;
      }
      isSubmitting.value = true;
      var unlocked = false;
      try {
        unlocked = await ref
            .read(appLockControllerProvider.notifier)
            .verifyPasscode(passcode);
      } catch (_) {
        if (context.mounted) {
          promptRevision.value++;
        }
        return;
      } finally {
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }

      if (!context.mounted) {
        return;
      }
      if (!unlocked) {
        promptRevision.value++;
        return;
      }

      _goToUnlockedDestination(context);
    }

    Future<void> unlockWithBiometrics() async {
      if (isSubmitting.value) {
        return;
      }
      isSubmitting.value = true;
      var unlocked = false;
      try {
        unlocked = await ref
            .read(appLockControllerProvider.notifier)
            .authenticateWithBiometrics();
      } catch (_) {
        if (context.mounted) {
          isSubmitting.value = false;
        }
        return;
      }

      if (!context.mounted) {
        return;
      }
      if (unlocked) {
        _goToUnlockedDestination(context);
        return;
      }

      isSubmitting.value = false;
    }

    Future<void> recoverBySigningOut() async {
      if (isSubmitting.value) {
        return;
      }
      isSubmitting.value = true;
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final router = GoRouter.of(context);
      final originalLocation =
          router.routeInformationProvider.value.uri.toString();
      final appLockController = ref.read(appLockControllerProvider.notifier);
      final authController = ref.read(authProvider.notifier);
      var processingDialogOpen = false;

      void closeProcessingDialog() {
        if (!processingDialogOpen) {
          return;
        }
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
        }
        processingDialogOpen = false;
      }

      try {
        if (context.mounted) {
          showBlockingProcessingDialog(
            context: rootNavigator.context,
            message: context.l10n.signingOut,
          );
          processingDialogOpen = true;
        }

        try {
          await appLockController.clearForRecovery();
        } catch (_) {
          await appLockController.clearForRecovery();
        }

        try {
          final userId = ref.read(authProvider).uid;
          try {
            await ref.read(selectedHouseholdProvider.notifier).clearSelection();
          } catch (_) {}
          try {
            await ref.read(appInitializationV2Provider.notifier).onLogout();
          } catch (_) {}
          await ref.read(userFinancialCacheCleanupProvider).clearForLogout(
                userId: userId,
                signOut: authController.signOut,
              );
        } catch (error) {
          // Supabase removes the local session before attempting remote token
          // revocation. The user is safely signed out on this device even when
          // that remote revocation request fails.
          debugPrint('Remote sign-out cleanup failed: $error');
        }

        closeProcessingDialog();
        router.go('/login');
      } catch (_) {
        closeProcessingDialog();
        router.go(originalLocation);
        final toastContext = rootNavigator.context;
        if (toastContext.mounted) {
          AppToast.error(
            toastContext,
            toastContext.l10n.couldNotUpdateAppLock,
          );
        }
      } finally {
        closeProcessingDialog();
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }
    }

    useEffect(() {
      if (canUnlockWithBiometrics) {
        Future.microtask(unlockWithBiometrics);
      }
      return null;
    }, [canUnlockWithBiometrics]);

    final content = AppLockBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppLockPasscodePrompt(
                      key: ValueKey(
                        'app-lock-unlock-${promptRevision.value}',
                      ),
                      title: context.l10n.unlockMoneko,
                      subtitle: appLockState.status == AppLockStatus.lockedOut
                          ? context.l10n.tooManyAttemptsTryAgainShortly
                          : context.l10n.enterYourPasscode,
                      errorText: appLockState.failedMessage(context.l10n),
                      enabled: !isSubmitting.value,
                      isSubmitting: isSubmitting.value,
                      showBiometricButton: canUnlockWithBiometrics,
                      biometricIcon: biometricIcon,
                      biometricTooltip:
                          appLockState.biometricAvailability.actionLabel(
                        context.l10n,
                      ),
                      onBiometricPressed: unlockWithBiometrics,
                      onComplete: unlockWithPasscode,
                    ),
                    AppLockLoadingOverlay(isLoading: isSubmitting.value),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isSubmitting.value ? null : recoverBySigningOut,
                child: Text(
                  context.l10n.forgotPasscodeSignOut,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (renderAsOverlay) {
      return SizedBox.expand(
        child: StatusBarOverlayRegion(child: content),
      );
    }

    return StatusBarOverlayRegion(
      child: AdaptiveScaffold(body: content),
    );
  }

  void _goToUnlockedDestination(BuildContext context) {
    final handleUnlocked = onUnlocked;
    if (handleUnlocked != null) {
      handleUnlocked();
      return;
    }

    final target = from;
    if (target != null &&
        target.isNotEmpty &&
        target != '/app-lock' &&
        !target.startsWith('/app-lock?')) {
      context.go(target);
      return;
    }
    context.go('/dashboard');
  }
}
