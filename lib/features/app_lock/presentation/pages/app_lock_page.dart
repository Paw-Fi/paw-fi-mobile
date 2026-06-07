import 'dart:ui';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/app_lock/presentation/widgets/app_lock_passcode_prompt.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class AppLockPage extends HookConsumerWidget {
  const AppLockPage({
    this.from,
    super.key,
  });

  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLockState = ref.watch(appLockControllerProvider);
    final isSubmitting = useState(false);
    final promptRevision = useState(0);

    Future<void> unlockWithPasscode(String passcode) async {
      if (isSubmitting.value) {
        return;
      }
      isSubmitting.value = true;
      final unlocked = await ref
          .read(appLockControllerProvider.notifier)
          .verifyPasscode(passcode);
      if (!context.mounted) {
        return;
      }
      isSubmitting.value = false;
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
      final unlocked = await ref
          .read(appLockControllerProvider.notifier)
          .authenticateWithBiometrics();
      if (!context.mounted) {
        return;
      }
      isSubmitting.value = false;
      if (unlocked) {
        _goToUnlockedDestination(context);
      }
    }

    Future<void> recoverBySigningOut() async {
      if (isSubmitting.value) {
        return;
      }
      isSubmitting.value = true;
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.signingOut,
      );

      try {
        final appLockRecovery =
            ref.read(appLockControllerProvider.notifier).clearForRecovery();
        final signOut = ref.read(authProvider.notifier).signOut();
        if (context.mounted) {
          context.go('/login');
        }
        await Future.wait([appLockRecovery, signOut]);
        if (rootNavigator.mounted && rootNavigator.canPop()) {
          rootNavigator.pop();
        }
      } catch (_) {
        if (rootNavigator.mounted && rootNavigator.canPop()) {
          rootNavigator.pop();
        }
        if (context.mounted) {
          AppToast.error(context, context.l10n.couldNotSignOutTryAgain);
        }
      } finally {
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }
    }

    useEffect(() {
      if (appLockState.canUseBiometrics) {
        Future.microtask(unlockWithBiometrics);
      }
      return null;
    }, [appLockState.canUseBiometrics]);

    return StatusBarOverlayRegion(
      child: AdaptiveScaffold(
        body: _AppLockBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                children: [
                  Expanded(
                    child: AppLockPasscodePrompt(
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
                      showBiometricButton: appLockState.canUseBiometrics,
                      biometricTooltip:
                          appLockState.biometricAvailability.actionLabel(
                        context.l10n,
                      ),
                      onBiometricPressed: unlockWithBiometrics,
                      onComplete: unlockWithPasscode,
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
        ),
      ),
    );
  }

  void _goToUnlockedDestination(BuildContext context) {
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

class _AppLockBackground extends StatelessWidget {
  const _AppLockBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    if (!isIOS) {
      return Material(
        color: colorScheme.appBackground,
        child: child,
      );
    }

    return Material(
      color: colorScheme.appBackground,
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: _AmbientGlow(
                color: colorScheme.primary.withValues(alpha: 0.15), size: 300),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: _AmbientGlow(
                color: colorScheme.secondary.withValues(alpha: 0.1), size: 400),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}
