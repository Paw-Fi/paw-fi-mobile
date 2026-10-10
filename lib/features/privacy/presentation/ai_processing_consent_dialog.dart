import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/privacy/presentation/ai_processing_consent_provider.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:url_launcher/url_launcher.dart';

const aiProcessingPrivacyPolicyUrl = 'https://moneko.io/privacy-policy';

Future<bool> ensureAiProcessingConsent(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return Future.value(false);
  final notifier = ref.read(aiProcessingConsentProvider.notifier);
  if (notifier.disclosureRequest != null) return Future.value(false);
  return notifier.disclosureRequest = _ensure(context, ref, notifier)
      .whenComplete(() => notifier.disclosureRequest = null);
}

Future<bool> _ensure(BuildContext context, WidgetRef ref,
    AiProcessingConsentNotifier notifier) async {
  if (!notifier.isCurrentActor) return false;
  var accountChanged = false;
  DialogRoute<bool>? route;
  final navigator = Navigator.of(context, rootNavigator: true);
  // Keep the account-owned cache alive while loading local preferences.
  final consentSubscription =
      ref.listenManual(aiProcessingConsentProvider, (_, __) {});
  final subscription =
      ref.listenManual(authProvider.select((user) => user.uid), (_, next) {
    accountChanged = true;
    final activeRoute = route;
    if (activeRoute != null && activeRoute.isActive && navigator.mounted) {
      navigator.removeRoute(activeRoute, false);
    }
  });
  try {
    final verified = await notifier.refresh();
    if (!context.mounted || accountChanged || !notifier.isCurrentActor) {
      return false;
    }
    if (verified) return true;
    if (ref.read(aiProcessingConsentProvider).error != null ||
        ref.read(aiProcessingConsentProvider).isSaving) {
      AppToast.error(context, context.l10n.aiConsentError);
      return false;
    }
    route = _AiProcessingConsentRoute(
      context: context,
      notifier: notifier,
    );
    final accepted = await navigator.push(route);
    return context.mounted &&
        !accountChanged &&
        notifier.isCurrentActor &&
        accepted == true &&
        ref.read(aiProcessingConsentProvider).mayProcess;
  } catch (_) {
    if (context.mounted && !accountChanged && notifier.isCurrentActor) {
      AppToast.error(context, context.l10n.aiConsentError);
    }
    return false;
  } finally {
    subscription.close();
    consentSubscription.close();
  }
}

class _AiProcessingConsentRoute extends DialogRoute<bool> {
  _AiProcessingConsentRoute({required super.context, required this.notifier})
      : super(builder: (_) => AiProcessingConsentDialog(notifier: notifier));

  final AiProcessingConsentNotifier notifier;

  @override
  void didComplete(bool? result) {
    // Cancel before completing the route future or running dismissal animations.
    if (result != true) notifier.cancelPendingGrant();
    super.didComplete(result);
  }
}

class AiProcessingConsentDialog extends ConsumerWidget {
  const AiProcessingConsentDialog({super.key, required this.notifier});

  final AiProcessingConsentNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiProcessingConsentProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    void close(bool accepted) {
      if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(accepted);
      }
    }

    final dialog = Dialog(
      backgroundColor: scheme.sheetBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.sheetBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.aiConsentTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(l10n.aiConsentProviderDisclosure),
              const SizedBox(height: 12),
              Text(l10n.aiConsentDataDisclosure),
              const SizedBox(height: 12),
              Text(l10n.aiConsentChoiceDisclosure),
              const SizedBox(height: 12),
              PrimaryAdaptiveButton.outlined(
                onPressed: () async {
                  try {
                    if (!await launchUrl(
                        Uri.parse(aiProcessingPrivacyPolicyUrl),
                        mode: LaunchMode.externalApplication)) {
                      throw StateError('Privacy policy unavailable');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      AppToast.error(context, l10n.aiConsentPrivacyLinkError);
                    }
                  }
                },
                child: Text(l10n.aiConsentPrivacyPolicy),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                child: state.error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(l10n.aiConsentError,
                            style: TextStyle(color: scheme.error)),
                      ),
              ),
              const SizedBox(height: 20),
              PrimaryAdaptiveButton(
                onPressed: state.isSaving || !notifier.isCurrentActor
                    ? null
                    : () async {
                        final saved = await notifier.setGranted(true);
                        if (saved && notifier.isCurrentActor) close(true);
                      },
                child: Text(state.isSaving
                    ? l10n.aiConsentSaving
                    : l10n.aiConsentAllow),
              ),
              const SizedBox(height: 12),
              PrimaryAdaptiveButton.outlined(
                onPressed: state.isCommitting ? null : () => close(false),
                child: Text(l10n.aiConsentNotNow),
              ),
            ],
          ),
        ),
      ),
    );
    return PopScope<bool>(canPop: !state.isCommitting, child: dialog);
  }
}
