import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/profile_helpers.dart';
import 'package:moneko/features/profile/presentation/widgets/whatsapp_tutorial_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildWhatsAppBindingCard(BuildContext context, WidgetRef ref) {
  final colorScheme = Theme.of(context).colorScheme;
  final whatsappBinding = ref.watch(whatsAppBindingProvider);

  Future<void> handleBindWhatsApp() async {
    // This wa link doesnt contains a "start" welcome message
    final Uri url = Uri.parse('https://wa.link/zxwtld');
    try {
      // Prefer external browser/WhatsApp if available
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // Some Android emulators/devices may not have a browser handler.
        // Fall back to an in-app webview so the flow still works.
        launched = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
      if (!launched) {
        // Final fallback
        launched = await launchUrl(url, mode: LaunchMode.inAppWebView);
      }
      if (launched && context.mounted) {
        Navigator.of(context).pop(true); // Return true to refresh status
      } else if (!launched) {
        AppToast.error(
          context,
          'Unable to open WhatsApp link. Please install a browser or WhatsApp.',
        );
      }
    } catch (_) {
      AppToast.error(context, 'Could not launch WhatsApp link.');
    }
  }

  return whatsappBinding.when(
    data: (isBound) {
      if (isBound) {
        // Success state - show connected
        return InkWell(
          onTap: () => handleBindWhatsApp(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.whatsappGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_rounded,
                  color: AppTheme.whatsappGreen,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.whatsAppConnected,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.logExpensesViaWhatsApp,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        );
      }

      // CTA state - not bound yet
      return GestureDetector(
        onTap: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const WhatsAppTutorialModal(),
          );
          if (result == true) {
            ref.invalidate(whatsAppBindingProvider);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.whatsappGreen.withValues(alpha: 0.1),
                AppTheme.whatsappDarkGreen.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.whatsappGreen.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.l10n.connectWhatsApp,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.foreground,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.whatsappGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                context.l10n.newBadge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primaryForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.logExpensesInstantly,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: colorScheme.foreground,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildBenefitIcon(context, Icons.flash_on, context.l10n.fast),
                  buildBenefitIcon(context, Icons.receipt, context.l10n.photo),
                  buildBenefitIcon(context, Icons.sync, context.l10n.autoSync),
                ],
              ),
            ],
          ),
        ),
      );
    },
    loading: () => Container(
      height: 120,
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    ),
    error: (error, stack) => const SizedBox.shrink(),
  );
}
