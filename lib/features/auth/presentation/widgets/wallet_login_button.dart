import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/core/web/web3_auth.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
/// Web3 Wallet Sign-In button using Supabase Auth (Web3 provider)
/// 
/// IMPORTANT: This button ONLY works on Flutter Web
/// - Uses browser wallet extensions (MetaMask, Phantom, etc.)
/// - Connects via JS interop to window.ethereum / window.solana
/// - Calls Supabase JS SDK's signInWithWeb3() method
/// 
/// Requirements:
/// 1. Enable Web3 providers in Supabase Dashboard → Authentication → Providers
/// 2. Add redirect URLs in Supabase Dashboard → Authentication → URL Configuration
/// 3. Install browser wallet extension (MetaMask for Ethereum, Phantom for Solana)
/// 
/// The button is hidden on mobile platforms.
class WalletLoginButton extends HookConsumerWidget {
  final String? redirectUrl;
  final bool disabled;

  const WalletLoginButton({
    super.key,
    this.redirectUrl,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide button on mobile - Web3 auth only works on Flutter Web
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isLoading = useState(false);
    final error = useState<String?>(null);

    Future<void> handleWalletLogin() async {
      error.value = null;
      isLoading.value = true;

      try {
        // Step 1: Ask user to choose blockchain
        final chain = await _pickChain(context);
        if (chain == null) {
          isLoading.value = false;
          return; // User cancelled
        }

        debugPrint('🔐 [Web3] Starting authentication for $chain');

        // Step 2: Call web3SignIn from JS interop  
        final sessionData = await web3SignIn(
          chain: chain,
          statement: context.l10n.walletSignInStatement,
          projectUrl: Constants.supabaseUrl,
          anonKey: Constants.supabaseAnon,
        );

        if (sessionData == null) {
          throw Exception('No session data returned from Web3 sign-in');
        }

        final walletAddress = sessionData['wallet_address']?.toString();
        final chainFromJs = sessionData['chain']?.toString();

        debugPrint(
          '🔐 [Web3] Session tokens received. Wallet: $walletAddress, chain: $chainFromJs',
        );

        // Step 3: Set session in Supabase Flutter client
        await _setSupabaseSession(sessionData);

        debugPrint('🔐 [Web3] Session established in Flutter client');

        // Step 3b: Persist wallet address as display name + users.wallet_address
        if (walletAddress != null && walletAddress.isNotEmpty) {
          final session = supabase.auth.currentSession;
          final chain =
              chainFromJs ?? session?.user.userMetadata?['chain']?.toString();

          debugPrint(
            '🔐 [Web3] Persisting wallet to profile. Wallet: $walletAddress, chain: $chain',
          );

          try {
            await supabase.auth.updateUser(
              UserAttributes(
                data: {
                  'full_name': walletAddress,
                  'name': walletAddress,
                  'wallet_address': walletAddress,
                  if (chain != null) 'chain': chain,
                },
              ),
            );
          } catch (e) {
            debugPrint('⚠️ [Web3] Failed to update auth metadata: $e');
          }

          try {
            if (session != null) {
              await supabase.from('users').upsert(
                {
                  'id': session.user.id,
                  'full_name': walletAddress,
                  'wallet_address': walletAddress,
                  if (chain != null) 'chain': chain,
                },
                onConflict: 'id',
              );
            }
          } catch (e) {
            debugPrint('⚠️ [Web3] Failed to upsert users row: $e');
          }
        }

        // Step 4: Navigate to callback screen (consistent with OAuth flow)
        if (context.mounted) {
          final next = redirectUrl ?? '/dashboard';
          final uri = Uri(path: '/auth/callback', queryParameters: {'next': next});
          context.go(uri.toString());
        }
      } catch (e) {
        debugPrint('❌ [Web3] Authentication error: $e');
        
        if (!context.mounted) return;
        
        // Normalize error message for display
        final errorMsg = _normalizeErrorMessage(e.toString());
        error.value = errorMsg;
        isLoading.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: AdaptiveButton.child(
            onPressed: (isLoading.value || disabled) ? null : handleWalletLogin,
            style: AdaptiveButtonStyle.bordered,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  isLoading.value
                      ? context.l10n.signingInWithWallet
                      : context.l10n.continueWithWallet,
                ),
              ],
            ),
          ),
        ),
        if (error.value != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.destructive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.destructive.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.destructive,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    error.value!,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.destructive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _setSupabaseSession(Map<String, dynamic> sessionData) async {
    final refreshToken = sessionData['refresh_token']?.toString();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('Missing refresh token in Web3 session data');
    }

    try {
      await supabase.auth.setSession(refreshToken);
    } catch (e) {
      throw Exception('Failed to set session in Supabase client: $e');
    }
    
    // Verify session was set
    if (supabase.auth.currentSession == null) {
      throw Exception('Session not established after setSession call');
    }
  }

  /// Normalize error messages for better UX
  String _normalizeErrorMessage(String error) {
    // Remove technical prefixes
    String normalized = error
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '')
        .replaceAll('AuthException: ', '')
        .replaceAll('AuthApiError: ', '');

    final lowerError = normalized.toLowerCase();

    // Map common errors to user-friendly messages
    if (lowerError.contains('supabase js') && lowerError.contains('not available')) {
      return 'Configuration error: Supabase JS SDK not loaded. Please refresh the page and try again.';
    }

    if (lowerError.contains('no ethereum wallet') ||
        lowerError.contains('ethereum wallet detected')) {
      return 'No Ethereum wallet detected. Please install MetaMask, Rainbow, or another Ethereum wallet extension.';
    }

    if (lowerError.contains('no solana wallet') ||
        lowerError.contains('solana wallet detected')) {
      return 'No Solana wallet detected. Please install Phantom, Solflare, or another Solana wallet extension.';
    }

    if (lowerError.contains('rejected') ||
        lowerError.contains('denied') ||
        lowerError.contains('cancelled') ||
        lowerError.contains('canceled')) {
      return 'You cancelled the wallet connection or signature. Please try again when ready.';
    }

    if (lowerError.contains('web3 provider') && lowerError.contains('disabled')) {
      return 'Web3 authentication is disabled. Please contact support or enable Web3 providers (Ethereum/Solana) in Supabase Dashboard.';
    }

    if (lowerError.contains('signinwithweb3') || lowerError.contains('not found')) {
      return 'Web3 authentication method not available. Please ensure you\'re using the latest Supabase version.';
    }

    if (lowerError.contains('network') || lowerError.contains('chain')) {
      return 'Network error. Please check your wallet is connected to the correct network and try again.';
    }

    if (lowerError.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (lowerError.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }

    // Return cleaned error if no specific match
    return normalized.length > 200
        ? '${normalized.substring(0, 200)}...'
        : normalized;
  }

  Future<String?> _pickChain(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: scheme.border.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.token_outlined),
                  title: Text(context.l10n.ethereumEvm),
                  subtitle: Text(context.l10n.useMetaMaskRainbowBraveEtc),
                  onTap: () => Navigator.pop(ctx, 'ethereum'),
                ),
                ListTile(
                  leading: const Icon(Icons.compass_calibration_outlined),
                  title: Text(context.l10n.solana),
                  subtitle: Text(context.l10n.usePhantomSolflareBackpackEtc),
                  onTap: () => Navigator.pop(ctx, 'solana'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(ctx.l10n.cancel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
