import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/auth/presentation/pages/login_screen.dart';
import 'package:moneko/features/auth/presentation/pages/register_screen.dart';
import 'package:moneko/features/auth/presentation/pages/auth_callback_screen.dart';
import 'package:moneko/features/avatar/presentation/pages/avatar_customizer_screen.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:moneko/features/subscription/presentation/pages/paywall_screen.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/core/navigation/main_shell.dart';
import 'package:moneko/core/app/app_initialization_provider.dart';
import 'package:moneko/core/ui/pages/splash_screen.dart';

import '../ui/pages/error_page.dart';

part 'router.g.dart';

/// Global navigator key for accessing navigator from anywhere
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(RouterRef ref) {
  final auth = ref.watch(authProvider);
  final hasSubscription = ref.watch(hasActiveSubscriptionProvider);
  final isSubscriptionLoaded = ref.watch(isSubscriptionLoadedProvider);
  final appInitState = ref.watch(appInitializationProvider);

  // Keep subscription provider alive
  ref.watch(subscriptionNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: RouterNotifier(ref),
    routes: [
      // Splash Screen Route
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

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
      final isOnSplashPage = state.matchedLocation == '/splash';
      final isOnAuthPage = state.matchedLocation == '/login' ||
                          state.matchedLocation == '/register' ||
                          state.matchedLocation.startsWith('/auth/callback');
      final isOnboardingPage = state.matchedLocation == '/avatar' ||
                              state.matchedLocation == '/onboarding';
      final isOnPaywallPage = state.matchedLocation == '/paywall';

      if (kDebugMode) {
        debugPrint('🔐 Auth redirect: init=$appInitState, isAuth=$isAuthenticated, hasSub=$hasSubscription, loaded=$isSubscriptionLoaded, path=${state.matchedLocation}');
      }

      // If app is still initializing, stay on splash screen
      if (appInitState != AppInitState.initialized) {
        if (!isOnSplashPage) {
          return '/splash';
        }
        return null;
      }

      // App is initialized, proceed with normal routing
      
      // Don't redirect if already leaving splash
      if (isOnSplashPage) {
        // Redirect from splash to appropriate page
        if (isAuthenticated) {
          if (!isSubscriptionLoaded) {
            // Wait for subscription to load
            return null;
          }
          if (!hasSubscription) {
            return '/paywall';
          }
          return '/dashboard';
        } else {
          return '/login';
        }
      }

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
        // If subscription is still loading, allow navigation (don't redirect yet)
        if (!isSubscriptionLoaded) {
          return null;
        }
        // Check subscription status
        if (!hasSubscription) {
          return '/paywall';
        }
        return '/dashboard';
      }

      // If authenticated but no subscription and trying to access protected pages
      // Only redirect to paywall if subscription is confirmed loaded
      if (isAuthenticated && isSubscriptionLoaded && !hasSubscription && !isOnPaywallPage) {
        return '/paywall';
      }

      // Allow navigation (includes when subscription is loading)
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
      (previous, next) {
        notifyListeners();
        // Reset initialization when auth changes
        if (previous?.uid != next.uid) {
          if (kDebugMode) {
            debugPrint('🔄 Auth changed: ${previous?.uid} -> ${next.uid}');
          }
          
          // If logging out (going from authenticated to not authenticated)
          if (previous != null && !previous.isEmpty && next.isEmpty) {
            if (kDebugMode) {
              debugPrint('👋 User logged out, clearing cache');
            }
            _ref.read(appInitializationProvider.notifier).clearCache();
          }
          
          // Reset initialization for both login and logout
          _ref.read(appInitializationProvider.notifier).reset();
        }
      },
    );
    
    // Listen to app initialization state changes
    _ref.listen<AppInitState>(
      appInitializationProvider,
      (_, __) => notifyListeners(),
    );
  }
}
