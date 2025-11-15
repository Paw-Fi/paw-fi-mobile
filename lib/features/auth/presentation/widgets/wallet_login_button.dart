import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/util/constants.dart';

/// Web3 Wallet Sign-In button using Supabase Auth (Wallet provider)
/// Requires Supabase project to have Wallet Auth enabled and redirect URI whitelisted.
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
    final isLoading = useState(false);
    final error = useState<String?>(null);

    Future<void> handleWalletLogin() async {
      error.value = null;
      isLoading.value = true;

      try {
        // Try Dart SDK Web3 API if available (2025+). Use dynamic to avoid
        // compile-time errors on older versions.
        final auth = supabase.auth as dynamic;
        final chain = await _pickChain(context);
        if (chain == null) {
          isLoading.value = false;
          return;
        }

        final result = await auth.signInWithWeb3(
          chain: chain,
          statement: 'I accept the Terms of Service at https://moneko.io/terms',
        );

        debugPrint('🔐 Web3 sign-in initiated: ${result != null ? "Success" : "Failed/Cancelled"}');

        // After Web3 sign-in, Supabase should set the current session.
        // Route through the centralized callback screen to keep behavior
        // consistent with OAuth providers.
        if (supabase.auth.currentSession != null && (context.mounted)) {
          final next = (redirectUrl ?? '/dashboard');
          final uri = Uri(path: '/auth/callback', queryParameters: {'next': next});
          context.go(uri.toString());
          return; // Avoid resetting loading state here; navigation will replace screen
        }

        // If we reach here, no session was established
        isLoading.value = false;
        if (context.mounted) {
          shadcnui.showToast(
            context: context,
            builder: (ctx, overlay) => shadcnui.Alert.destructive(
              leading: const shadcnui.Icon(Icons.error_outline),
              title: shadcnui.Text('Web3 sign-in failed or was canceled'),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Wallet OAuth error: $e');
        final msg = e.toString();
        if (msg.contains('NoSuchMethod') || msg.contains('signInWithWeb3')) {
          // Fallback: open a DApp browser (MetaMask/Phantom) to a hosted Web3 login page
          // that performs signInWithWeb3 with Supabase JS and deep-links back.
          final selected = await _pickChain(context);
          if (selected == null) {
            isLoading.value = false;
            return;
          }
          final supabaseUrl = Uri.encodeComponent(Constants.supabaseUrl);
          final anonKey = Uri.encodeComponent(Constants.supabaseAnon);
          final statement = Uri.encodeComponent('I accept the Terms of Service at https://moneko.io/terms');
          final redirect = Uri.encodeComponent(DeepLinks.oauthCallback);
          final baseDapp = 'https://moneko.io/web3-login.html?projectUrl=' + supabaseUrl +
              '&anonKey=' + anonKey + '&chain=' + Uri.encodeComponent(selected) + '&statement=' + statement + '&redirect=' + redirect;

          String walletLauncherUrl;
          if (selected.toLowerCase() == 'solana') {
            // Open in Phantom in-app browser
            walletLauncherUrl = 'https://phantom.app/ul/browse/' + Uri.encodeComponent(baseDapp);
          } else {
            // Default to Ethereum via MetaMask in-app browser
            walletLauncherUrl = 'https://metamask.app.link/dapp/' + Uri.encodeComponent(baseDapp);
          }

          final launched = await launchUrlString(walletLauncherUrl, mode: LaunchMode.externalApplication);
          if (!launched && context.mounted) {
            error.value = 'Web3 login requires a compatible wallet app (MetaMask/Phantom). Please install and try again.';
          } else {
            // Do not set error; user will complete flow in wallet and deep-link back.
          }
        } else {
          error.value = msg.replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
        }
        isLoading.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        shadcnui.OutlineButton(
          onPressed: (isLoading.value || disabled) ? null : handleWalletLogin,
          leading: const shadcnui.Icon(Icons.account_balance_wallet_outlined, size: 20),
          child: isLoading.value
              ? shadcnui.Text(context.l10n.signingInWithWallet)
              : shadcnui.Text(context.l10n.continueWithWallet),
        ),
        if (error.value != null) ...[
          const SizedBox(height: 12),
          shadcnui.Alert.destructive(
            leading: const shadcnui.Icon(Icons.error),
            title: shadcnui.Text(error.value!),
          ),
        ],
      ],
    );
  }

  Future<String?> _pickChain(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = shadcnui.Theme.of(ctx).colorScheme;
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
                  title: const Text('Ethereum (EVM)'),
                  subtitle: const Text('Use MetaMask, Rainbow, Brave, etc.'),
                  onTap: () => Navigator.pop(ctx, 'ethereum'),
                ),
                ListTile(
                  leading: const Icon(Icons.compass_calibration_outlined),
                  title: const Text('Solana'),
                  subtitle: const Text('Use Phantom, Solflare, Backpack, etc.'),
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
