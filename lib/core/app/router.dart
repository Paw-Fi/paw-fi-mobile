import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/avatar/presentation/pages/avatar_customizer_screen.dart';
import 'package:moneko/features/subscription/presentation/pages/plan_selection_page.dart';
import 'package:moneko/features/subscription/presentation/pages/paywall_screen.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/core/navigation/main_shell.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/ui/pages/splash_screen.dart';
import 'package:moneko/features/households/presentation/pages/household_invites_page.dart';
import 'package:moneko/features/households/presentation/pages/household_join_page.dart';
import 'package:moneko/features/households/presentation/pages/household_members_page.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_flow_page.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_post_auth_flow_page.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';
import 'package:moneko/features/households/presentation/pages/settlement_history_page.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/insights/presentation/pages/monthly_report_page.dart';
import 'package:moneko/features/import/presentation/pages/import_wizard_page.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_pre_auth_flow_page.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_account_preparing_page.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_save_budget_page.dart';

import '../ui/pages/error_page.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

part 'router.g.dart';

/// Global navigator key for accessing navigator from anywhere
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(RouterRef ref) {
  ref.keepAlive();
  final routerNotifier = RouterNotifier(ref);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: routerNotifier,
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
      GoRoute(
        path: '/insights/monthly-report/balance',
        builder: (context, state) => MonthlyReportDetailPage(
          kind: MonthlyReportDetailKind.balance,
          query: monthlyReportQueryFromUri(state.uri),
        ),
      ),
      GoRoute(
        path: '/insights/monthly-report/safe-spend',
        builder: (context, state) => MonthlyReportDetailPage(
          kind: MonthlyReportDetailKind.safeSpend,
          query: monthlyReportQueryFromUri(state.uri),
        ),
      ),
      GoRoute(
        path: '/insights/monthly-report/spending',
        builder: (context, state) => MonthlyReportDetailPage(
          kind: MonthlyReportDetailKind.spending,
          query: monthlyReportQueryFromUri(state.uri),
        ),
      ),
      GoRoute(
        path: '/insights/monthly-report/budget',
        builder: (context, state) => MonthlyReportDetailPage(
          kind: MonthlyReportDetailKind.budget,
          query: monthlyReportQueryFromUri(state.uri),
        ),
      ),
      GoRoute(
        path: '/insights/monthly-report/savings',
        builder: (context, state) => MonthlyReportDetailPage(
          kind: MonthlyReportDetailKind.savings,
          query: monthlyReportQueryFromUri(state.uri),
        ),
      ),
      GoRoute(
        path: '/insights/monthly-report/categories',
        builder: (context, state) => MonthlyReportDetailPage(
          kind: MonthlyReportDetailKind.categories,
          query: monthlyReportQueryFromUri(state.uri),
          selectedCategoryName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/insights/monthly-report/recurring',
        builder: (context, state) => MonthlyReportDetailPage(
          kind: MonthlyReportDetailKind.recurring,
          query: monthlyReportQueryFromUri(state.uri),
        ),
      ),
      GoRoute(
        path: '/insights/monthly-report/drilldown',
        builder: (context, state) => MonthlyReportDrillDownPage(
          query: monthlyReportQueryFromUri(state.uri),
          title: state.uri.queryParameters['title'],
          subtitle: state.uri.queryParameters['subtitle'],
          sourceTransactionIds: state.uri.queryParameters['ids'],
          recurringId: state.uri.queryParameters['recurringId'],
          goalId: state.uri.queryParameters['goalId'],
        ),
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

      // Subscription / Paywall
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          final modeStr = state.uri.queryParameters['mode'];
          return PaywallScreen(
            mode: PaywallModeX.fromQuery(modeStr),
          );
        },
      ),
      GoRoute(
        path: '/plan-selection',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return PlanSelectionPage(mode: PlanSelectionModeX.fromQuery(mode));
        },
      ),

      GoRoute(
        path: '/import',
        builder: (context, state) => const ImportWizardPage(),
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
      GoRoute(
        path: '/households/:householdId/settlements',
        builder: (context, state) {
          final householdId = state.pathParameters['householdId'] ?? '';
          return SettlementHistoryPage(householdId: householdId);
        },
      ),

      // Onboarding Routes
      GoRoute(
        path: '/avatar',
        builder: (context, state) => const AvatarCustomizerScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          final stage = state.uri.queryParameters['stage'];
          final debugPost =
              kDebugMode && state.uri.queryParameters['debug'] == 'post';
          if (stage == 'pre') {
            return const OnboardingPreAuthFlowPage();
          }
          if (stage == 'save_budget') {
            return const OnboardingSaveBudgetPage();
          }
          if (stage == 'prepare') {
            return const OnboardingAccountPreparingPage();
          }
          if (stage == 'post') {
            return const OnboardingPostAuthFlowPage();
          }
          return OnboardingFlowPage(debugForcePostFlow: debugPost);
        },
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
        final auth = ref.read(authProvider);
        final subscriptionGateStatus = ref.read(subscriptionGateStatusProvider);
        final subscriptionAsync = ref.read(subscriptionNotifierProvider);
        final prefs = ref.read(sharedPreferencesProvider);
        final previewMode = ref.read(previewModeProvider);
        final hasCompletedPreauth =
            prefs.getBool('onboarding_preauth_completed') ?? false;
        final draftRaw = prefs.getString('onboarding_preauth_draft_v2') ??
            prefs.getString('onboarding_preauth_draft_v1');
        final hasInProgressPreauthDraft = () {
          if (draftRaw == null || draftRaw.isEmpty) return false;
          try {
            final decoded = jsonDecode(draftRaw);
            if (decoded is! Map<String, dynamic>) return false;
            final currentStep = (decoded['currentStep'] as num?)?.toInt() ?? 0;
            return currentStep > 0;
          } catch (_) {
            return false;
          }
        }();
        final appInitStateV2 = ref.read(appInitializationV2Provider);

        // Handle invitation universal links - redirect to home page
        // The invitation modal is shown by deep_link_service.dart on top of the home page
        if (state.matchedLocation.startsWith('/invites/')) {
          debugPrint(
              '🔗 Invitation universal link detected: ${state.matchedLocation}');
          // Redirect to home page where modal will be shown
          return '/';
        }

        final isAuthenticated = !auth.isEmpty;
        final isPreauthSynced = isAuthenticated
            ? (prefs.getBool('onboarding_preauth_synced:${auth.uid}') ?? false)
            : false;
        final hasOnboarded = !isAuthenticated
            ? true
            : (prefs.getBool('onboarding_completed:${auth.uid}') ?? false);
        final isPreview = previewMode.isActive;
        final onboardingStage = state.uri.queryParameters['stage'];
        final isDebugPostBypass =
            kDebugMode && state.uri.queryParameters['debug'] == 'post';
        final isOnSplashPage = state.matchedLocation == '/splash';
        final isOnAuthPage = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation.startsWith('/auth/callback');
        final isOnPreOnboardingPage = state.matchedLocation == '/onboarding' &&
            (onboardingStage == 'pre' || onboardingStage == 'save_budget');
        final isOnPrepareOnboardingPage =
            state.matchedLocation == '/onboarding' &&
                onboardingStage == 'prepare';
        final isOnPostOnboardingPage = state.matchedLocation == '/onboarding' &&
            onboardingStage != 'pre' &&
            onboardingStage != 'save_budget' &&
            onboardingStage != 'prepare';
        final isOnboardingPage = state.matchedLocation == '/avatar' ||
            state.matchedLocation == '/onboarding';
        final isOnPaywallPage = state.matchedLocation == '/paywall';
        final isOnPlanSelectionPage =
            state.matchedLocation == '/plan-selection';
        final isOnErrorPage = state.matchedLocation == '/error';

        if (kDebugMode) {
          debugPrint(
              '🔐 Auth redirect [V2]: state=${appInitStateV2.state}, isAuth=$isAuthenticated, subGate=$subscriptionGateStatus, path=${state.matchedLocation}');
        }

        final requiresPaywall = subscriptionGateStatus.requiresPaywall;
        final isSubscriptionChecking = subscriptionGateStatus.isLoading;
        final hasExpiredEntitlement = subscriptionAsync.maybeWhen(
          data: (subscription) {
            if (subscription == null) return false;
            final status = (subscription.status ?? '').toLowerCase();
            if (status != 'trialing' && status != 'active') return false;
            final endAt = subscription.currentPeriodEnd;
            if (endAt == null) return false;
            return !endAt.isAfter(DateTime.now());
          },
          orElse: () => false,
        );
        final everSubscribed = isAuthenticated
            ? (prefs.getBool('ever_subscribed:${auth.uid}') ?? false)
            : false;

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
          if (isPreview) {
            return '/dashboard';
          }
          // Redirect from splash to appropriate page
          if (isAuthenticated) {
            if (hasCompletedPreauth && !isPreauthSynced) {
              return '/onboarding?stage=prepare';
            }
            // Always check onboarding first
            if (!hasOnboarded) {
              return '/onboarding?stage=post';
            }
            if (!isSubscriptionChecking &&
                ((requiresPaywall && everSubscribed) ||
                    hasExpiredEntitlement)) {
              return '/paywall?mode=resubscribe';
            }
            return '/dashboard';
          } else {
            if (hasCompletedPreauth) {
              return '/onboarding?stage=save_budget';
            }
            if (hasInProgressPreauthDraft) {
              return '/onboarding?stage=pre';
            }
            return '/onboarding';
          }
        }

        // Allow auth callback to proceed
        if (state.matchedLocation.startsWith('/auth/callback')) {
          return null;
        }

        // Pre-auth onboarding is only for unauthenticated users.
        if (!isAuthenticated && isOnPreOnboardingPage) {
          return null;
        }

        // Prepare onboarding is only for authenticated users.
        if (isAuthenticated && isOnPrepareOnboardingPage) {
          return null;
        }

        // Post-auth onboarding is only allowed while onboarding is still incomplete.
        // Once the flow marks onboarding as complete, force the user onward instead of
        // leaving them on the onboarding route waiting for a widget-level navigation.
        if (isAuthenticated && isOnPostOnboardingPage) {
          if (!hasOnboarded) {
            return null;
          }

          if (kDebugMode) {
            debugPrint(
              '✅ [RouterV2] Post-auth onboarding already completed; redirecting away from ${state.matchedLocation}',
            );
          }

          return '/dashboard';
        }

        if (!isAuthenticated && isOnPrepareOnboardingPage) {
          return '/login';
        }

        if (!isAuthenticated && isOnPostOnboardingPage && !isDebugPostBypass) {
          if (hasCompletedPreauth) return '/login';
          if (hasInProgressPreauthDraft) return '/onboarding?stage=pre';
          return null;
        }

        if (isAuthenticated &&
            hasCompletedPreauth &&
            !isPreauthSynced &&
            !isOnPrepareOnboardingPage &&
            !isOnAuthPage &&
            !isOnSplashPage) {
          return '/onboarding?stage=prepare';
        }

        if (!isPreview &&
            isAuthenticated &&
            isPreauthSynced &&
            !hasOnboarded &&
            !isOnPrepareOnboardingPage &&
            !isOnPostOnboardingPage &&
            !isOnAuthPage &&
            !isOnSplashPage) {
          return '/onboarding?stage=post';
        }

        // Allow paywall page only while the router-facing subscription gate
        // still requires it. If a purchase just activated, leave paywall even
        // if the widget-level navigation did not run.
        if (!kIsWeb && isOnPaywallPage && isAuthenticated) {
          if (!isSubscriptionChecking &&
              !requiresPaywall &&
              !hasExpiredEntitlement) {
            return '/dashboard';
          }
          return null;
        }

        if (!kIsWeb && isOnPlanSelectionPage && isAuthenticated) {
          return null;
        }

        if (!isPreview &&
            !isAuthenticated &&
            !isOnAuthPage &&
            !isOnboardingPage) {
          if (hasCompletedPreauth) {
            return '/onboarding?stage=save_budget';
          }
          if (hasInProgressPreauthDraft) {
            return '/onboarding?stage=pre';
          }
          return '/onboarding';
        }

        // If authenticated and on auth page, check onboarding then subscription then redirect
        if (!isPreview && isAuthenticated && isOnAuthPage) {
          if (hasCompletedPreauth && !isPreauthSynced) {
            return '/onboarding?stage=prepare';
          }
          // Always prioritize onboarding
          if (!hasOnboarded) {
            return '/onboarding?stage=post';
          }
          if (!isSubscriptionChecking &&
              ((requiresPaywall && everSubscribed) || hasExpiredEntitlement)) {
            return '/paywall?mode=resubscribe';
          }
          return '/dashboard';
        }

        if (!isPreview &&
            !kIsWeb &&
            isAuthenticated &&
            isPreauthSynced &&
            hasOnboarded &&
            !isSubscriptionChecking &&
            ((requiresPaywall && everSubscribed) || hasExpiredEntitlement) &&
            !isOnPaywallPage &&
            !isOnPlanSelectionPage &&
            !isOnboardingPage &&
            !isOnPrepareOnboardingPage) {
          return '/paywall?mode=resubscribe';
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

    // Keep routing reactive to subscription/preview changes while app is open.
    _ref.listen<bool>(
      subscriptionGateStatusProvider.select((status) => status.requiresPaywall),
      (_, __) => notifyListeners(),
    );
    _ref.listen<bool>(
      subscriptionGateStatusProvider.select((status) => status.isLoading),
      (_, __) => notifyListeners(),
    );
    _ref.listen<PreviewModeState>(
      previewModeProvider,
      (_, __) => notifyListeners(),
    );
  }
}
