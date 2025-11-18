import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
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
        
        // OAuth will redirect to browser, then back to app via deep link
        // No need to set loading to false - app will be backgrounded
      } catch (e) {
        debugPrint('❌ OAuth error: $e');
        error.value = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
        isLoading.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        shadcnui.OutlineButton(
          onPressed: (isLoading.value || disabled) ? null : handleGoogleLogin,
          leading: const shadcnui.Icon(Icons.g_mobiledata, size: 24),
          child: isLoading.value
              ? shadcnui.Text(context.l10n.signingInWithGoogle)
              : shadcnui.Text(context.l10n.continueWithGoogle),
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
}
