import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/features/auth/auth.dart';
import '../providers/subscription_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  Future<void> _launchCheckout(WidgetRef ref) async {
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
      barrierColor: Colors.black.withOpacity(0.5),
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
                  color: Colors.black.withOpacity(0.2),
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
                  'Creating checkout session...',
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
      final response = await supabase.functions.invoke(
        'create-checkout-session',
        body: {
          'plan': 'plus',
          'billingInterval': 'monthly',
          'successUrl': '${DeepLinks.paymentCallback}?status=success&session_id={CHECKOUT_SESSION_ID}',
          'cancelUrl': '${DeepLinks.paymentCallback}?status=canceled&session_id={CHECKOUT_SESSION_ID}',
        },
      );

      if (!ref.context.mounted) return;
      Navigator.of(ref.context).pop();

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? response.data?['message'] ?? 'Unknown error';
        throw Exception('Server error: $errorMsg');
      }

      if (response.data == null) {
        throw Exception('No data returned from server');
      }

      final checkoutUrl = response.data['checkoutUrl'] as String?;
      
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL in response');
      }

      if (!await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not open browser');
      }
      
    } catch (e) {
      if (ref.context.mounted) {
        Navigator.of(ref.context).pop();
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text('Failed to start checkout: ${e.toString()}'),
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

           

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: shadcnui.PrimaryButton(
                  onPressed: () => _launchCheckout(ref),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Free Trial',
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
