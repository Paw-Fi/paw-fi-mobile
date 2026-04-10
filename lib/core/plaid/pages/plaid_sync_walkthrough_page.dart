import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/bank_sync/bank_provider_routing.dart';
import 'package:moneko/core/bank_sync/tink_link_service.dart';
import 'package:moneko/core/navigation/main_menu_screen.dart';
import 'package:moneko/core/plaid/models/bank_sync_review_session.dart';
import 'package:moneko/core/plaid/plaid_countries.dart';
import 'package:moneko/core/plaid/plaid_country_flags.dart';
import 'package:moneko/core/plaid/plaid_country_selector_modal.dart';
import 'package:moneko/core/plaid/plaid_link_service.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_review_page.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/bank_sync_result_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaidSyncWalkthroughPage extends ConsumerStatefulWidget {
  const PlaidSyncWalkthroughPage({
    super.key,
    this.targetHouseholdId,
    this.connectionId,
  });

  final String? targetHouseholdId;
  final String? connectionId;

  @override
  ConsumerState<PlaidSyncWalkthroughPage> createState() =>
      _PlaidSyncWalkthroughPageState();
}

class _PlaidSyncWalkthroughPageState
    extends ConsumerState<PlaidSyncWalkthroughPage> {
  static const int _plaidInitialTransactionsDaysRequested = 730;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isConnecting = false;
  final int _numPages = 4;
  String? _plaidExchangeIdempotencyKey;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage >= _numPages - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _performConnection() async {
    if (_isConnecting) return;

    final user = ref.read(authProvider);
    if (user.uid.isEmpty) {
      return;
    }

    setState(() => _isConnecting = true);

    final selectedCountryCode = ref.read(plaidCountryCodeProvider);
    final provider = getProviderForCountry(selectedCountryCode);
    final client = Supabase.instance.client;

    try {
      if (provider == BankProvider.plaid) {
        await _performPlaidFlow(
          client: client,
          countryCode: selectedCountryCode,
          userId: user.uid,
        );
      } else {
        await _performTinkFlow(
          client: client,
          countryCode: selectedCountryCode,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isConnecting = false);
      AppToast.error(context, error.toString());
    }
  }

  Future<void> _performPlaidFlow({
    required SupabaseClient client,
    required String countryCode,
    required String userId,
  }) async {
    final connectionId = widget.connectionId?.trim();
    final linkTokenResponse = await client.functions.invoke(
      'plaid-create-link-token',
      body: {
        'platform': Platform.isAndroid ? 'android' : 'ios',
        if ((connectionId == null || connectionId.isEmpty) &&
            countryCode.isNotEmpty)
          'countryCode': countryCode,
        if (connectionId != null && connectionId.isNotEmpty)
          'connectionId': connectionId,
        if (connectionId == null || connectionId.isEmpty)
          'transactionsDaysRequested': _plaidInitialTransactionsDaysRequested,
      },
    );

    if (linkTokenResponse.status >= 400) {
      throw Exception(_extractFunctionError(
        linkTokenResponse.data,
        fallback: 'Failed to create link token',
      ));
    }

    final linkData = linkTokenResponse.data as Map<String, dynamic>?;
    final linkToken = linkData?['linkToken'] as String?;
    if (linkToken == null || linkToken.isEmpty) {
      throw Exception('Missing Plaid link token');
    }

    final linkResult = await openPlaidLink(linkToken);
    if (linkResult == null) {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
      return;
    }

    final exchangeResponse = await client.functions.invoke(
      'plaid-exchange-public-token',
      body: {
        'publicToken': linkResult.publicToken,
        if (connectionId == null || connectionId.isEmpty)
          'countryCode': countryCode,
        'idempotencyKey': _plaidExchangeIdempotencyKey ??=
            generateIdempotencyKey(userId),
        if (widget.targetHouseholdId != null)
          'targetHouseholdId': widget.targetHouseholdId,
        if (linkResult.institutionId != null)
          'institutionId': linkResult.institutionId,
        if (linkResult.institutionName != null)
          'institutionName': linkResult.institutionName,
      },
    );

    if (exchangeResponse.status >= 400) {
      throw Exception(_extractFunctionError(
        exchangeResponse.data,
        fallback: 'Failed to exchange token',
      ));
    }

    final exchangeData = exchangeResponse.data as Map<String, dynamic>?;
    if (exchangeData == null) {
      throw Exception('Missing bank connection data');
    }

    final session = BankSyncReviewSession.fromResponse(
      data: exchangeData,
      provider: 'plaid',
      targetHouseholdId: widget.targetHouseholdId,
    );
    if (!session.hasAccounts) {
      throw Exception('No supported bank accounts were returned');
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlaidSyncReviewPage(session: session),
      ),
    );
  }

  Future<void> _performTinkFlow({
    required SupabaseClient client,
    required String countryCode,
  }) async {
    final linkTokenResponse = await client.functions.invoke(
      'tink-create-link-token',
      body: {
        'countryCode': countryCode,
        'intent': 'add',
        if (widget.targetHouseholdId != null)
          'targetHouseholdId': widget.targetHouseholdId,
      },
    );

    if (linkTokenResponse.status >= 400) {
      throw Exception('Failed to create Tink link');
    }

    final linkData = linkTokenResponse.data as Map<String, dynamic>?;
    final linkUrl = linkData?['linkUrl'] as String?;
    if (linkUrl == null || linkUrl.isEmpty) {
      throw Exception('Missing Tink link URL');
    }

    ref.read(pendingBankLinkStateProvider.notifier).state =
        PendingBankLinkState(
      countryCode: countryCode,
      targetHouseholdId: widget.targetHouseholdId,
    );

    final opened = await openTinkLink(linkUrl);
    if (!opened) {
      ref.read(pendingBankLinkStateProvider.notifier).state = null;
      throw Exception('Could not open Tink Link');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_isConnecting,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    IconButton(
                      onPressed: _isConnecting
                          ? null
                          : () => Navigator.of(context).pop(),
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
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _WalkthroughStep(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Effortless\nTracking',
                      description:
                          'Connect your bank to automatically import transactions into wallets instead of entering everything by hand.',
                      colorScheme: colorScheme,
                      isFirst: true,
                    ),
                    _WalkthroughStep(
                      icon: Icons.account_balance_rounded,
                      title: 'Wallets For\nEach Account',
                      description:
                          'Each linked bank account gets its own wallet, so balances and transaction history stay organized in the right place.',
                      colorScheme: colorScheme,
                    ),
                    _WalkthroughStep(
                      icon: Icons.shield_rounded,
                      title: 'Private &\nSecure',
                      description:
                          'Your data is encrypted with bank-grade security. We never see your credentials, and access is read-only.',
                      colorScheme: colorScheme,
                    ),
                    _CountrySelectionStep(colorScheme: colorScheme),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isConnecting)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Preparing your bank connection...',
                                style: TextStyle(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: _currentPage == _numPages - 1
                          ? FilledButton(
                              onPressed:
                                  _isConnecting ? null : _performConnection,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 0,
                                shadowColor:
                                    colorScheme.shadow.withValues(alpha: 0.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isConnecting
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text(
                                      'Connect Bank',
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
                                shadowColor:
                                    colorScheme.shadow.withValues(alpha: 0.0),
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
                    if (_currentPage == _numPages - 1)
                      Consumer(
                        builder: (context, ref, _) {
                          final selectedCode =
                              ref.watch(plaidCountryCodeProvider);
                          final provider = getProviderForCountry(selectedCode);
                          final providerName = getProviderDisplayName(provider);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 12,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Secured by $providerName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.outline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    else
                      const SizedBox(height: 16),
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

String _extractFunctionError(
  dynamic payload, {
  required String fallback,
}) {
  if (payload is Map<String, dynamic>) {
    final error = payload['error']?.toString().trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }
  }

  return fallback;
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
                          color: colorScheme.shadow.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        flagPath,
                        fit: BoxFit.cover,
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
