import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/plaid/plaid_link_service.dart';
import 'package:moneko/core/navigation/main_menu_screen.dart'; // For plaidCountryCodeProvider
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

  final int _numPages = 3; // Intro, Security, Benefits

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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _WalkthroughStep(
                    icon: Icons.account_balance_rounded,
                    title: 'Connect Your Bank',
                    description:
                        'Link your bank account to automatically import your transactions and balances.',
                    colorScheme: colorScheme,
                  ),
                  _WalkthroughStep(
                    icon: Icons.lock_outline_rounded,
                    title: 'Secure & Private',
                    description:
                        'We use bank-grade encryption. We never see your credentials and only have read-only access to your data.',
                    colorScheme: colorScheme,
                  ),
                  _WalkthroughStep(
                    icon: Icons.auto_graph_rounded,
                    title: 'Stay Updated',
                    description:
                        'Keep your budget effortless. Your expenses and income will be categorized automatically.',
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _numPages,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _currentPage == _numPages - 1
                        ? FilledButton(
                            onPressed: _isSyncing ? null : _performSync,
                            style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            )),
                            child: _isSyncing
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : Text(
                                    'Sync Now',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          )
                        : FilledButton(
                            onPressed: _nextPage,
                            style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            )),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
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
  });

  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
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
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'All Set!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your bank account has been successfully connected. Your transactions are now syncing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onFinish,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Finish',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
