import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:url_launcher/url_launcher.dart';
import '../providers/subscription_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  Future<void> _launchPricing() async {
    final Uri url = Uri.parse('https://www.moneko.io/pricing');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    // Refresh subscription status from database
    await ref.read(subscriptionNotifierProvider.notifier).refresh();

    // Check if user is now subscribed
    final hasSubscription = ref.read(hasActiveSubscriptionProvider);

    if (hasSubscription) {
      debugPrint('✅ Subscription detected! Redirecting to dashboard...');
      if (context.mounted) {
        context.go('/dashboard');
      }
    } else {
      debugPrint('ℹ️ Still on free plan');
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

              // Rocket Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '🚀',
                    style: TextStyle(fontSize: 50),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Unlock Premium Features!',
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
                'This app is available exclusively to our Plus Plan members — and we\'ve got something special for you! 🎁',
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
                    Text(
                      'Enjoy 1 month of Plus access, completely free — no strings attached.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Get access to advanced tools, faster performance, and an even smoother experience.',
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

              // Features List
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _FeatureItem(
                      text: 'Advanced AI-powered insights',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      text: 'Unlimited scenario planning',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      text: 'Priority support',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      text: 'Enhanced security features',
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: shadcnui.PrimaryButton(
                  onPressed: _launchPricing,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Free Trial',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Footer Text
              Text(
                'Cancel anytime • No credit card required',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
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

class _FeatureItem extends StatelessWidget {
  final String text;
  final shadcnui.ColorScheme colorScheme;

  const _FeatureItem({
    required this.text,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.foreground,
            ),
          ),
        ),
      ],
    );
  }
}
