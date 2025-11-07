import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/onboarding/data/services/guest_goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

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

      // Migrate guest data on sign in
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _migrateGuestData(data.session!.user.id);
      }
    });
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
      await supabase.auth.signOut();
    } on AuthException catch (error, stackTrace) {
      appLog('Sign out error: ${error.message}', name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      appLog('Unexpected sign out error', name: 'Auth', error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  dispose() {
    _authStateSubscription.cancel();
  }
}
