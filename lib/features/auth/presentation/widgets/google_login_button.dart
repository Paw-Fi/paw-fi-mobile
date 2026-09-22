import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';

const _googleWebClientId =
    '1075784863194-p530784s5hi7nmd7b7mthipkshhjhe6h.apps.googleusercontent.com';

final _googleSignInInitialization = GoogleSignIn.instance.initialize(
  serverClientId: _googleWebClientId,
);

/// Google Sign-In button matching the web implementation.
/// Uses native Google authentication on mobile and Supabase OAuth on web.
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
        if (kIsWeb) {
          await supabase.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: DeepLinks.oauthCallback,
            authScreenLaunchMode: LaunchMode.externalApplication,
          );
        } else {
          await _googleSignInInitialization;
          final googleAccount = await GoogleSignIn.instance.authenticate();
          final googleAuthentication = googleAccount.authentication;
          final idToken = googleAuthentication.idToken;
          final googleAuthorization = await googleAccount.authorizationClient
              .authorizationForScopes(const <String>[]);

          if (idToken == null) {
            throw const AuthException('Google did not return an ID token.');
          }

          await supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: googleAuthorization?.accessToken,
          );
        }

        // The actual sign-in completion is handled via onAuthStateChange.
        isLoading.value = false;
      } catch (e) {
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
