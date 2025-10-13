import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
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
    final nameFocusNode = useFocusNode();
    final emailFocusNode = useFocusNode();
    final passwordFocusNode = useFocusNode();
    final nameHasFocus = useState(false);
    final emailHasFocus = useState(false);
    final passwordHasFocus = useState(false);
    final errorShake = useState(false);

    // Focus listeners for micro-interactions
    useEffect(() {
      void nameListener() => nameHasFocus.value = nameFocusNode.hasFocus;
      void emailListener() => emailHasFocus.value = emailFocusNode.hasFocus;
      void passwordListener() => passwordHasFocus.value = passwordFocusNode.hasFocus;

      nameFocusNode.addListener(nameListener);
      emailFocusNode.addListener(emailListener);
      passwordFocusNode.addListener(passwordListener);

      return () {
        nameFocusNode.removeListener(nameListener);
        emailFocusNode.removeListener(emailListener);
        passwordFocusNode.removeListener(passwordListener);
      };
    }, [nameFocusNode, emailFocusNode, passwordFocusNode]);

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

    Future<void> handleSignUp() async {
      final fullName = fullNameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text;

      // Validation
      if (fullName.isEmpty || fullName.length < 2) {
        error.value = 'Full name must be at least 2 characters long';
        errorShake.value = true;
        return;
      }

      if (email.isEmpty || !email.contains('@')) {
        error.value = 'Please enter a valid email address';
        errorShake.value = true;
        return;
      }

      if (password.isEmpty || password.length < 8) {
        error.value = 'Password must be at least 8 characters long';
        errorShake.value = true;
        return;
      }

      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
        error.value = 'Password must contain at least one uppercase letter, one lowercase letter, and one number';
        errorShake.value = true;
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
        errorShake.value = true;
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
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
                          'Moneko',
                          style: theme.typography.h1.copyWith(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.5,
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your account',
                          style: theme.typography.large.copyWith(
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
                          color: theme.colorScheme.foreground.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: theme.colorScheme.foreground.withOpacity(0.03),
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
                          // Google Sign Up
                          GoogleLoginButton(
                            redirectUrl: '/avatar',
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
                                        theme.colorScheme.border.withOpacity(0.5),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Or continue with email',
                                  style: theme.typography.small.copyWith(
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
                                        theme.colorScheme.border.withOpacity(0.5),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Full Name Field with focus animation
                          shadcnui.TextField(
                            controller: fullNameController,
                            focusNode: nameFocusNode,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            placeholder: shadcnui.Text(
                              'Full name',
                              style: TextStyle(
                                color: theme.colorScheme.mutedForeground.withOpacity(0.6),
                              ),
                            ),
                            enabled: !isLoading.value,
                            style: theme.typography.base.copyWith(fontSize: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: nameHasFocus.value
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.border,
                                width: nameHasFocus.value ? 2 : 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email Field with focus animation
                          shadcnui.TextField(
                            controller: emailController,
                            focusNode: emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            placeholder: shadcnui.Text(
                              'Email address',
                              style: TextStyle(
                                color: theme.colorScheme.mutedForeground.withOpacity(0.6),
                              ),
                            ),
                            enabled: !isLoading.value,
                            style: theme.typography.base.copyWith(fontSize: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: emailHasFocus.value
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.border,
                                width: emailHasFocus.value ? 2 : 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Field with focus animation
                          shadcnui.TextField(
                            controller: passwordController,
                            focusNode: passwordFocusNode,
                            obscureText: !showPassword.value,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => handleSignUp(),
                            placeholder: shadcnui.Text(
                              'Create a password',
                              style: TextStyle(
                                color: theme.colorScheme.mutedForeground.withOpacity(0.6),
                              ),
                            ),
                            trailing: GestureDetector(
                              onTap: () => showPassword.value = !showPassword.value,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  showPassword.value
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: theme.colorScheme.mutedForeground,
                                  size: 20,
                                ),
                              ),
                            ),
                            enabled: !isLoading.value,
                            style: theme.typography.base.copyWith(fontSize: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: passwordHasFocus.value
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.border,
                                width: passwordHasFocus.value ? 2 : 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Password requirements
                          Text(
                            'Password must be 8+ characters with uppercase, lowercase, and number',
                            style: theme.typography.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.left,
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
                                  color: theme.colorScheme.destructive.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.destructive.withOpacity(0.3),
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
                                        style: theme.typography.small.copyWith(
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

                          // Create Account Button with press animation
                          AnimatedScale(
                            scale: isLoading.value ? 0.98 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withOpacity(0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isLoading.value ? null : handleSignUp,
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
                                            'Create Account',
                                            style: theme.typography.base.copyWith(
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
                          const SizedBox(height: 16),

                          // Terms
                          Text(
                            'By creating an account, you agree to our Terms of Service and Privacy Policy',
                            style: theme.typography.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign In Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: theme.typography.base.copyWith(
                          color: theme.colorScheme.mutedForeground,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: isLoading.value ? null : () => context.go('/login'),
                        child: Text(
                          'Sign in',
                          style: theme.typography.base.copyWith(
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
