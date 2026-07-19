import 'dart:async' show Timer;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/bank_sync/bank_provider_routing.dart';
import 'package:moneko/core/bank_sync/tink_link_service.dart';
import 'package:moneko/core/l10n/l10n.dart';
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
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_sync_result_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaidSyncWalkthroughPage extends ConsumerStatefulWidget {
  const PlaidSyncWalkthroughPage({
    super.key,
    this.targetHouseholdId,
    this.connectionId,
    this.flowReason,
  });

  final String? targetHouseholdId;
  final String? connectionId;
  final String? flowReason;

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
  Timer? _statusTimer;
  String? _loadingMessage;

  bool get _isReconnectFlow => widget.connectionId?.trim().isNotEmpty == true;

  bool get _isNewAccountsFlow => widget.flowReason == 'new_accounts_available';

  @override
  void dispose() {
    _stopExchangeStatusTimer();
    _pageController.dispose();
    super.dispose();
  }

  void _startExchangeStatusTimer() {
    _statusTimer?.cancel();
    int seconds = 0;
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_isConnecting) {
        timer.cancel();
        return;
      }
      seconds += 3;
      setState(() {
        if (seconds == 3) {
          _loadingMessage = context.l10n.plaidSyncRetrieving;
        } else if (seconds == 6) {
          _loadingMessage = context.l10n.plaidSyncSyncing;
        } else if (seconds == 9) {
          _loadingMessage = context.l10n.plaidSyncFinalizing;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _stopExchangeStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = null;
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

    final hasAccess = await PlusLockedSheet.ensureAccess(
      context,
      ref,
      feature: PlusFeature.bankSync,
    );
    if (!hasAccess || !mounted) return;

    final selectedCountryCode = ref.read(plaidCountryCodeProvider);
    final provider = getProviderForCountry(selectedCountryCode);

    // Handle coming soon countries
    if (provider == BankProvider.comingSoon) {
      AppToast.info(
          context, context.l10n.bankConnectionsInYourCountryComingSoon);
      return;
    }

    setState(() {
      _isConnecting = true;
      _loadingMessage = context.l10n.plaidSyncPreparing;
    });

    final client = Supabase.instance.client;

    try {
      if (provider == BankProvider.plaid) {
        await _performPlaidFlow(
          client: client,
          countryCode: selectedCountryCode,
          userId: user.uid,
        );
      } else if (provider == BankProvider.tink) {
        await _performTinkFlow(
          client: client,
          countryCode: selectedCountryCode,
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (_extractFunctionErrorCode(error) == 'duplicate_item_accounts') {
        await _handleDuplicateBankConnection();
        return;
      }
      setState(() => _isConnecting = false);
      AppToast.error(
        context,
        _extractFunctionError(
          error,
          fallback: context.l10n.couldNotConnectThisBankRightNow,
        ),
      );
    } finally {
      _stopExchangeStatusTimer();
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
            ? (_isNewAccountsFlow ? 'update' : 'reconnect')
            : 'new',
        'platform': Platform.isAndroid ? 'android' : 'ios',
        if ((connectionId == null || connectionId.isEmpty) &&
            countryCode.isNotEmpty)
          'countryCode': countryCode,
        if (connectionId != null && connectionId.isNotEmpty)
          'connectionId': connectionId,
        if (widget.flowReason != null) 'updateReason': widget.flowReason,
        if (connectionId == null || connectionId.isEmpty)
          'transactionsDaysRequested': _plaidInitialTransactionsDaysRequested,
        if (widget.targetHouseholdId != null)
          'targetHouseholdId': widget.targetHouseholdId,
      },
    );

    if (linkTokenResponse.status >= 400) {
      throw Exception(_extractFunctionError(
        linkTokenResponse.data,
        fallback: context.l10n.failedToCreateLinkToken,
      ));
    }

    final linkData = linkTokenResponse.data as Map<String, dynamic>?;
    final linkToken = linkData?['linkToken'] as String?;
    final modeUsed = (linkData?['modeUsed'] as String?)?.trim();
    final linkCompletionNonce =
        (linkData?['linkCompletionNonce'] as String?)?.trim();
    final updateCompletionNonce =
        (linkData?['updateCompletionNonce'] as String?)?.trim();
    if (linkToken == null || linkToken.isEmpty) {
      throw Exception(context.l10n.missingPlaidLinkToken);
    }

    final linkResult = await openPlaidLink(linkToken);
    if (linkResult == null) {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingMessage = context.l10n.plaidSyncConnecting;
    });
    _startExchangeStatusTimer();

    final isUpdateMode = connectionId != null && connectionId.isNotEmpty;
    final FunctionResponse exchangeResponse;
    if (isUpdateMode) {
      exchangeResponse = await client.functions.invoke(
        'plaid-item-control',
        body: {
          'action': 'update_mode_complete',
          'connectionId': connectionId,
          if (updateCompletionNonce != null && updateCompletionNonce.isNotEmpty)
            'updateCompletionNonce': updateCompletionNonce,
          if (widget.flowReason != null) 'reason': widget.flowReason,
          if (modeUsed != null && modeUsed.isNotEmpty) 'mode': modeUsed,
          if (linkResult.linkRequestId != null)
            'linkRequestId': linkResult.linkRequestId,
          if (linkResult.linkSessionId != null)
            'linkSessionId': linkResult.linkSessionId,
          if (linkResult.selectedAccounts.isNotEmpty)
            'selectedAccounts': linkResult.selectedAccounts
                .map((account) => account.toJson())
                .toList(growable: false),
          if (widget.targetHouseholdId != null)
            'targetHouseholdId': widget.targetHouseholdId,
          if (linkResult.institutionId != null)
            'institutionId': linkResult.institutionId,
          if (linkResult.institutionName != null)
            'institutionName': linkResult.institutionName,
        },
      );
    } else {
      final publicToken = linkResult.publicToken?.trim();
      if (publicToken == null || publicToken.isEmpty) {
        throw Exception(context.l10n.missingPlaidPublicToken);
      }

      exchangeResponse = await client.functions.invoke(
        'plaid-exchange-public-token',
        body: {
          'publicToken': publicToken,
          if (linkCompletionNonce != null && linkCompletionNonce.isNotEmpty)
            'linkCompletionNonce': linkCompletionNonce,
          'countryCode': countryCode,
          // Generate one idempotency key per user action attempt.
          'idempotencyKey': _plaidExchangeIdempotencyKey ??=
              generateIdempotencyKey(userId),
          if (linkResult.linkRequestId != null)
            'linkRequestId': linkResult.linkRequestId,
          if (linkResult.linkSessionId != null)
            'linkSessionId': linkResult.linkSessionId,
          if (linkResult.selectedAccounts.isNotEmpty)
            'selectedAccounts': linkResult.selectedAccounts
                .map((account) => account.toJson())
                .toList(growable: false),
          if (widget.targetHouseholdId != null)
            'targetHouseholdId': widget.targetHouseholdId,
          if (linkResult.institutionId != null)
            'institutionId': linkResult.institutionId,
          if (linkResult.institutionName != null)
            'institutionName': linkResult.institutionName,
        },
      );
    }

    if (exchangeResponse.status >= 400) {
      if (exchangeResponse.status == 409 && mounted) {
        final duplicateCode = _extractFunctionErrorCode(exchangeResponse.data);
        if (duplicateCode == 'duplicate_item_accounts') {
          await _handleDuplicateBankConnection();
          return;
        }
      }
      throw Exception(_extractFunctionError(
        exchangeResponse.data,
        fallback: context.l10n.failedToExchangeToken,
      ));
    }

    final exchangeData = exchangeResponse.data as Map<String, dynamic>?;
    if (exchangeData == null) {
      throw Exception(context.l10n.missingBankConnectionData);
    }

    final session = BankSyncReviewSession.fromResponse(
      data: exchangeData,
      flowReason: widget.flowReason,
      provider: 'plaid',
      targetHouseholdId: widget.targetHouseholdId,
      defaultAccountName: context.l10n.bankAccount,
    );
    if (!session.hasAccounts) {
      throw Exception(context.l10n.noSupportedBankAccountsReturned);
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
      throw Exception(context.l10n.failedToCreateTinkLink);
    }

    final linkData = linkTokenResponse.data as Map<String, dynamic>?;
    final linkUrl = linkData?['linkUrl'] as String?;
    if (linkUrl == null || linkUrl.isEmpty) {
      throw Exception(context.l10n.missingTinkLinkUrl);
    }

    ref.read(pendingBankLinkStateProvider.notifier).state =
        PendingBankLinkState(
      countryCode: countryCode,
      targetHouseholdId: widget.targetHouseholdId,
    );

    final opened = await openTinkLink(linkUrl);
    if (!opened) {
      ref.read(pendingBankLinkStateProvider.notifier).state = null;
      throw Exception(context.l10n.couldNotOpenTinkLink);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleDuplicateBankConnection() async {
    if (!mounted) return;
    setState(() => _isConnecting = false);
    await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.bankAlreadyConnected,
        description: context.l10n.duplicateBankConnectionDescription,
        confirmLabel: context.l10n.backToWallets,
        showCancelButton: false);
    ref.invalidate(bankConnectionsProvider);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedCode = ref.watch(plaidCountryCodeProvider);
    final provider = getProviderForCountry(selectedCode);
    final providerName = getProviderDisplayName(provider);
    final walkthroughSteps = _buildWalkthroughSteps();

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
                  children: walkthroughSteps,
                ),
              ),
              PlaidSyncWalkthroughFooter(
                connectLabel: _connectButtonLabel(),
                isLastPage: _currentPage == _numPages - 1,
                isConnecting: _isConnecting,
                loadingMessage: _loadingMessage,
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

  List<Widget> _buildWalkthroughSteps() {
    if (_isNewAccountsFlow) {
      return [
        PlaidSyncWalkthroughStep(
          icon: Icons.account_balance_wallet_rounded,
          title: context.l10n.reviewNewBankAccounts,
          description: context.l10n.reviewNewBankAccountsDescription,
        ),
        PlaidSyncWalkthroughStep(
          icon: Icons.playlist_add_check_circle_rounded,
          title: context.l10n.onlyTheAccountsYouPick,
          description: context.l10n.onlyTheAccountsYouPickDescription,
        ),
        PlaidSyncWalkthroughStep(
          icon: Icons.shield_rounded,
          title: context.l10n.secureReadOnly,
          description: context.l10n.secureReadOnlyExistingConnectionDescription,
        ),
        PlaidSyncCountrySelectionStep(
          isDisabled: _isConnecting,
        ),
      ];
    }

    if (_isReconnectFlow) {
      return [
        PlaidSyncWalkthroughStep(
          icon: Icons.sync_problem_rounded,
          title: context.l10n.repairYourBankConnection,
          description: context.l10n.repairYourBankConnectionDescription,
        ),
        PlaidSyncWalkthroughStep(
          icon: Icons.account_balance_rounded,
          title: context.l10n.keepYourExistingWallets,
          description: context.l10n.keepYourExistingWalletsDescription,
        ),
        PlaidSyncWalkthroughStep(
          icon: Icons.shield_rounded,
          title: context.l10n.consentSecurity,
          description: context.l10n.consentSecurityDescription,
        ),
        PlaidSyncCountrySelectionStep(
          isDisabled: _isConnecting,
        ),
      ];
    }

    return [
      PlaidSyncWalkthroughStep(
        icon: Icons.account_balance_wallet_rounded,
        title: context.l10n.effortlessTracking,
        description: context.l10n.effortlessTrackingDescription,
      ),
      PlaidSyncWalkthroughStep(
        icon: Icons.account_balance_rounded,
        title: context.l10n.walletsForEachAccount,
        description: context.l10n.walletsForEachAccountDescription,
      ),
      PlaidSyncWalkthroughStep(
        icon: Icons.shield_rounded,
        title: context.l10n.privateSecure,
        description: context.l10n.privateSecureDescription,
      ),
      PlaidSyncCountrySelectionStep(
        isDisabled: _isConnecting,
      ),
    ];
  }

  String _connectButtonLabel() {
    if (_isNewAccountsFlow) {
      return context.l10n.reviewAccounts;
    }
    if (_isReconnectFlow) {
      return context.l10n.reconnectBank;
    }
    return context.l10n.connectBank;
  }
}

String _extractFunctionError(
  dynamic payload, {
  required String fallback,
}) {
  final details = _functionErrorDetails(payload);
  if (details is Map<String, dynamic>) {
    final error = details['error']?.toString().trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }
  }
  if (payload is Map<String, dynamic>) {
    final error = payload['error']?.toString().trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }
  }

  return fallback;
}

String? _extractFunctionErrorCode(dynamic payload) {
  final details = _functionErrorDetails(payload);
  if (details is Map<String, dynamic>) {
    final errorCode = details['errorCode']?.toString().trim();
    if (errorCode != null && errorCode.isNotEmpty) {
      return errorCode;
    }
  }
  if (payload is Map<String, dynamic>) {
    final errorCode = payload['errorCode']?.toString().trim();
    if (errorCode != null && errorCode.isNotEmpty) {
      return errorCode;
    }
  }

  return null;
}

dynamic _functionErrorDetails(dynamic payload) {
  if (payload is FunctionException) {
    return payload.details;
  }
  return null;
}
