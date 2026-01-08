import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
/// Google Sign-In button matching web implementation
/// Uses Supabase OAuth with Google provider
class GoogleLoginButton extends HookConsumerWidget {
  final String? redirectUrl;
  final bool disabled;

  const GoogleLoginButton({
    super.key,
    this.redirectUrl,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = useState(false);
    final error = useState<String?>(null);

    Future<void> handleGoogleLogin() async {
      error.value = null;
      isLoading.value = true;

      try {
        debugPrint('🔐 Starting Google OAuth flow...');
        debugPrint('🔐 Redirect URL: ${DeepLinks.oauthCallback}');
        
        // Use Supabase's recommended mobile deep link pattern
        // Important: Don't add query parameters to redirectTo - handle them in the callback screen
        final result = await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: DeepLinks.oauthCallback,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );

        debugPrint('🔐 OAuth initiated: ${result ? "Success" : "Failed"}');
        
        // Store the intended redirect location for after auth completes
        // The DeepLinkService will handle navigation to this route
        if (redirectUrl != null) {
          debugPrint('🔐 Will redirect to: $redirectUrl after auth');
        }

        // signInWithOAuth only initiates the browser flow; it does not
        // guarantee that the user completed auth. Reset loading state so
        // that if the user cancels and returns, the button is interactive
        // again. The actual sign-in completion is still handled via
        // onAuthStateChange elsewhere.
        isLoading.value = false;
      } catch (e) {
        debugPrint('❌ OAuth error: $e');
        error.value = formatAuthErrorMessage(e);
        isLoading.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryAdaptiveButton(
          onPressed: (isLoading.value || disabled) ? null : handleGoogleLogin,
          prefixIcon: isLoading.value
              ? null
              : Icon(
                  Icons.g_mobiledata,
                  size: 26,
                  color: theme.colorScheme.primaryForeground,
                ),
          child: Text(
            isLoading.value
                ? context.l10n.signingInWithGoogle
                : context.l10n.continueWithGoogle,
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
}
