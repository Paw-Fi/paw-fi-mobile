import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rsupa/features/auth/auth.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'dart:async';

// State provider to store registered email for OTP verification
final registeredEmailProvider = StateProvider<String?>((ref) => null);

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationSent = useState(false);
    final registeredEmail = ref.watch(registeredEmailProvider);

    return verificationSent.value && registeredEmail != null
        ? _OTPVerificationView(
            email: registeredEmail,
            onBack: () {
              verificationSent.value = false;
              ref.read(registeredEmailProvider.notifier).state = null;
            },
          )
        : _RegistrationFormView(
            onVerificationSent: (email) {
              ref.read(registeredEmailProvider.notifier).state = email;
              verificationSent.value = true;
            },
          );
  }
}

class _RegistrationFormView extends HookConsumerWidget {
  final void Function(String email) onVerificationSent;

  const _RegistrationFormView({required this.onVerificationSent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = shadcnui.Theme.of(context);
    final fullNameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final showPassword = useState(false);
    final error = useState<String?>(null);
    final isLoading = useState(false);

    Future<void> handleSignUp() async {
      final fullName = fullNameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text;

      // Validation
      if (fullName.isEmpty || fullName.length < 2) {
        error.value = 'Full name must be at least 2 characters long';
        return;
      }

      if (email.isEmpty || !email.contains('@')) {
        error.value = 'Please enter a valid email address';
        return;
      }

      if (password.isEmpty || password.length < 8) {
        error.value = 'Password must be at least 8 characters long';
        return;
      }

      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
        error.value = 'Password must contain at least one uppercase letter, one lowercase letter, and one number';
        return;
      }

      error.value = null;
      isLoading.value = true;

      try {
        await ref.read(authProvider.notifier).signUp(
              email: email,
              password: password,
              fullName: fullName,
            );

        if (context.mounted) {
          onVerificationSent(email);
        }
      } catch (e) {
        String errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');

        // Handle specific error messages
        if (errorMessage.contains('User already registered')) {
          errorMessage = 'An account with this email already exists. Please sign in instead.';
        } else if (errorMessage.contains('Invalid email')) {
          errorMessage = 'Please enter a valid email address.';
        } else if (errorMessage.contains('rate limit')) {
          errorMessage = 'Too many attempts. Please wait a moment before trying again.';
        }

        error.value = errorMessage;
      } finally {
        isLoading.value = false;
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
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Text(
                          'Create account',
                          style: theme.typography.h2,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your details to create your account',
                          style: theme.typography.textMuted,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Google Sign Up
                        GoogleLoginButton(
                          redirectUrl: '/avatar',
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
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Full Name Field
                        shadcnui.FormField(
                          key: const shadcnui.FormKey('fullname'),
                          label: const shadcnui.Text('Full name'),
                          child: shadcnui.TextField(
                            controller: fullNameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            placeholder: const shadcnui.Text('Your full name'),
                            enabled: !isLoading.value,
                          ),
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
                            onSubmitted: (_) => handleSignUp(),
                            placeholder: const shadcnui.Text('Create a strong password'),
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
                        const SizedBox(height: 24),

                        // Error Message
                        if (error.value != null)
                          shadcnui.Alert.destructive(
                            leading: const shadcnui.Icon(Icons.error),
                            title: shadcnui.Text(error.value!),
                          ),
                        if (error.value != null) const SizedBox(height: 16),

                        // Create Account Button
                        shadcnui.PrimaryButton(
                          onPressed: isLoading.value ? null : handleSignUp,
                          child: isLoading.value
                              ? const CircularProgressIndicator()
                              : const Text('Create Account'),
                        ),
                        const SizedBox(height: 16),

                        // Terms
                        Text(
                          'By creating an account, you agree to our Terms of Service and Privacy Policy',
                          style: theme.typography.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: theme.typography.textMuted,
                      ),
                      TextButton(
                        onPressed: isLoading.value
                            ? null
                            : () => context.go('/login'),
                        child: const Text('Sign in'),
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

class _OTPVerificationView extends HookConsumerWidget {
  final String email;
  final VoidCallback onBack;

  const _OTPVerificationView({
    required this.email,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme =   shadcnui.Theme.of(context);
    final otpControllers = List.generate(6, (_) => useTextEditingController());
    final focusNodes = List.generate(6, (_) => useFocusNode());
    final error = useState<String?>(null);
    final isVerifying = useState(false);
    final resendCooldown = useState(0);

    useEffect(() {
      Timer? timer;
      if (resendCooldown.value > 0) {
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (resendCooldown.value > 0) {
            resendCooldown.value--;
          }
        });
      }
      return () => timer?.cancel();
    }, [resendCooldown.value]);

    String getOtpValue() => otpControllers.map((c) => c.text).join();

    Future<void> handleVerifyOtp() async {
      final otp = getOtpValue();
      if (otp.length != 6) {
        error.value = 'Please enter the complete 6-digit code';
        return;
      }

      error.value = null;
      isVerifying.value = true;

      try {
        await ref.read(authProvider.notifier).verifyOtp(
              email: email,
              token: otp,
            );

        if (context.mounted) {
          // After successful registration, redirect to avatar customizer
          context.go('/avatar');
        }
      } catch (e) {
        String errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');

        if (errorMessage.contains('expired')) {
          errorMessage = 'Verification code has expired. Please request a new one.';
        } else if (errorMessage.contains('invalid')) {
          errorMessage = 'Invalid verification code. Please check and try again.';
        }

        error.value = errorMessage;
      } finally {
        isVerifying.value = false;
      }
    }

    Future<void> handleResend() async {
      if (resendCooldown.value > 0) return;

      error.value = null;

      try {
        await ref.read(authProvider.notifier).resendVerification(email);

        // Clear OTP fields
        for (var controller in otpControllers) {
          controller.clear();
        }

        // Start cooldown
        resendCooldown.value = 60;

        if (context.mounted) {
          shadcnui.showToast(
            context: context,
            builder: (context, overlay) => shadcnui.SurfaceCard(
              child: shadcnui.Basic(
                title: const shadcnui.Text('Verification code sent successfully'),
                leading: const shadcnui.Icon(Icons.check_circle),
              ),
            ),
          );
        }
      } catch (e) {
        String errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');

        if (errorMessage.contains('rate limit')) {
          errorMessage = 'You\'ve reached the email limit. Please wait 5-10 minutes before trying again.';
        }

        error.value = errorMessage;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Success Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: shadcnui.Icon(
                        Icons.check_circle,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Verify Your Email',
                    style: theme.typography.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: 'We\'ve sent a 6-digit verification code to ',
                      style: theme.typography.textMuted,
                      children: [
                        TextSpan(
                          text: email,
                          style: theme.typography.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // OTP Input Fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 50,
                        child: shadcnui.TextField(
                          controller: otpControllers[index],
                          focusNode: focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: theme.typography.h3,
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              focusNodes[index + 1].requestFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              focusNodes[index - 1].requestFocus();
                            }
                            if (index == 5 && value.isNotEmpty) {
                              handleVerifyOtp();
                            }
                          },
                          enabled: !isVerifying.value,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (error.value != null)
                    shadcnui.Alert.destructive(
                      leading: const shadcnui.Icon(Icons.error),
                      title: shadcnui.Text(error.value!),
                    ),
                  if (error.value != null) const SizedBox(height: 16),

                  // Verify Button
                  shadcnui.PrimaryButton(
                    onPressed: (isVerifying.value || getOtpValue().length != 6)
                        ? null
                        : handleVerifyOtp,
                    child: isVerifying.value
                        ? const CircularProgressIndicator()
                        : const Text('Verify Email'),
                  ),
                  const SizedBox(height: 24),

                  // Resend Link
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Didn\'t receive the code? Check your spam folder or',
                          style: theme.typography.textMuted,
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: resendCooldown.value > 0 ? null : handleResend,
                          child: Text(
                            resendCooldown.value > 0
                                ? 'resend in ${resendCooldown.value}s'
                                : 'resend verification email',
                          ),
                        ),
                      ],
                    ),
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
