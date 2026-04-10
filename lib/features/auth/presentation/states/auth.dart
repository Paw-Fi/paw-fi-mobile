import 'dart:async';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:moneko/core/services/preferred_language_sync_service.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/core/services/notification_capture_service.dart';

part 'auth.g.dart';

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  late final StreamSubscription<AuthState> _authStateSubscription;
  bool _isLoading = false;

  @override
  AppUser build() {
    initListener();
    final user = AppUser.fromSession(supabase.auth.currentSession);
    unawaited(_syncSiriShortcutAuthContext(supabase.auth.currentSession));
    // Set Crashlytics user identifier for initial state as well
    try {
      final uid = user.uid;
      if (uid.isNotEmpty) {
        FirebaseCrashlytics.instance.setUserIdentifier(uid);
      } else {
        FirebaseCrashlytics.instance.setUserIdentifier('anonymous');
      }
    } catch (_) {}
    return user;
  }

  bool get isLoading => _isLoading;
  bool get isAuthenticated => state.uid.isNotEmpty;

  initListener() {
    _authStateSubscription =
        supabase.auth.onAuthStateChange.listen((data) async {
      state = AppUser.fromSession(data.session);

      final event = data.event;
      final session = data.session;

      unawaited(_syncSiriShortcutAuthContext(session));

      // Set Crashlytics user identifier for better correlation
      try {
        final uid = state.uid;
        if (uid.isNotEmpty) {
          await FirebaseCrashlytics.instance.setUserIdentifier(uid);
        } else {
          await FirebaseCrashlytics.instance.setUserIdentifier('anonymous');
        }
      } catch (_) {}

      // Ensure device is registered for push notifications whenever we have
      // an authenticated session (initial load or explicit sign-in).
      if (session != null &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession)) {
        try {
          await ref.read(deviceRegistrationServiceProvider).initialize();
        } catch (e, st) {
          appLog('Device registration init failed: $e',
              name: 'Auth', error: e, stackTrace: st);
        }

        unawaited(
          ref.read(preferredLanguageSyncServiceProvider).syncForUserSafely(
                userId: session.user.id,
              ),
        );
      }

      // On sign in, migrate guest data and sync Web3 profile (wallet address/name)
      if (event == AuthChangeEvent.signedIn && session != null) {
        try {
          await _syncWeb3Profile(session);
        } catch (e, st) {
          appLog('Web3 profile sync failed: $e',
              name: 'Auth', error: e, stackTrace: st);
        }
      }
    }, onError: (error) {
      // Handle auth stream errors gracefully
      appLog('Auth state change error: $error', name: 'Auth', error: error);
      if (_isRefreshTokenNotFound(error)) {
        appLog('Auth session expired, clearing local session', name: 'Auth');
        unawaited(SiriShortcutAuthService.instance.clearAuthContext());
        unawaited(NotificationCaptureService.instance.clearAuthContext());
        unawaited(supabase.auth.signOut());
        return;
      }
      if (_isFlowStateNotFound(error)) {
        return;
      }
      if (!_isNetworkError(error)) {
        try {
          FirebaseCrashlytics.instance.recordError(error, null, fatal: false);
        } catch (_) {}
      }
    });
  }

  Future<void> _syncSiriShortcutAuthContext(Session? session) async {
    try {
      if (Constants.supabaseUrl.isEmpty || Constants.supabaseAnon.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      if (Constants.supabaseUrl.isEmpty || Constants.supabaseAnon.isEmpty) {
        return;
      }

      if (session == null) {
        await SiriShortcutAuthService.instance.clearAuthContext();
        if (Platform.isAndroid) {
          await NotificationCaptureService.instance.clearAuthContext();
        }
        return;
      }

      // iOS: Siri Shortcuts auth context
      await SiriShortcutAuthService.instance.syncAuthContext(
        supabaseUrl: Constants.supabaseUrl,
        supabaseAnonKey: Constants.supabaseAnon,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        userId: session.user.id,
        expiresAt: session.expiresAt,
      );

      // Android: Notification capture auth context
      if (Platform.isAndroid) {
        await NotificationCaptureService.instance.syncAuthContext(
          supabaseUrl: Constants.supabaseUrl,
          supabaseAnonKey: Constants.supabaseAnon,
          accessToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
          userId: session.user.id,
          expiresAt: session.expiresAt ?? 0,
        );
      }
    } on MissingPluginException {
      return;
    } catch (error) {
      appLog(
        'Failed to sync Siri shortcut auth context: $error',
        name: 'Auth',
        error: error,
      );
    }
  }

  bool _isRefreshTokenNotFound(Object error) {
    if (error is AuthApiException) {
      return error.code?.toLowerCase() == 'refresh_token_not_found';
    }
    final message = error.toString().toLowerCase();
    return message.contains('refresh_token_not_found') ||
        message.contains('refresh token not found');
  }

  bool _isFlowStateNotFound(Object error) {
    if (error is AuthApiException) {
      return error.code?.toLowerCase() == 'flow_state_not_found';
    }
    final message = error.toString().toLowerCase();
    return message.contains('flow_state_not_found');
  }

  bool _isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('connection reset') ||
        message.contains('connection terminated') ||
        message.contains('handshakeexception') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('clientexception');
  }

  /// Ensure Web3 logins set a reasonable display name and persist
  /// wallet address to public.users. Safe no-op for non-Web3 accounts.
  Future<void> _syncWeb3Profile(Session session) async {
    try {
      final user = session.user;
      String? walletAddress;
      String? chain;

      // Extract from identities when available
      try {
        final identities = (user.identities as List?) ?? const [];
        for (final id in identities) {
          final idDyn = id as dynamic;
          final provider = (idDyn.provider ?? idDyn['provider'])?.toString();
          if (provider == 'web3' ||
              provider == 'ethereum' ||
              provider == 'solana') {
            final data = (idDyn.identityData ?? idDyn['identity_data']) as Map?;
            walletAddress = (data?['wallet_address'] ??
                    data?['address'] ??
                    data?['publicKey'])
                ?.toString();
            chain = (data?['chain'] ?? data?['network'])?.toString();
            if (walletAddress != null && walletAddress.isNotEmpty) break;
          }
        }
      } catch (_) {}

      // Fallback: user metadata (if JS flow saved it)
      walletAddress ??= user.userMetadata?['wallet_address']?.toString();
      chain ??= user.userMetadata?['chain']?.toString();

      if (walletAddress == null || walletAddress.isEmpty) {
        return; // Not a Web3 login
      }

      // If no name set, use wallet address as display name
      final hasName = (user.userMetadata?['full_name']
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true) ||
          (user.userMetadata?['name']?.toString().trim().isNotEmpty == true);
      if (!hasName) {
        try {
          await supabase.auth.updateUser(
            UserAttributes(data: {
              'full_name': walletAddress,
              'name': walletAddress,
              'wallet_address': walletAddress,
              if (chain != null) 'chain': chain,
            }),
          );
        } catch (_) {}
      }

      // Upsert users row with wallet address
      try {
        await supabase.from('users').upsert({
          'id': user.id,
          'full_name': walletAddress,
          'wallet_address': walletAddress,
          if (chain != null) 'chain': chain,
        }, onConflict: 'id');
      } catch (_) {}
    } catch (_) {}
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    _isLoading = true;

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (error, stackTrace) {
      appLog('Sign in error: ${error.message}',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected sign in error',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Sign up with email, password, and user metadata
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? redirectUrl,
  }) async {
    _isLoading = true;

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
        emailRedirectTo: redirectUrl,
      );
      return response;
    } on AuthException catch (error, stackTrace) {
      appLog('Sign up error: ${error.message}',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected sign up error',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Verify OTP code
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    _isLoading = true;

    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      return response;
    } on AuthException catch (error, stackTrace) {
      appLog('OTP verification error: ${error.message}',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected OTP verification error',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Resend verification email
  Future<void> resendVerification(String email) async {
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } on AuthException catch (error, stackTrace) {
      appLog('Resend verification error: ${error.message}',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected resend error',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email, {String? redirectUrl}) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
    } on AuthException catch (error, stackTrace) {
      appLog('Reset password error: ${error.message}',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected reset password error',
          name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;

    try {
      // Ensure device is unregistered on backend before auth session is cleared
      try {
        await ref.read(deviceRegistrationServiceProvider).unregisterDevice();
      } catch (_) {}

      await supabase.auth.signOut();
      await SiriShortcutAuthService.instance.clearAuthContext();
      await NotificationCaptureService.instance.clearAuthContext();
    } on AuthException catch (error, stackTrace) {
      appLog('Sign out error: ${error.message}',
          name: 'Auth', error: error, stackTrace: stackTrace);

      // Handle specific refresh token errors
      if (error.message.contains('Refresh Token Not Found') ||
          error.message.contains('Invalid Refresh Token')) {
        // Token is already invalid, clear local state and proceed with logout
        appLog('Refresh token already invalid, proceeding with logout',
            name: 'Auth');
        await SiriShortcutAuthService.instance.clearAuthContext();
        await NotificationCaptureService.instance.clearAuthContext();
        return; // Don't rethrow, allow logout to complete
      }

      rethrow;
    } on SocketException catch (error, stackTrace) {
      appLog('Network error during sign out: $error',
          name: 'Auth', error: error, stackTrace: stackTrace);
      // For network errors during logout, still try to clear local state
      try {
        await SiriShortcutAuthService.instance.clearAuthContext();
        await NotificationCaptureService.instance.clearAuthContext();
        state = const AppUser(
            uid: '', email: '', displayName: null, photoUrl: null);
      } catch (_) {}
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected sign out error',
          name: 'Auth', error: error, stackTrace: stackTrace);
      // Clear local state even if sign out fails
      try {
        state = const AppUser(
            uid: '', email: '', displayName: null, photoUrl: null);
      } catch (_) {}
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  dispose() {
    _authStateSubscription.cancel();
  }
}

final authAccessTokenProvider = Provider<String?>((ref) {
  ref.watch(authProvider);
  return supabase.auth.currentSession?.accessToken;
});

final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider);
  final uid = user.uid.trim();
  return uid.isEmpty ? null : uid;
});

/// Format Supabase auth errors into concise, user-facing messages.
///
/// - For [AuthException], this returns [AuthException.message] directly.
/// - For any other error type, this falls back to a cleaned string without
///   Dart exception class prefixes.
String formatAuthErrorMessage(Object error) {
  if (error is AuthException) {
    return error.message;
  }

  final raw = error.toString();
  return raw
      .replaceAll('Exception: ', '')
      .replaceAll('AuthException: ', '')
      .replaceAll('AuthApiException: ', '');
}
