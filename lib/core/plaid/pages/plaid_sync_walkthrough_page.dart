import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/bank_sync/bank_provider_routing.dart';
import 'package:moneko/core/bank_sync/tink_link_service.dart';
import 'package:moneko/core/navigation/main_menu_screen.dart';
import 'package:moneko/core/plaid/models/bank_sync_review_session.dart';
import 'package:moneko/core/plaid/plaid_link_service.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_country_selection_step.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_review_page.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_walkthrough_footer.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_walkthrough_header.dart';
import 'package:moneko/core/plaid/widgets/plaid_sync_walkthrough_step.dart';
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
  String? _plaidExchangeIdempotencyKey;
  int _currentPage = 0;
  bool _isConnecting = false;
  final int _numPages = 4;

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
        'mode': (connectionId != null && connectionId.isNotEmpty)
            ? 'reconnect'
            : 'new',
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
        // Generate one idempotency key per user action attempt.
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
    final selectedCode = ref.watch(plaidCountryCodeProvider);
    final provider = getProviderForCountry(selectedCode);
    final providerName = getProviderDisplayName(provider);

    return PopScope(
      canPop: !_isConnecting,
      child: Scaffold(
        backgroundColor: colorScheme.appBackground,
        body: SafeArea(
          child: Column(
            children: [
              PlaidSyncWalkthroughHeader(
                currentPage: _currentPage,
                numPages: _numPages,
                isConnecting: _isConnecting,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: _isConnecting
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    const PlaidSyncWalkthroughStep(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Effortless\nTracking',
                      description:
                          'Connect your bank to automatically import transactions into wallets instead of entering everything by hand.',
                    ),
                    const PlaidSyncWalkthroughStep(
                      icon: Icons.account_balance_rounded,
                      title: 'Wallets For\nEach Account',
                      description:
                          'Each linked bank account gets its own wallet, so balances and transaction history stay organized in the right place.',
                    ),
                    const PlaidSyncWalkthroughStep(
                      icon: Icons.shield_rounded,
                      title: 'Private &\nSecure',
                      description:
                          'Your data is encrypted with bank-grade security. We never see your credentials, and access is read-only.',
                    ),
                    PlaidSyncCountrySelectionStep(
                      isDisabled: _isConnecting,
                    ),
                  ],
                ),
              ),
              PlaidSyncWalkthroughFooter(
                isLastPage: _currentPage == _numPages - 1,
                isConnecting: _isConnecting,
                providerName: providerName,
                onContinue: _nextPage,
                onConnect: _performConnection,
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
