import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/plaid/plaid_link_service.dart';
import 'package:moneko/core/navigation/main_menu_screen.dart'; // For plaidCountryCodeProvider
import 'package:moneko/core/plaid/plaid_countries.dart';
import 'package:moneko/core/plaid/plaid_country_flags.dart';
import 'package:moneko/core/plaid/plaid_country_selector_modal.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaidSyncWalkthroughPage extends ConsumerStatefulWidget {
  const PlaidSyncWalkthroughPage({super.key});

  @override
  ConsumerState<PlaidSyncWalkthroughPage> createState() =>
      _PlaidSyncWalkthroughPageState();
}

class _PlaidSyncWalkthroughPageState
    extends ConsumerState<PlaidSyncWalkthroughPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSyncing = false;
  bool _isSuccess = false;

  final int _numPages = 4; // Intro, Security, Benefits, Country selection

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
    });

    final user = ref.read(authProvider);
    if (user.uid.isEmpty) {
      setState(() => _isSyncing = false);
      return;
    }
    final selectedCountryCode = ref.read(plaidCountryCodeProvider);

    // We don't use the blocking dialog here because we have a UI for it,
    // but for consistency with the original code, or to show progress clearly:
    // showBlockingProcessingDialog(context: context, message: context.l10n.autoSync);
    // However, standard blocking dialogs on top of a nice walkthrough might be jarring.
    // Let's try to keep it inline or use the blocking dialog if strictly necessary for the flow.
    // The user request says "once connected, the walkthrough proceed to last step with finish".

    final client = Supabase.instance.client;

    try {
      final linkTokenResponse = await client.functions.invoke(
        'plaid-create-link-token',
        body: {
          'platform': Platform.isAndroid ? 'android' : 'ios',
          if (selectedCountryCode.isNotEmpty)
            'countryCode': selectedCountryCode,
        },
      );

      if (linkTokenResponse.status >= 400) {
        throw Exception('Failed to create link token');
      }

      final linkData = linkTokenResponse.data as Map<String, dynamic>?;
      final linkToken = linkData?['linkToken'] as String?;
      if (linkToken == null || linkToken.isEmpty) {
        throw Exception('Missing Plaid link token');
      }

      final linkResult = await openPlaidLink(linkToken);
      if (linkResult == null) {
        // User cancelled Plaid Link
        setState(() => _isSyncing = false);
        return;
      }

      final exchangeResponse = await client.functions.invoke(
        'plaid-exchange-public-token',
        body: {
          'publicToken': linkResult.publicToken,
          if (linkResult.institutionId != null)
            'institutionId': linkResult.institutionId,
          if (linkResult.institutionName != null)
            'institutionName': linkResult.institutionName,
        },
      );

      if (exchangeResponse.status >= 400) {
        throw Exception('Failed to exchange token');
      }

      final syncResponse = await client.functions.invoke(
        'plaid-sync-transactions',
      );

      if (syncResponse.status >= 400) {
        throw Exception('Failed to sync transactions');
      }

      // Refresh providers
      ref.invalidate(analyticsProvider);
      ref.invalidate(userHouseholdsProvider);
      ref.invalidate(householdExpensesProvider);
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);
      ref.invalidate(householdSummaryProvider);
      ref.invalidate(householdMembersProvider);
      ref.invalidate(selectedHouseholdProvider);
      ref.invalidate(viewModeProvider);
      ref.invalidate(homeFilterProvider);
      ref.invalidate(incomeSummaryProvider);
      ref.invalidate(incomeListProvider);
      ref.invalidate(goalsListProvider);
      ref.invalidate(goalSummaryProvider);
      ref.invalidate(subscriptionManagementProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(pocketsProvider);
      ref.invalidate(recurringTransactionsProvider);
      ref.invalidate(recurringTransactionSaveProvider);
      ref.invalidate(selectedRecurringTabProvider);

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isSyncing = false;
        });
        // Animate to success page (which effectively is a 4th page overlay or replacement)
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          '${context.l10n.failedToSyncCurrencyPreference}: ${e.toString()}',
        );
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isSuccess) {
      return _SuccessPage(onFinish: () => Navigator.of(context).pop());
    }

    return WillPopScope(
      onWillPop: () async {
        return !_isSyncing;
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              // Custom Minimal Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page Indicator (Apple style: subtle dots or progress)
                    Row(
                      children: List.generate(
                        _numPages,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 6,
                          width: _currentPage == index ? 24 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    // Close Button
                    IconButton(
                      onPressed:
                          _isSyncing ? null : () => Navigator.of(context).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _WalkthroughStep(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Effortless\nTracking',
                      description:
                          'Connect your bank to automatically import transactions and balances. Say goodbye to manual entry.',
                      colorScheme: colorScheme,
                      isFirst: true,
                    ),
                    _WalkthroughStep(
                      icon: Icons.shield_rounded,
                      title: 'Private &\nSecure',
                      description:
                          'Your data is encrypted with bank-grade security. We never see your credentials, and access is read-only.',
                      colorScheme: colorScheme,
                    ),
                    _WalkthroughStep(
                      icon: Icons.insights_rounded,
                      title: 'Real-time\nInsights',
                      description:
                          'Get instant notifications on spending, spot trends, and stay on top of your budget as it happens.',
                      colorScheme: colorScheme,
                    ),
                    _CountrySelectionStep(colorScheme: colorScheme),
                  ],
                ),
              ),

              // Bottom Action Area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: _currentPage == _numPages - 1
                          ? FilledButton(
                              onPressed: _isSyncing ? null : _performSync,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isSyncing
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text(
                                      'Sync Now',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                            )
                          : FilledButton(
                              onPressed: _nextPage,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // "Powered by Plaid" or similar trust signal could go here
                    if (_currentPage == _numPages - 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 12, color: colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            'Secured by Plaid',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(
                          height:
                              16), // Spacer to keep button position consistent-ish
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkthroughStep extends StatelessWidget {
  const _WalkthroughStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
    this.isFirst = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container with subtle glow/shadow
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 10,
                ),
              ],
              border: Border.all(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.5,
              color: colorScheme.mutedForeground,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountrySelectionStep extends ConsumerWidget {
  const _CountrySelectionStep({
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCode = ref.watch(plaidCountryCodeProvider);
    final selectedOption =
        plaidCountryOptions.firstWhere((o) => o.code == selectedCode);
    final flagPath = getPlaidCountryFlagPath(selectedCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.public_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Select Region',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose your banking region to see available institutions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.5,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 40),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              final result = await showPlaidCountrySelectorModal(context, ref);
              if (result != null) {
                ref.read(plaidCountryCodeProvider.notifier).state = result;
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(0),
                        child: Image.asset(
                          flagPath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Country',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.mutedForeground,
                            textBaseline: TextBaseline.alphabetic,
                          ),
                        ),
                        Text(
                          selectedOption.label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.foreground,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPage extends StatelessWidget {
  const _SuccessPage({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 64,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Connected!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your bank account has been successfully linked. We are now syncing your transaction history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: onFinish,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
