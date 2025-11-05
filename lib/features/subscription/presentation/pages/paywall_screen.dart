import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/features/auth/auth.dart';
import '../providers/subscription_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  Future<void> _launchDiscord(WidgetRef ref) async {
    final user = ref.read(authProvider);
    
    if (user.isEmpty) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          const SnackBar(content: Text('Please log in to continue')),
        );
      }
      return;
    }

    if (!ref.context.mounted) return;

    // Show loading modal
    showDialog(
      context: ref.context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: shadcnui.Theme.of(context).colorScheme.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const shadcnui.CircularProgressIndicator(),
                const SizedBox(height: 24),
                shadcnui.Text(
                  'Opening Discord...',
                  style: shadcnui.Theme.of(context).typography.large,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                shadcnui.Text(
                  'Please wait',
                  style: shadcnui.Theme.of(context).typography.base,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      const discordUrl = 'https://discord.gg/M2Dgujvtze';

      if (!ref.context.mounted) return;
      Navigator.of(ref.context).pop();

      if (!await launchUrl(
        Uri.parse(discordUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not open Discord link');
      }
      
    } catch (e) {
      if (ref.context.mounted) {
        Navigator.of(ref.context).pop();
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text('Failed to open Discord: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    await ref.read(subscriptionNotifierProvider.notifier).refresh();

    final hasSubscription = ref.read(hasActiveSubscriptionProvider);

    if (hasSubscription && context.mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _handleRefresh(context, ref),
          color: colorScheme.primary,
          backgroundColor: colorScheme.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const SizedBox(height: 40),

              // Beta Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: ClipOval(
                    child: Image.asset(
                      'lib/assets/mascots/moneko.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'You\'re Early! 🚀',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Access opens soon — join our Discord to get verified and unlock early access!',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.mutedForeground,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Highlight Box
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Join our Discord channel to get early access!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Get verified, unlock exclusive features, connect with our community, and be among the first to experience the app.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

           

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: shadcnui.PrimaryButton(
                  onPressed: () => _launchDiscord(ref),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Join Discord for Early Access',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.buttonText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20, color: colorScheme.buttonText),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Footer Text
              Text(
                'Free to join • Limited spots • Exclusive perks',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
          ),
      ),
    );
  }
}
