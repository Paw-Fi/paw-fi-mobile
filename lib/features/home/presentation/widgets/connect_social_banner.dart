import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/home/presentation/widgets/connect_social_bottom_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart'; // For sharedPreferencesProvider
import 'package:moneko/core/preview/preview_mode_provider.dart';

final connectSocialBannerDismissedProvider = StateProvider<bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return prefs.getBool('connect_social_banner_dismissed') ?? false;
});

class ConnectSocialBanner extends HookConsumerWidget {
  const ConnectSocialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreview = ref.watch(previewModeProvider).isActive;
    if (isPreview) {
      return const SizedBox.shrink();
    }

    final isDismissed = ref.watch(connectSocialBannerDismissedProvider);
    final whatsAppAsync = ref.watch(whatsAppBindingProvider);
    final telegramAsync = ref.watch(telegramBindingProvider);

    final isWhatsAppConnected = whatsAppAsync.valueOrNull == true;
    final isTelegramConnected = telegramAsync.valueOrNull == true;

    if (isDismissed || isWhatsAppConnected || isTelegramConnected) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.connect_without_contact,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Connect Telegram or WhatsApp',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interact with our AI using your favorite messaging app for an easier logging experience.',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryAdaptiveButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const ConnectSocialBottomSheet(),
                        );
                      },
                      child: const Text('Connect'),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                  ref.read(connectSocialBannerDismissedProvider.notifier).state = true;
                  final prefs = ref.read(sharedPreferencesProvider);
                  await prefs.setBool('connect_social_banner_dismissed', true);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
