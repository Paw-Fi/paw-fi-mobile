import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';
import 'package:moneko/shared/widgets/plain-adaptive-button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import '../providers/subscription_provider.dart';
import '../providers/referral_code_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasReferralCodeAsync = ref.watch(referralCodeCheckerProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: hasReferralCodeAsync.when(
        data: (hasReferralCode) => _PaywallContent(
          hasReferralCode: hasReferralCode,
          user: user,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _PaywallContent(
          hasReferralCode: false,
          user: user,
        ),
      ),
    );
  }
}

class _PaywallContent extends ConsumerStatefulWidget {
  final bool hasReferralCode;
  final AppUser user;

  const _PaywallContent({
    required this.hasReferralCode,
    required this.user,
  });

  @override
  ConsumerState<_PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends ConsumerState<_PaywallContent> {
  bool _isLoading = false;

  Future<void> _handleRefresh() async {
    await ref.read(subscriptionNotifierProvider.notifier).refresh();
    await ref.read(referralCodeCheckerProvider.notifier).refresh();

    if (!mounted) return;

    final hasSubscription = ref.read(hasActiveSubscriptionProvider);
    if (hasSubscription) {
      context.go('/dashboard');
    }
  }

  Future<void> _launchReferralPage() async {
    const referralUrl = 'https://moneko.io/referral';
    setState(() => _isLoading = true);

    try {
      if (!await launchUrl(
        Uri.parse(referralUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not open referral link');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to open referral page');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchDiscord() async {
    const discordUrl = 'https://discord.gg/M2Dgujvtze';
    try {
      await launchUrl(Uri.parse(discordUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _claimTrialAccess() async {
    if (widget.user.isEmpty) {
      AppToast.info(context, 'Please log in to continue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final response = await supabase.functions.invoke(
        'create-checkout-session',
        body: {
          'plan': 'plus',
          'billingInterval': 'monthly',
          'successUrl':
              'https://moneko.io/checkout/success?status=success&flow=trial&session_id={CHECKOUT_SESSION_ID}',
          'cancelUrl':
              'https://moneko.io/checkout/cancel?status=canceled&flow=trial',
        },
      );

      if (response.data != null && response.data['checkoutUrl'] != null) {
        final checkoutUrl = response.data['checkoutUrl'] as String;
        await launchUrl(Uri.parse(checkoutUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No checkout URL received');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to start trial: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Failed to logout');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Extract name logic
    final userName = widget.user.email.split('@').first;
    final displayName = (widget.user.displayName?.isNotEmpty ?? false)
        ? widget.user.displayName?.split(' ').first ?? userName
        : userName;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: colorScheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Hero Image with Glow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          'lib/assets/mascots/moneko.png',
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Title
                    Text(
                      widget.hasReferralCode
                          ? 'Welcome, $displayName!'
                          : 'Unlock Full Access',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      widget.hasReferralCode
                          ? 'You\'ve been invited to try Moneko Premium. Enjoy exclusive features and insights.'
                          : 'Join our referral program to unlock lifetime access and share the love with friends.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Feature Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildFeatureRow(context,
                              icon: Icons.star_rounded,
                              text: widget.hasReferralCode
                                  ? '1 Month Free Premium Access'
                                  : 'Lifetime Access for You & Friends'),
                          const SizedBox(height: 16),
                          _buildFeatureRow(context,
                              icon: Icons.check_circle_outline_rounded,
                              text: widget.hasReferralCode
                                  ? 'No credit card required'
                                  : 'Unlimited referrals'),
                          const SizedBox(height: 16),
                          _buildFeatureRow(context,
                              icon: Icons.flash_on_rounded,
                              text: 'Instant upgrade'),
                        ],
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 32),

                    // Primary Action
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: PrimaryAdaptiveButton(
                        onPressed: _isLoading
                            ? null
                            : (widget.hasReferralCode
                                ? _claimTrialAccess
                                : _launchReferralPage),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text(
                                widget.hasReferralCode
                                    ? 'Claim Free Month'
                                    : 'Join Referral Program',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Secondary Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PlainAdaptiveButton(
                          onPressed: _launchDiscord,
                          child: Text(
                            'Support',
                            style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          height: 4,
                          width: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.outline.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        PlainAdaptiveButton(
                          onPressed: _handleLogout,
                          child: Text(
                            'Log out',
                            style:
                                TextStyle(color: colorScheme.mutedForeground),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context,
      {required IconData icon, required String text}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: 15,
                ),
          ),
        ),
      ],
    );
  }
}
