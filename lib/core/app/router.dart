import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rsupa/features/auth/auth.dart';
import 'package:rsupa/features/auth/presentation/pages/login_screen.dart';
import 'package:rsupa/features/auth/presentation/pages/register_screen.dart';
import 'package:rsupa/features/auth/presentation/pages/auth_callback_screen.dart';
import 'package:rsupa/features/avatar/presentation/pages/avatar_customizer_screen.dart';
import 'package:rsupa/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:rsupa/features/subscription/presentation/pages/paywall_screen.dart';
import 'package:rsupa/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:rsupa/core/navigation/main_shell.dart';

import '../ui/pages/error_page.dart';

part 'router.g.dart';

@riverpod
GoRouter router(RouterRef ref) {
  final auth = ref.watch(authProvider);
  final hasSubscription = ref.watch(hasActiveSubscriptionProvider);

  // Keep subscription provider alive
  ref.watch(subscriptionNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: RouterNotifier(ref),
    routes: [
      // Home/Dashboard Route
      GoRoute(
        path: '/',
        redirect: (context, state) => '/dashboard',
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainShell(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) {
          final next = state.uri.queryParameters['next'];
          return AuthCallbackScreen(next: next);
        },
      ),

      // Subscription Routes
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),

      // Onboarding Routes
      GoRoute(
        path: '/avatar',
        builder: (context, state) => const AvatarCustomizerScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated = !auth.isEmpty;
      final isOnAuthPage = state.matchedLocation == '/login' ||
                          state.matchedLocation == '/register' ||
                          state.matchedLocation.startsWith('/auth/callback');
      final isOnboardingPage = state.matchedLocation == '/avatar' ||
                              state.matchedLocation == '/onboarding';
      final isOnPaywallPage = state.matchedLocation == '/paywall';

      debugPrint('🔐 Auth redirect: isAuth=$isAuthenticated, hasSub=$hasSubscription, path=${state.matchedLocation}');

      // Allow auth callback to proceed
      if (state.matchedLocation.startsWith('/auth/callback')) {
        return null;
      }

      // Allow onboarding pages for both authenticated and unauthenticated users
      if (isOnboardingPage) {
        return null;
      }

      // Allow paywall page for authenticated users
      if (isOnPaywallPage && isAuthenticated) {
        return null;
      }

      // If not authenticated and not on auth/onboarding page, redirect to login
      if (!isAuthenticated && !isOnAuthPage) {
        return '/login';
      }

      // If authenticated and on auth page, check subscription then redirect
      if (isAuthenticated && isOnAuthPage) {
        // Check subscription status
        if (!hasSubscription) {
          return '/paywall';
        }
        return '/dashboard';
      }

      // If authenticated but no subscription and trying to access protected pages
      if (isAuthenticated && !hasSubscription && !isOnPaywallPage) {
        return '/paywall';
      }

      // Allow navigation
      return null;
    },
    errorBuilder: (context, state) => ErrorPage(state.error),
  );
}

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Listen to auth changes which triggers router rebuild
    _ref.listen<AppUser>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}
