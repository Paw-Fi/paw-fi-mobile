import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/auth/presentation/widgets/wallet_login_button.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final showPassword = useState(false);
    final error = useState<String?>(null);
    final isLoading = useState(false);
    final emailFocusNode = useFocusNode();
    final passwordFocusNode = useFocusNode();
    final emailHasFocus = useState(false);
    final passwordHasFocus = useState(false);
    final errorShake = useState(false);

    // Focus listeners for micro-interactions
    useEffect(() {
      void emailListener() => emailHasFocus.value = emailFocusNode.hasFocus;
      void passwordListener() => passwordHasFocus.value = passwordFocusNode.hasFocus;

      emailFocusNode.addListener(emailListener);
      passwordFocusNode.addListener(passwordListener);

      return () {
        emailFocusNode.removeListener(emailListener);
        passwordFocusNode.removeListener(passwordListener);
      };
    }, [emailFocusNode, passwordFocusNode]);

    // Error shake animation
    useEffect(() {
      if (errorShake.value) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            errorShake.value = false;
          }
        });
      }
      return null;
    }, [errorShake.value]);

    Future<void> handleSignIn() async {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (email.isEmpty || !email.contains('@')) {
        error.value = context.l10n.enterValidEmail;
        errorShake.value = true;
        return;
      }

      if (password.isEmpty || password.length < 6) {
        error.value = context.l10n.passwordMinLength(6);
        errorShake.value = true;
        return;
      }

      error.value = null;
      isLoading.value = true;

      try {
        await ref.read(authProvider.notifier).signIn(email, password);

        // After successful authentication, ensure device is registered for push notifications
        try {
          await ref.read(deviceRegistrationServiceProvider).initialize();
        } catch (_) {}

        if (context.mounted) {
          context.go('/dashboard');
        }
      } catch (e) {
        if (!context.mounted) return; // Widget may have been disposed after navigation
        error.value = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
        errorShake.value = true;
      } finally {
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    Future<void> handleResetPassword() async {
      final email = await showDialog<String>(
        context: context,
        builder: (context) => _ResetPasswordDialog(),
      );

      if (email == null || email.isEmpty) return;

      try {
        await ref.read(authProvider.notifier).resetPassword(email);
        AppToast.success(context, context.l10n.passwordResetEmailSent);
      } catch (e) {
        AppToast.error(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.appBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modern Logo with subtle animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          context.l10n.appTitle,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.5,
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.loginWelcomeBack,
                          style: TextStyle(
                            color: theme.colorScheme.mutedForeground,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Modern elevated card with soft shadows
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.card,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.foreground.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: theme.colorScheme.foreground.withValues(alpha: 0.03),
                          blurRadius: 40,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // OAuth Sign In
                          GoogleLoginButton(
                            redirectUrl: '/dashboard',
                            disabled: isLoading.value,
                          ),
                          const SizedBox(height: 12),
                          WalletLoginButton(
                            redirectUrl: '/dashboard',
                            disabled: isLoading.value,
                          ),
                          const SizedBox(height: 24),

                          // Modern Divider
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        theme.colorScheme.border.withValues(alpha: 0.5),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  context.l10n.orContinueWithEmail,
                                  style: TextStyle(
                                    color: theme.colorScheme.mutedForeground,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.border.withValues(alpha: 0.5),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Email Field with focus animation
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: emailHasFocus.value
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.border,
                                width: emailHasFocus.value ? 2 : 1,
                              ),
                            ),
                            child: TextField(
                              controller: emailController,
                              focusNode: emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading.value,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.foreground,
                              ),
                              decoration: InputDecoration(
                                hintText: context.l10n.emailAddress,
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.mutedForeground.withValues(alpha: 0.6),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Field with focus animation
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: passwordHasFocus.value
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.border,
                                width: passwordHasFocus.value ? 2 : 1,
                              ),
                            ),
                            child: TextField(
                              controller: passwordController,
                              focusNode: passwordFocusNode,
                              obscureText: !showPassword.value,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => handleSignIn(),
                              enabled: !isLoading.value,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.foreground,
                              ),
                              decoration: InputDecoration(
                                hintText: context.l10n.password,
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.mutedForeground.withValues(alpha: 0.6),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => showPassword.value = !showPassword.value,
                                  icon: Icon(
                                    showPassword.value
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: theme.colorScheme.mutedForeground,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: isLoading.value ? null : handleResetPassword,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                child: Text(
                                  context.l10n.forgotPassword,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Error Message with shake animation
                          if (error.value != null)
                            TweenAnimationBuilder<double>(
                              key: ValueKey(errorShake.value),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                final shake = errorShake.value ? (1 - value) * 10 : 0.0;
                                return Transform.translate(
                                  offset: Offset(shake * (value % 2 == 0 ? 1 : -1), 0),
                                  child: child,
                                );
                              },
                              child: Container(
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
                                          color: theme.colorScheme.destructive,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (error.value != null) const SizedBox(height: 20),

                          // Sign In Button with press animation
                          AnimatedScale(
                            scale: isLoading.value ? 0.98 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withValues(alpha: 0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isLoading.value ? null : handleSignIn,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Center(
                                    child: isLoading.value
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                theme.colorScheme.primaryForeground,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            context.l10n.signIn,
                                            style: TextStyle(
                                              color: theme.colorScheme.primaryForeground,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${context.l10n.newToMoneko} ',
                        style: TextStyle(
                          color: theme.colorScheme.mutedForeground,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: isLoading.value ? null : () => context.go('/register'),
                        child: Text(
                          context.l10n.createAccount,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emailController = useTextEditingController();

    return AlertDialog(
      title: Text(context.l10n.resetYourPassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.sendResetLink,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: context.l10n.email,
              hintText: context.l10n.exampleEmail,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(emailController.text.trim()),
          child: Text(context.l10n.sendResetLink),
        ),
      ],
    );
  }
}
