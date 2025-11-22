import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';

/// OAuth callback handler - matches web's /auth/callback route
/// Handles the redirect from Google OAuth flow
class AuthCallbackScreen extends HookConsumerWidget {
  final String? next;

  const AuthCallbackScreen({
    super.key,
    this.next,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isProcessing = useState(false);

    useEffect(() {
      // Prevent multiple executions
      if (isProcessing.value) return null;

      Future<void> handleAuthCallback() async {
        isProcessing.value = true;

        try {
          // Web: if tokens are present in fragment, set session proactively
          if (kIsWeb) {
            final frag = Uri.base.fragment;
            if (frag.contains('access_token') && frag.contains('refresh_token')) {
              final params = Uri.splitQueryString(frag);
              final refreshToken = params['refresh_token'];
              if (refreshToken != null && refreshToken.isNotEmpty) {
                try {
                  await supabase.auth.setSession(refreshToken);
                } catch (e) {
                  debugPrint('Failed to set session from callback: $e');
                }
              }
            }
          }
          // Check if we have a session - Supabase handles OAuth exchange automatically
          final session = supabase.auth.currentSession;

          if (session != null) {
            await _syncWeb3Profile(session);
            // OAuth authentication successful
            if (context.mounted) {
              // Check if this is a new user (created_at within last 5 minutes)
              final user = session.user;
              final createdAt = DateTime.parse(user.createdAt);
              final isNewUser = DateTime.now().difference(createdAt).inMinutes < 5;

              if (isNewUser) {
                // New user - redirect to avatar customizer
                context.go('/avatar');
              } else {
                // Existing user - go to specified redirect or dashboard
                context.go(next ?? '/dashboard');
              }
            }
          } else {
            // No immediate session - give Supabase time to process
            await Future.delayed(const Duration(milliseconds: 1000));

            final retrySession = supabase.auth.currentSession;

            if (retrySession != null) {
              if (context.mounted) {
                context.go(next ?? '/dashboard');
              }
            } else {
              // Session establishment failed
              if (context.mounted) {
                context.go('/login');
                AppToast.error(
                  context,
                  'Authentication session could not be established',
                );
              }
            }
          }
        } catch (error) {
          debugPrint('OAuth callback processing error: $error');
          if (context.mounted) {
            context.go('/login');
            AppToast.error(
              context,
              'An unexpected error occurred during authentication',
            );
          }
        }
      }

      // Process callback immediately
      handleAuthCallback();

      return null;
    }, []);

    return AdaptiveScaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Completing authentication...',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncWeb3Profile(Session session) async {
    try {
      final u = session.user as dynamic;
      String? walletAddress;
      String? chain;

      final identities = (u.identities as List?) ?? const [];
      for (final id in identities) {
        final idDyn = id as dynamic;
        final provider = (idDyn.provider ?? idDyn['provider'])?.toString();
        if (provider == 'web3' || provider == 'ethereum' || provider == 'solana') {
          final data = (idDyn.identityData ?? idDyn['identity_data']) as Map?;
          walletAddress = (data?['wallet_address'] ?? data?['address'] ?? data?['publicKey'])?.toString();
          chain = (data?['chain'] ?? data?['network'])?.toString();
          if (walletAddress != null) break;
        }
      }

      // If still unknown on web, try query string fragment extras (if our hosted page added them)
      if (walletAddress == null && kIsWeb) {
        final frag = Uri.base.fragment;
        final hasAddr = frag.contains('wallet_address=');
        if (hasAddr) {
          final params = Uri.splitQueryString(frag);
          walletAddress = params['wallet_address'];
          chain ??= params['chain'];
        }
      }

      if (walletAddress == null || walletAddress.isEmpty) return;

      final address = walletAddress;

      // Update auth metadata if no display name
      final meta = (u.userMetadata as Map?) ?? const {};
      final hasName = (meta['full_name']?.toString().trim().isNotEmpty == true) ||
          (meta['name']?.toString().trim().isNotEmpty == true);
      if (!hasName) {
        try {
          await supabase.auth.updateUser(UserAttributes(data: {
            'full_name': address,
            'name': address,
          }));
        } catch (_) {}
      }

      // Upsert into public.users (does not overwrite non-null values)
      try {
        await supabase.from('users').upsert({
          'id': session.user.id,
          'full_name': address,
          'wallet_address': address,
          if (chain != null) 'chain': chain,
        }, onConflict: 'id');
      } catch (e) {
        debugPrint('⚠️ users upsert failed: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Web3 profile sync skipped: $e');
    }
  }
}
