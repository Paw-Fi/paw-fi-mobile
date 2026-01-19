import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/constants/links.dart';
import '../providers/subscription_provider.dart';
import '../providers/referral_code_provider.dart';

enum PaywallMode {
  trial,
  resubscribe,
}

extension PaywallModeX on PaywallMode {
  static PaywallMode fromQuery(String? value) {
    return switch (value) {
      'resubscribe' => PaywallMode.resubscribe,
      _ => PaywallMode.trial,
    };
  }

  String get queryValue {
    return switch (this) {
      PaywallMode.trial => 'trial',
      PaywallMode.resubscribe => 'resubscribe',
    };
  }
}

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, this.mode = PaywallMode.trial});

  final PaywallMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: _PaywallContent(
        mode: mode,
        user: user,
      ),
    );
  }
}

class _PaywallContent extends ConsumerStatefulWidget {
  final PaywallMode mode;
  final AppUser user;

  const _PaywallContent({
    required this.mode,
    required this.user,
  });

  @override
  ConsumerState<_PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends ConsumerState<_PaywallContent> {
  bool _isLoading = false;

  Future<void> _handleRefresh() async {
    if (!mounted) return;

    final subscriptionNotifier =
        ref.read(subscriptionNotifierProvider.notifier);
    final referralNotifier = ref.read(referralCodeCheckerProvider.notifier);

    await subscriptionNotifier.refresh();
    await referralNotifier.refresh();

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
    try {
      await launchUrl(
        Uri.parse(Links.discordSupport),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _startCheckout({required String flow}) async {
    if (widget.user.isEmpty) {
      AppToast.info(context, 'Please log in to continue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      // IMPORTANT: Do not URI-encode the Stripe placeholder.
      final successBase = Uri.https('moneko.io', '/checkout', {
        'status': 'success',
        'source': 'mobile',
        'redirectUrl': DeepLinks.paymentCallback,
        'plan': 'plus',
        'billing': 'monthly',
        'flow': flow,
      }).toString();
      final cancelBase = Uri.https('moneko.io', '/checkout', {
        'status': 'canceled',
        'source': 'mobile',
        'redirectUrl': DeepLinks.paymentCallback,
        'plan': 'plus',
        'billing': 'monthly',
        'flow': flow,
      }).toString();

      final response = await supabase.functions.invoke(
        'create-checkout-session',
        body: {
          'plan': 'plus',
          'billingInterval': 'monthly',
          'successUrl': '$successBase&session_id={CHECKOUT_SESSION_ID}',
          'cancelUrl': '$cancelBase&session_id={CHECKOUT_SESSION_ID}',
        },
      );

      if (response.data != null && response.data['checkoutUrl'] != null) {
        final checkoutUrl = response.data['checkoutUrl'] as String;
        await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('No checkout URL received');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(e));
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
    final hasReferralCodeAsync = ref.watch(referralCodeCheckerProvider);

    // Extract name logic
    final userName = widget.user.email.split('@').first;
    final displayName = (widget.user.displayName?.isNotEmpty ?? false)
        ? widget.user.displayName?.split(' ').first ?? userName
        : userName;

    final isTrialEligible = widget.mode == PaywallMode.trial;

    return hasReferralCodeAsync.when(
      data: (hasReferralCode) {
        final primaryModeHasReferralCode = isTrialEligible && hasReferralCode;
        final showResubscribe = widget.mode == PaywallMode.resubscribe;

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
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
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.2),
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
                          showResubscribe
                              ? 'Your subscription has expired'
                              : (primaryModeHasReferralCode
                                  ? 'Welcome, $displayName!'
                                  : 'Unlock Full Access'),
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
                          showResubscribe
                              ? 'Resubscribe to continue enjoying premium features and insights.'
                              : (primaryModeHasReferralCode
                                  ? 'You\'ve been invited to try Moneko Premium. Enjoy exclusive features and insights.'
                                  : 'Join our referral program to unlock lifetime access and share the love with friends.'),
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
                            color: colorScheme.homeCardSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.homeCardBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.homeCardShadow,
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildFeatureRow(context,
                                  icon: Icons.star_rounded,
                                  text: showResubscribe
                                      ? 'Continue premium access'
                                      : (primaryModeHasReferralCode
                                          ? '1 Month Free Premium Access'
                                          : 'Lifetime Access for You & Friends')),
                              const SizedBox(height: 16),
                              _buildFeatureRow(context,
                                  icon: Icons.check_circle_outline_rounded,
                                  text: showResubscribe
                                      ? 'All premium features'
                                      : (primaryModeHasReferralCode
                                          ? 'No credit card required'
                                          : 'Unlimited referrals')),
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
                                : (showResubscribe
                                    ? () => _startCheckout(flow: 'resubscribe')
                                    : (primaryModeHasReferralCode
                                        ? () => _startCheckout(flow: 'trial')
                                        : _launchReferralPage)),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.primaryForeground,
                                    ),
                                  )
                                : Text(
                                    showResubscribe
                                        ? 'Resubscribe'
                                        : (primaryModeHasReferralCode
                                            ? 'Claim Free Month'
                                            : 'Join Referral Program'),
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
                                color:
                                    colorScheme.outline.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            PlainAdaptiveButton(
                              onPressed: _handleLogout,
                              child: Text(
                                'Log out',
                                style: TextStyle(
                                    color: colorScheme.mutedForeground),
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        // Fallback to trial mode if referral check fails
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: colorScheme.primary,
          child: const Center(
            child: Text('Unable to load subscription options'),
          ),
        );
      },
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
