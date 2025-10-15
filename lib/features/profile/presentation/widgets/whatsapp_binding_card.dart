import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/profile_helpers.dart';
import 'package:moneko/features/profile/presentation/widgets/whatsapp_tutorial_modal.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildWhatsAppBindingCard(BuildContext context, WidgetRef ref) {
  final colorScheme = shadcnui.Theme.of(context).colorScheme;
  final whatsappBinding = ref.watch(whatsAppBindingProvider);

    Future<void> handleBindWhatsApp() async {
      // This wa link doesnt contains a "start" welcome message
      final Uri url = Uri.parse('https://wa.link/zxwtld');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          Navigator.of(context).pop(true); // Return true to refresh status
        }
      }
    }

  return whatsappBinding.when(
    data: (isBound) {
      if (isBound) {
        // Success state - show connected
        return InkWell(
          onTap: () => handleBindWhatsApp(),
          child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF25D366),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Connected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log expenses via WhatsApp messages',
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
        ));
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
                const Color(0xFF25D366).withOpacity(0.1),
                const Color(0xFF128C7E).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.3),
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
                              'Connect WhatsApp',
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
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Log expenses instantly via chat',
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
                  buildBenefitIcon(context, Icons.flash_on, 'Fast'),
                  buildBenefitIcon(context, Icons.receipt, 'Photo'),
                  buildBenefitIcon(context, Icons.sync, 'Auto-sync'),
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
