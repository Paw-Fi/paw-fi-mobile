import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rsupa/core/core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';

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
        // Use built-in Supabase OAuth - following web implementation exactly
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'moneko://auth/callback?next=${Uri.encodeComponent(redirectUrl ?? '/dashboard')}',
          authScreenLaunchMode: LaunchMode.externalApplication,
        );

        // OAuth will redirect to browser, then back to app via deep link
        // No need to set loading to false - app will be backgrounded
      } catch (e) {
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
              ? const shadcnui.Text('Signing in with Google...')
              : const shadcnui.Text('Continue with Google'),
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
