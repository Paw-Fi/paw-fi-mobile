import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/onboarding/data/services/guest_goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

part 'auth.g.dart';

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  late final StreamSubscription<AuthState> _authStateSubscription;
  bool _isLoading = false;

  @override
  AppUser build() {
    initListener();
    final user = AppUser.fromSession(supabase.auth.currentSession);
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
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      state = AppUser.fromSession(data.session);

      // Set Crashlytics user identifier for better correlation
      try {
        final uid = state.uid;
        if (uid.isNotEmpty) {
          await FirebaseCrashlytics.instance.setUserIdentifier(uid);
        } else {
          await FirebaseCrashlytics.instance.setUserIdentifier('anonymous');
        }
      } catch (_) {}

      // On sign in, migrate guest data and sync Web3 profile (wallet address/name)
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _migrateGuestData(data.session!.user.id);
        try {
          await _syncWeb3Profile(data.session!);
        } catch (e, st) {
          appLog('Web3 profile sync failed: $e', name: 'Auth', error: e, stackTrace: st);
        }
      }
    }, onError: (error) {
      // Handle auth stream errors gracefully
      appLog('Auth state change error: $error', name: 'Auth', error: error);
      try {
        FirebaseCrashlytics.instance.recordError(error, null, fatal: false);
      } catch (_) {}
    });
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
          if (provider == 'web3' || provider == 'ethereum' || provider == 'solana') {
            final data = (idDyn.identityData ?? idDyn['identity_data']) as Map?;
            walletAddress = (data?['wallet_address'] ?? data?['address'] ?? data?['publicKey'])?.toString();
            chain = (data?['chain'] ?? data?['network'])?.toString();
            if (walletAddress != null && walletAddress!.isNotEmpty) break;
          }
        }
      } catch (_) {}

      // Fallback: user metadata (if JS flow saved it)
      walletAddress ??= user.userMetadata?['wallet_address']?.toString();
      chain ??= user.userMetadata?['chain']?.toString();

      if (walletAddress == null || walletAddress.isEmpty) return; // Not a Web3 login

      // If no name set, use wallet address as display name
      final hasName = (user.userMetadata?['full_name']?.toString().trim().isNotEmpty == true) ||
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

  /// Migrate guest goals and profiles to authenticated user
  /// This matches the web's migration logic exactly
  Future<void> _migrateGuestData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guestGoalService = GuestGoalService(prefs, supabase);

      // Check if there's any guest data to migrate
      final hasGuestData = await guestGoalService.hasGuestDataToMigrate();

      if (!hasGuestData) {
        appLog('No guest data to migrate for user $userId', name: 'Auth');
        return;
      }

      appLog('Migrating guest data for user $userId...', name: 'Auth');

      // Perform migration
      final result = await guestGoalService.migrateGuestGoals(userId);

      if (result.success) {
        appLog(
          'Successfully migrated guest data: ${result.migratedGoals} goals, ${result.migratedProfiles} profiles',
          name: 'Auth',
        );
      } else {
        appLog('Guest data migration completed with errors: ${result.errors}', name: 'Auth');
      }
    } catch (error, stackTrace) {
      appLog('Error during guest data migration', name: 'Auth', error: error, stackTrace: stackTrace);
      // Don't fail login if migration fails
    }
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
      appLog('Sign in error: ${error.message}', name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected sign in error', name: 'Auth', error: error, stackTrace: stackTrace);
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
      appLog('Sign up error: ${error.message}', name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected sign up error', name: 'Auth', error: error, stackTrace: stackTrace);
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
      appLog('OTP verification error: ${error.message}', name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected OTP verification error', name: 'Auth', error: error, stackTrace: stackTrace);
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
      appLog('Resend verification error: ${error.message}', name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected resend error', name: 'Auth', error: error, stackTrace: stackTrace);
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
      appLog('Reset password error: ${error.message}', name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected reset password error', name: 'Auth', error: error, stackTrace: stackTrace);
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
    } on AuthException catch (error, stackTrace) {
      appLog('Sign out error: ${error.message}', name: 'Auth', error: error, stackTrace: stackTrace);
      
      // Handle specific refresh token errors
      if (error.message.contains('Refresh Token Not Found') || 
          error.message.contains('Invalid Refresh Token')) {
        // Token is already invalid, clear local state and proceed with logout
        appLog('Refresh token already invalid, proceeding with logout', name: 'Auth');
        return; // Don't rethrow, allow logout to complete
      }
      
      rethrow;
    } on SocketException catch (error, stackTrace) {
      appLog('Network error during sign out: $error', name: 'Auth', error: error, stackTrace: stackTrace);
      // For network errors during logout, still try to clear local state
      try {
        state = const AppUser(uid: '', email: '', displayName: null, photoUrl: null);
      } catch (_) {}
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected sign out error', name: 'Auth', error: error, stackTrace: stackTrace);
      // Clear local state even if sign out fails
      try {
        state = const AppUser(uid: '', email: '', displayName: null, photoUrl: null);
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
