import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

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
    final theme = shadcnui.Theme.of(context);
    final isProcessing = useState(false);

    useEffect(() {
      // Prevent multiple executions
      if (isProcessing.value) return null;

      Future<void> handleAuthCallback() async {
        isProcessing.value = true;

        try {
          // Check if we have a session - Supabase handles OAuth exchange automatically
          final session = supabase.auth.currentSession;

          if (session != null) {
            // OAuth authentication successful
            if (context.mounted) {
              // Check if this is a new user (created_at within last 5 minutes)
              final user = session.user;
              final createdAt = DateTime.parse(user.createdAt);
              final isNewUser = DateTime.now().difference(createdAt).inMinutes < 5;

              // If user signed in with Web3 and has no email/phone, proceed normally.
              // Linking can be handled elsewhere via profile settings if required.

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
                shadcnui.showToast(
                  context: context,
                  builder: (context, overlay) => const shadcnui.Alert.destructive(
                    leading: Icon(Icons.error),
                    title: Text('Authentication session could not be established'),
                  ),
                );
              }
            }
          }
        } catch (error) {
          debugPrint('OAuth callback processing error: $error');
          if (context.mounted) {
            context.go('/login');
            shadcnui.showToast(
              context: context,
              builder: (context, overlay) => const shadcnui.Alert.destructive(
                leading: Icon(Icons.error),
                title: Text('An unexpected error occurred during authentication'),
              ),
            );
          }
        }
      }

      // Process callback immediately
      handleAuthCallback();

      return null;
    }, []);

    return shadcnui.Scaffold(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const shadcnui.CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Completing authentication...',
              style: theme.typography.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
