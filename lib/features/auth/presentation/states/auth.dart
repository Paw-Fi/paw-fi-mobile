import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rsupa/core/core.dart';
import 'package:rsupa/features/auth/auth.dart';
import 'package:rsupa/features/onboarding/data/services/guest_goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth.g.dart';

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  late final StreamSubscription<AuthState> _authStateSubscription;
  bool _isLoading = false;

  @override
  AppUser build() {
    initListener();

    return supabase.auth.currentSession == null
        ? AppUser.empty
        : AppUser.fromSession(supabase.auth.currentSession!);
  }

  bool get isLoading => _isLoading;
  bool get isAuthenticated => state.uid.isNotEmpty;

  initListener() {
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      state = AppUser.fromSession(data.session);

      // Update last login and migrate guest data on sign in
      if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
        _updateLastLogin(data.session!.user.id);
        _migrateGuestData(data.session!.user.id);
      }
    });
  }

  Future<void> _updateLastLogin(String userId) async {
    try {
      await supabase
          .from('users')
          .update({'last_login': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (error) {
      print('Error updating last login: $error');
    }
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
        print('No guest data to migrate for user $userId');
        return;
      }

      print('Migrating guest data for user $userId...');

      // Perform migration
      final result = await guestGoalService.migrateGuestGoals(userId);

      if (result.success) {
        print('Successfully migrated guest data: ${result.migratedGoals} goals, ${result.migratedProfiles} profiles');
      } else {
        print('Guest data migration completed with errors: ${result.errors}');
      }
    } catch (error) {
      print('Error during guest data migration: $error');
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
    } on AuthException catch (error) {
      print('Sign in error: ${error.message}');
      rethrow;
    } catch (error) {
      print('Unexpected sign in error: $error');
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
    } on AuthException catch (error) {
      print('Sign up error: ${error.message}');
      rethrow;
    } catch (error) {
      print('Unexpected sign up error: $error');
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
    } on AuthException catch (error) {
      print('OTP verification error: ${error.message}');
      rethrow;
    } catch (error) {
      print('Unexpected OTP verification error: $error');
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
    } on AuthException catch (error) {
      print('Resend verification error: ${error.message}');
      rethrow;
    } catch (error) {
      print('Unexpected resend error: $error');
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
    } on AuthException catch (error) {
      print('Reset password error: ${error.message}');
      rethrow;
    } catch (error) {
      print('Unexpected reset password error: $error');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;

    try {
      await supabase.auth.signOut();
    } on AuthException catch (error) {
      print('Sign out error: ${error.message}');
      rethrow;
    } catch (error) {
      print('Unexpected sign out error: $error');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  dispose() {
    _authStateSubscription.cancel();
  }
}
