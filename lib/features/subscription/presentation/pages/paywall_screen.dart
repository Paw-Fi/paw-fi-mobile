import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/core.dart';
import '../providers/subscription_provider.dart';
import '../providers/referral_code_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final hasReferralCodeAsync = ref.watch(referralCodeCheckerProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _handleRefresh(ref, context),
          color: colorScheme.primary,
          backgroundColor: colorScheme.card,
          child: hasReferralCodeAsync.when(
            data: (hasReferralCode) => _buildContent(context, ref, colorScheme, hasReferralCode, user),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildContent(context, ref, colorScheme, false, user),
          ),
        ),
      ),
    );
  }

  static Future<void> _launchReferralPage(BuildContext context) async {
    const referralUrl = 'https://moneko.io/referral';

    // Show loading modal
    showDialog(
      context: context,
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
                  'Opening Referral Page...',
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
      Navigator.of(context).pop();

      if (!await launchUrl(
        Uri.parse(referralUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not open referral link');
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open referral page: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
    }
  }

  static Future<void> _launchDiscord(BuildContext context) async {
    const discordUrl = 'https://discord.gg/M2Dgujvtze';

    try {
      if (!await launchUrl(
        Uri.parse(discordUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not open Discord link');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open Discord: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
    }
  }

  static Future<void> _claimTrialAccess(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider);

    if (user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    // Show loading modal
    showDialog(
      context: context,
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
                  'Starting your trial...',
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
      final session = supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      final response = await supabase.functions.invoke(
        'create-checkout-session',
        body: {
          'plan': 'plus',
          'billingInterval': 'monthly',
          'successUrl': 'https://moneko.io/checkout/success?status=success&flow=trial&session_id={CHECKOUT_SESSION_ID}',
          'cancelUrl': 'https://moneko.io/checkout/cancel?status=canceled&flow=trial',
        },
      );

      Navigator.of(context).pop();

      if (response.data != null && response.data['checkoutUrl'] != null) {
        final checkoutUrl = response.data['checkoutUrl'] as String;
        if (!await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception('Could not open checkout page');
        }
      } else {
        throw Exception('No checkout URL received');
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start trial: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
    }
  }

  static Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authProvider.notifier).signOut();
      context.go('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  static Future<void> _handleRefresh(WidgetRef ref, BuildContext context) async {
    await ref.read(subscriptionNotifierProvider.notifier).refresh();
    await ref.read(referralCodeCheckerProvider.notifier).refresh();

    final hasSubscription = ref.read(hasActiveSubscriptionProvider);
    if (hasSubscription) {
      context.go('/dashboard');
    }
  }

  static Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    dynamic colorScheme,
    bool hasReferralCode,
    AppUser user,
  ) {
    // Extract user name from email or use full name if available
    final userName = user.email.split('@').first.isNotEmpty ? user.email.split('@').first : 'User';
    final displayName = (user.displayName?.isNotEmpty ?? false) ? user.displayName?.split(' ').first ?? userName : userName;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          // Title
          Text(
            hasReferralCode ? 'Welcome, $displayName!' : 'Welcome, $displayName!',
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
            hasReferralCode
                ? 'Get 1 month free access while you wait for friends to join!'
                : 'Join our referral program and invite friends to unlock lifetime access!',
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
                        text: hasReferralCode
                            ? 'Test the app with 1 month free access - no credit card required!'
                            : 'Invite friends and when they join, both of you get lifetime access!',
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
                  hasReferralCode
                      ? 'Once your friend accepts your invite, you\'ll both automatically upgrade to lifetime access.'
                      : 'Visit our referral page to get your unique referral link, share it with friends, and unlock exclusive lifetime features when they join.',
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
              onPressed: () => hasReferralCode ? _claimTrialAccess(context, ref) : _launchReferralPage(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasReferralCode ? 'Claim 1 Month Free Access' : 'Join Referral Program',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.primaryForeground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20, color: colorScheme.primaryForeground),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Footer Text
          Text(
            hasReferralCode
                ? 'No credit card • Limited time • Instant upgrade'
                : 'Free to join • Limited spots • Exclusive perks',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          // Discord Link
          GestureDetector(
            onTap: () => _launchDiscord(context),
            child: Text(
              'Join our Discord for instant support',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

  

                  const SizedBox(height: 15),

          // Not your account link
          GestureDetector(
            onTap: () => _handleLogout(context, ref),
            child: Text(
              'Not ${user.email}?',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.mutedForeground,
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        ],
      ),
    );
  }
}
