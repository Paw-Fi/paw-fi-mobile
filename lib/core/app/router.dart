import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/avatar/presentation/pages/avatar_customizer_screen.dart';
import 'package:moneko/features/subscription/presentation/pages/paywall_screen.dart';
import 'package:moneko/features/subscription/presentation/pages/plan_selection_page.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/core/navigation/main_shell.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/ui/pages/splash_screen.dart';
import 'package:moneko/features/households/presentation/pages/household_invites_page.dart';
import 'package:moneko/features/households/presentation/pages/household_join_page.dart';
import 'package:moneko/features/households/presentation/pages/household_members_page.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_flow_page.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';
import 'package:moneko/features/home/presentation/state/state.dart';

import '../ui/pages/error_page.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

part 'router.g.dart';

/// Global navigator key for accessing navigator from anywhere
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(RouterRef ref) {
  final auth = ref.watch(authProvider);
  final hasSubscription = ref.watch(hasActiveSubscriptionProvider);
  final isSubscriptionLoaded = ref.watch(isSubscriptionLoadedProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  // Use V2 initialization provider (cache-first, faster)
  final appInitStateV2 = ref.watch(appInitializationV2Provider);

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

      // Fatal error page
      GoRoute(
        path: '/error',
        builder: (context, state) {
          final initStateV2 = ref.read(appInitializationV2Provider);
          final exception = state.extra is Exception
              ? state.extra as Exception
              : initStateV2.error;
          return ErrorPage(
            exception,
            details: initStateV2.errorMessage,
            stackTrace: initStateV2.errorStackTrace,
          );
        },
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
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return PaywallScreen(mode: PaywallModeX.fromQuery(mode));
        },
      ),
      GoRoute(
        path: '/plan-selection',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return PlanSelectionPage(mode: PlanSelectionModeX.fromQuery(mode));
        },
      ),

      // Deep link routes - show dashboard so sheet appears on a valid page
      GoRoute(
        path: '/expense/:id',
        redirect: (context, state) {
          debugPrint('🔗 Expense deep link, showing dashboard');
          return '/dashboard';
        },
      ),
      GoRoute(
        path: '/budget/:id',
        redirect: (context, state) {
          debugPrint('🔗 Budget deep link, showing dashboard');
          return '/dashboard';
        },
      ),
      GoRoute(
        path: '/split/:id',
        redirect: (context, state) {
          debugPrint('🔗 Split deep link, showing dashboard');
          return '/dashboard';
        },
      ),

      // Household join page (with optional token query param)
      GoRoute(
        path: '/households/join',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return HouseholdJoinPage(initialToken: token);
        },
      ),

      // Household routes (household overview moved to home page "For Us" mode)
      GoRoute(
        path: '/households/:householdId/invites',
        builder: (context, state) {
          final householdId = state.pathParameters['householdId'] ?? '';
          return HouseholdInvitesPage(householdId: householdId);
        },
      ),
      GoRoute(
        path: '/households/:householdId/members',
        builder: (context, state) {
          final householdId = state.pathParameters['householdId'] ?? '';
          return HouseholdMembersPage(householdId: householdId);
        },
      ),
      GoRoute(
        path: '/households/:householdId/settings',
        builder: (context, state) {
          final householdId = state.pathParameters['householdId'] ?? '';
          return HouseholdSettingsPage(householdId: householdId);
        },
      ),

      // Onboarding Routes
      GoRoute(
        path: '/avatar',
        builder: (context, state) => const AvatarCustomizerScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowPage(),
      ),

      // Catch-all route for deep links with UUID patterns (expense, budget, split IDs)
      // This handles paths like /{uuid} that come from moneko://expense/{uuid}
      GoRoute(
        path: '/:id',
        redirect: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          debugPrint(
              '🔗 Catch-all route matched for ID: $id, redirecting to dashboard');
          return '/dashboard';
        },
      ),
    ],
    redirect: (context, state) {
      try {
        // Handle invitation universal links - redirect to home page
        // The invitation modal is shown by deep_link_service.dart on top of the home page
        if (state.matchedLocation.startsWith('/invites/')) {
          debugPrint(
              '🔗 Invitation universal link detected: ${state.matchedLocation}');
          // Redirect to home page where modal will be shown
          return '/';
        }

        final isAuthenticated = !auth.isEmpty;
        final hasOnboarded = !isAuthenticated
            ? true
            : (prefs.getBool('onboarding_completed:${auth.uid}') ?? false);
        final isOnSplashPage = state.matchedLocation == '/splash';
        final isOnAuthPage = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation.startsWith('/auth/callback');
        final isOnboardingPage = state.matchedLocation == '/avatar' ||
            state.matchedLocation == '/onboarding';
        final isOnPaywallPage = state.matchedLocation == '/paywall';
        final isOnPlanSelectionPage =
            state.matchedLocation == '/plan-selection';
        final isOnErrorPage = state.matchedLocation == '/error';

        if (kDebugMode) {
          debugPrint(
              '🔐 Auth redirect [V2]: state=${appInitStateV2.state}, isAuth=$isAuthenticated, hasSub=$hasSubscription, loaded=$isSubscriptionLoaded, path=${state.matchedLocation}');
        }

        // V2: Surface fatal initialization failures ONLY if no cached data available
        if (appInitStateV2.state == AppInitState.failed &&
            appInitStateV2.data == null) {
          if (!isOnErrorPage) {
            debugPrint(
                '❌ [RouterV2] Init failed with no cache, showing error page');
            return '/error';
          }
          return null;
        }

        // V2: Don't block on splash - navigate immediately after auth check
        // Splash screen only shown briefly during initial app load
        if (isOnSplashPage) {
          debugPrint(
              '🚀 [RouterV2] On splash, redirecting immediately based on auth');
          // Redirect from splash to appropriate page
          if (isAuthenticated) {
            // Always check onboarding first
            if (!hasOnboarded) {
              return '/onboarding';
            }
            // On web: skip paywall and go straight to dashboard
            if (kIsWeb) {
              return '/dashboard';
            }
            // For completed onboarding: check subscription if loaded
            if (isSubscriptionLoaded) {
              if (!hasSubscription) {
                // Check if user ever had a subscription
                final everSubscribed =
                    prefs.getBool('ever_subscribed:${auth.uid}') ?? false;
                if (everSubscribed) {
                  return '/plan-selection?mode=resubscribe';
                } else {
                  return '/plan-selection?mode=trial';
                }
              }
            }
            return '/dashboard'; // Navigate immediately, UI will show skeletons
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

        // Allow paywall page for authenticated users (mobile only)
        if (!kIsWeb && isOnPaywallPage && isAuthenticated) {
          return null;
        }

        if (!kIsWeb && isOnPlanSelectionPage && isAuthenticated) {
          return null;
        }

        // If not authenticated and not on auth/onboarding page, redirect to login
        if (!isAuthenticated && !isOnAuthPage) {
          return '/login';
        }

        // If authenticated and on auth page, check onboarding then subscription then redirect
        if (isAuthenticated && isOnAuthPage) {
          // Always prioritize onboarding
          if (!hasOnboarded) {
            return '/onboarding';
          }
          // If subscription is still loading, allow navigation (don't redirect yet)
          if (!isSubscriptionLoaded) {
            return null;
          }
          // Check subscription status
          if (!hasSubscription) {
            // On web: skip paywall and go straight to dashboard
            if (kIsWeb) return '/dashboard';
            // Check if user ever had a subscription to determine paywall mode
            final everSubscribed =
                prefs.getBool('ever_subscribed:${auth.uid}') ?? false;
            if (everSubscribed) {
              return '/plan-selection?mode=resubscribe';
            } else {
              return '/plan-selection?mode=trial';
            }
          }
          return '/dashboard';
        }

        // If authenticated but no subscription and trying to access protected pages
        // Only redirect to paywall if subscription is confirmed loaded and onboarding completed
        if (!kIsWeb &&
            isAuthenticated &&
            hasOnboarded &&
            isSubscriptionLoaded &&
            !hasSubscription &&
            !isOnPaywallPage &&
            !isOnPlanSelectionPage &&
            !isOnboardingPage) {
          // Check if user ever had a subscription to determine paywall mode
          final everSubscribed =
              prefs.getBool('ever_subscribed:${auth.uid}') ?? false;
          if (everSubscribed) {
            return '/plan-selection?mode=resubscribe';
          } else {
            return '/plan-selection?mode=trial';
          }
        }

        // Allow navigation (includes when subscription is loading)
        return null;
      } catch (e, s) {
        // Record non-fatal to Crashlytics for production observability
        try {
          FirebaseCrashlytics.instance
              .recordError(e, s, fatal: false, reason: 'router_redirect_error');
        } catch (_) {}
        debugPrint('Router redirect error: $e');
        debugPrint(s.toString());
        return '/splash';
      }
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
              debugPrint('👋 User logged out, clearing cache (V2)');
            }
            _ref.read(appInitializationV2Provider.notifier).onLogout();
            _ref.read(widgetSyncStateProvider.notifier).reset();
          } else {
            // Reset initialization for login (not logout)
            _ref.read(appInitializationV2Provider.notifier).reset();
          }
        }
      },
    );

    // Listen to app initialization state changes (V2)
    _ref.listen<AppInitializationState>(
      appInitializationV2Provider,
      (_, __) => notifyListeners(),
    );
  }
}
