import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/auth/presentation/widgets/apple_login_button.dart';
import 'package:moneko/features/auth/presentation/widgets/wallet_login_button.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/otp_input.dart';

import 'dart:async';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

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
    final theme = Theme.of(context);
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
      void passwordListener() =>
          passwordHasFocus.value = passwordFocusNode.hasFocus;

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
        error.value = context.l10n.fullNameMinLength(2);
        errorShake.value = true;
        return;
      }

      if (email.isEmpty || !email.contains('@')) {
        error.value = context.l10n.enterValidEmail;
        errorShake.value = true;
        return;
      }

      if (password.isEmpty || password.length < 8) {
        error.value = context.l10n.passwordMinLength(8);
        errorShake.value = true;
        return;
      }

      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
        error.value = context.l10n.passwordComplexityRequirement;
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
        error.value = formatAuthErrorMessage(e);
        errorShake.value = true;
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.appBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
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
                          context.l10n.createYourAccount,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.mutedForeground,
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
                          color: theme.colorScheme.foreground
                              .withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: theme.colorScheme.foreground
                              .withValues(alpha: 0.03),
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
                          // OAuth Sign Up
                          GoogleLoginButton(
                            redirectUrl: '/dashboard',
                            disabled: isLoading.value,
                          ),
                          const SizedBox(height: 12),
                          AppleLoginButton(
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
                                        theme.colorScheme.border
                                            .withValues(alpha: 0.0),
                                        theme.colorScheme.border
                                            .withValues(alpha: 0.5),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  context.l10n.orContinueWithEmail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.border
                                            .withValues(alpha: 0.5),
                                        theme.colorScheme.border
                                            .withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Full Name Field with focus animation
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: nameHasFocus.value
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.border,
                                width: nameHasFocus.value ? 2 : 1,
                              ),
                            ),
                            child: TextField(
                              controller: fullNameController,
                              focusNode: nameFocusNode,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              enabled: !isLoading.value,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.foreground,
                              ),
                              decoration: InputDecoration(
                                hintText: context.l10n.fullName,
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.mutedForeground
                                      .withValues(alpha: 0.6),
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
                                  color: theme.colorScheme.mutedForeground
                                      .withValues(alpha: 0.6),
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
                              onSubmitted: (_) => handleSignUp(),
                              enabled: !isLoading.value,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.foreground,
                              ),
                              decoration: InputDecoration(
                                hintText: context.l10n.createPassword,
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.mutedForeground
                                      .withValues(alpha: 0.6),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      showPassword.value = !showPassword.value,
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

                          // Password requirements
                          Text(
                            context.l10n.passwordRequirementShort,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.mutedForeground,
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
                                final shake =
                                    errorShake.value ? (1 - value) * 10 : 0.0;
                                return Transform.translate(
                                  offset: Offset(
                                      shake * (value % 2 == 0 ? 1 : -1), 0),
                                  child: child,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.destructive
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.destructive
                                        .withValues(alpha: 0.3),
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
                                    theme.colorScheme.primary
                                        .withValues(alpha: 0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: theme.colorScheme.surface
                                    .withValues(alpha: 0.0),
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
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                theme.colorScheme
                                                    .primaryForeground,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            context.l10n.createAccount,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme
                                                  .primaryForeground,
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
                            context.l10n.termsAgreement,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.mutedForeground,
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
                        '${context.l10n.alreadyHaveAccount} ',
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            isLoading.value ? null : () => context.go('/login'),
                        child: Text(
                          context.l10n.signInLower,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    final otpValue = useState<String>('');
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

    Future<void> handleVerifyOtp() async {
      final l10n = context.l10n;
      final otp = otpValue.value;
      if (otp.length != 6) {
        error.value = l10n.enterCompleteCode;
        return;
      }

      error.value = null;
      isVerifying.value = true;

      try {
        await ref.read(authProvider.notifier).verifyOtp(
              email: email,
              token: otp,
            );
        // After the account is verified (user authenticated), register device for push notifications
        try {
          await ref.read(deviceRegistrationServiceProvider).initialize();
        } catch (_) {}

        if (context.mounted) {
          // After successful registration, redirect to avatar customizer
          context.go('/avatar');
        }
      } catch (e) {
        error.value = formatAuthErrorMessage(e);
      } finally {
        isVerifying.value = false;
      }
    }

    Future<void> handleResend() async {
      if (resendCooldown.value > 0) return;

      error.value = null;

      try {
        await ref.read(authProvider.notifier).resendVerification(email);

        // Clear OTP field
        otpValue.value = '';

        // Start cooldown
        resendCooldown.value = 60;

        if (context.mounted) {
          AppToast.success(context, context.l10n.verificationCodeSent);
        }
      } catch (e) {
        error.value = formatAuthErrorMessage(e);
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
                      child: Icon(
                        Icons.check_circle,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    context.l10n.verifyYourEmail,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.verificationEmailSentTo(email),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // OTP Input Field
                  OtpInput(
                    length: 6,
                    onChanged: (value) {
                      otpValue.value = value;
                    },
                    onCompleted: (value) {
                      if (value.length == 6 && !isVerifying.value) {
                        handleVerifyOtp();
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (error.value != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.destructive
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.destructive
                              .withValues(alpha: 0.3),
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
                  if (error.value != null) const SizedBox(height: 16),

                  // Verify Button
                  ValueListenableBuilder(
                    valueListenable: otpValue,
                    builder: (context, _, __) {
                      return ValueListenableBuilder(
                        valueListenable: isVerifying,
                        builder: (context, _, __) {
                          return SizedBox(
                            width: double.infinity,
                            child: PrimaryAdaptiveButton(
                              onPressed: (isVerifying.value ||
                                      otpValue.value.length != 6)
                                  ? null
                                  : handleVerifyOtp,
                              child: isVerifying.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(context.l10n.verifyEmail),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Resend Link
                  Center(
                    child: Column(
                      children: [
                        Text(
                          context.l10n.didntReceiveTheCode,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed:
                              resendCooldown.value > 0 ? null : handleResend,
                          child: Text(
                            resendCooldown.value > 0
                                ? context.l10n
                                    .resendInSeconds(resendCooldown.value)
                                : context.l10n.resendVerificationEmail,
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
