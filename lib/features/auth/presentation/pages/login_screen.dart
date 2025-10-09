import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rsupa/features/auth/auth.dart';
import 'package:rsupa/features/auth/presentation/widgets/google_login_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = shadcnui.Theme.of(context);
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final showPassword = useState(false);
    final error = useState<String?>(null);
    final isLoading = useState(false);

    Future<void> handleSignIn() async {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (email.isEmpty || !email.contains('@')) {
        error.value = 'Please enter a valid email address';
        return;
      }

      if (password.isEmpty || password.length < 6) {
        error.value = 'Password must be at least 6 characters long';
        return;
      }

      error.value = null;
      isLoading.value = true;

      try {
        await ref.read(authProvider.notifier).signIn(email, password);

        if (context.mounted) {
          context.go('/dashboard');
        }
      } catch (e) {
        error.value = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
      } finally {
        isLoading.value = false;
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
        if (context.mounted) {
          shadcnui.showToast(
            context: context,
            builder: (context, overlay) => shadcnui.Alert(
              leading: const shadcnui.Icon(Icons.check_circle),
              title: const shadcnui.Text('Password reset email sent. Check your inbox.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          shadcnui.showToast(
            context: context,
            builder: (context, overlay) => shadcnui.Alert.destructive(
              leading: const shadcnui.Icon(Icons.error),
              title: shadcnui.Text(e.toString().replaceAll('Exception: ', '')),
            ),
          );
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Brand
                  Text(
                    'Moneko',
                    style: theme.typography.h1.copyWith(
                      color: theme.colorScheme.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Card with form
                  shadcnui.Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Text(
                          'Sign in',
                          style: theme.typography.h2,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your email and password to access your account',
                          style: theme.typography.textMuted,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Google Sign In
                        GoogleLoginButton(
                          redirectUrl: '/dashboard',
                          disabled: isLoading.value,
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: shadcnui.Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Or continue with',
                                style: theme.typography.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                            const Expanded(child: shadcnui.Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email Field
                        shadcnui.FormField(
                          key: const shadcnui.FormKey('email'),
                          label: const shadcnui.Text('Email'),
                          child: shadcnui.TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            placeholder: const shadcnui.Text('name@example.com'),
                            enabled: !isLoading.value,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        shadcnui.FormField(
                          key: const shadcnui.FormKey('password'),
                          label: const shadcnui.Text('Password'),
                          child: shadcnui.TextField(
                            controller: passwordController,
                            obscureText: !showPassword.value,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => handleSignIn(),
                            placeholder: const shadcnui.Text('Enter your password'),
                            trailing: shadcnui.IconButton(
                              variance: shadcnui.ButtonVariance.ghost,
                              icon: shadcnui.Icon(
                                showPassword.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => showPassword.value = !showPassword.value,
                            ),
                            enabled: !isLoading.value,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: shadcnui.TextButton(
                            onPressed: isLoading.value ? null : handleResetPassword,
                            child: const shadcnui.Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Error Message
                        if (error.value != null)
                          shadcnui.Alert.destructive(
                            leading: const shadcnui.Icon(Icons.error),
                            title: shadcnui.Text(error.value!),
                          ),
                        if (error.value != null) const SizedBox(height: 16),

                        // Sign In Button
                        shadcnui.PrimaryButton(
                          onPressed: isLoading.value ? null : handleSignIn,
                          child: isLoading.value
                              ? const shadcnui.CircularProgressIndicator()
                              : const shadcnui.Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to Moneko? ',
                        style: theme.typography.textMuted,
                      ),
                      shadcnui.TextButton(
                        onPressed: isLoading.value
                            ? null
                            : () => context.go('/register'),
                        child: const shadcnui.Text('Register'),
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
    final theme = shadcnui.Theme.of(context);
    final emailController = useTextEditingController();

    return shadcnui.AlertDialog(
      title: const shadcnui.Text('Reset your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          shadcnui.Text(
            'Enter your email and we will send you a password reset link.',
            style: theme.typography.textMuted,
          ),
          const SizedBox(height: 16),
          shadcnui.FormField(
            key: const shadcnui.FormKey('reset-email'),
            label: const shadcnui.Text('Email'),
            child: shadcnui.TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              placeholder: const shadcnui.Text('you@example.com'),
            ),
          ),
        ],
      ),
      actions: [
        shadcnui.OutlineButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const shadcnui.Text('Cancel'),
        ),
        shadcnui.PrimaryButton(
          onPressed: () => Navigator.of(context).pop(emailController.text.trim()),
          child: const shadcnui.Text('Send reset link'),
        ),
      ],
    );
  }
}
