import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class AppleLoginButton extends HookConsumerWidget {
  final String? redirectUrl;
  final bool disabled;

  const AppleLoginButton({
    super.key,
    this.redirectUrl,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = useState(false);
    final error = useState<String?>(null);
    final isAvailable = useState(true);

    useEffect(() {
      if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
        isAvailable.value = true;
        return null;
      }
      var isActive = true;

      Future<void>(() async {
        try {
          final available = await SignInWithApple.isAvailable();
          if (isActive) {
            isAvailable.value = available;
          }
        } catch (_) {
          if (isActive) {
            isAvailable.value = false;
          }
        }
      });

      return () {
        isActive = false;
      };
    }, const []);

    if (!isAvailable.value) {
      return const SizedBox.shrink();
    }

    Future<void> handleAppleLogin() async {
      error.value = null;
      isLoading.value = true;

      try {
        if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
          final result = await supabase.auth.signInWithOAuth(
            OAuthProvider.apple,
            redirectTo: kIsWeb ? null : DeepLinks.oauthCallback,
            authScreenLaunchMode: kIsWeb
                ? LaunchMode.platformDefault
                : LaunchMode.externalApplication,
          );

          debugPrint(
              '🔐 Apple OAuth initiated: ${result ? "Success" : "Failed"}');
          isLoading.value = false;
          return;
        }

        final rawNonce = supabase.auth.generateRawNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );

        final idToken = credential.identityToken;
        if (idToken == null) {
          throw const AuthException(
              'Could not find ID Token from generated credential.');
        }

        final response = await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        );

        if (credential.givenName != null || credential.familyName != null) {
          final nameParts = <String>[];
          if (credential.givenName != null) {
            nameParts.add(credential.givenName!);
          }
          if (credential.familyName != null) {
            nameParts.add(credential.familyName!);
          }
          final fullName = nameParts.join(' ').trim();
          if (fullName.isNotEmpty) {
            await supabase.auth.updateUser(
              UserAttributes(
                data: {
                  'full_name': fullName,
                  'given_name': credential.givenName,
                  'family_name': credential.familyName,
                },
              ),
            );
          }
        }

        if (!context.mounted) return;

        if (response.session != null) {
          final next = redirectUrl ?? '/dashboard';
          context.go(next);
        }
      } catch (e) {
        debugPrint('❌ Apple sign-in error: $e');
        if (!context.mounted) return;
        error.value = formatAuthErrorMessage(e);
      } finally {
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryAdaptiveButton(
          onPressed: (isLoading.value || disabled) ? null : handleAppleLogin,
          prefixIcon: isLoading.value
              ? null
              : Icon(
                  Icons.apple,
                  size: 20,
                  color: theme.colorScheme.primaryForeground,
                ),
          child: Text(
            isLoading.value
                  ? context.l10n.signInWithAppleLoading
                  : context.l10n.signInWithAppleCta,
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
