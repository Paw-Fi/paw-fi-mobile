import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing guest goals and migrating them on login
/// Mirrors web's cookie-based guest goal management
class GuestGoalService {
  static const String _guestGoalsKey = 'moneko-guest-goals';
  static const String _guestProfilesKey = 'moneko-guest-profiles';

  final SharedPreferences _prefs;
  final SupabaseClient _supabase;

  GuestGoalService(this._prefs, this._supabase);

  // ============================================================================
  // Guest Goals Management
  // ============================================================================

  /// Get list of guest goal IDs stored locally
  Future<List<String>> getGuestGoalIds() async {
    final goalIdsJson = _prefs.getString(_guestGoalsKey);
    if (goalIdsJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(goalIdsJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print('Error parsing guest goal IDs: $e');
      return [];
    }
  }

  /// Add a goal ID to guest goals list
  Future<void> addGuestGoalId(String goalId) async {
    final existingGoalIds = await getGuestGoalIds();

    // Avoid duplicates
    if (existingGoalIds.contains(goalId)) {
      return;
    }

    final updatedGoalIds = [...existingGoalIds, goalId];
    await _prefs.setString(_guestGoalsKey, jsonEncode(updatedGoalIds));

    print('Added guest goal ID: $goalId');
    print('Total guest goals: ${updatedGoalIds.length}');
  }

  /// Clear all guest goal IDs (called after successful migration)
  Future<void> clearGuestGoalIds() async {
    await _prefs.remove(_guestGoalsKey);
    print('Cleared all guest goal IDs');
  }

  // ============================================================================
  // Guest Profiles Management
  // ============================================================================

  /// Get list of guest financial profile IDs stored locally
  Future<List<String>> getGuestProfileIds() async {
    final profileIdsJson = _prefs.getString(_guestProfilesKey);
    if (profileIdsJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(profileIdsJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print('Error parsing guest profile IDs: $e');
      return [];
    }
  }

  /// Add a profile ID to guest profiles list
  Future<void> addGuestProfileId(String profileId) async {
    final existingProfileIds = await getGuestProfileIds();

    // Avoid duplicates
    if (existingProfileIds.contains(profileId)) {
      return;
    }

    final updatedProfileIds = [...existingProfileIds, profileId];
    await _prefs.setString(_guestProfilesKey, jsonEncode(updatedProfileIds));

    print('Added guest profile ID: $profileId');
    print('Total guest profiles: ${updatedProfileIds.length}');
  }

  /// Clear all guest profile IDs (called after successful migration)
  Future<void> clearGuestProfileIds() async {
    await _prefs.remove(_guestProfilesKey);
    print('Cleared all guest profile IDs');
  }

  // ============================================================================
  // Migration Logic (called after login)
  // ============================================================================

  /// Migrate all guest goals to authenticated user
  /// This matches the web's migration logic exactly
  Future<MigrationResult> migrateGuestGoals(String userId) async {
    final guestGoalIds = await getGuestGoalIds();
    final guestProfileIds = await getGuestProfileIds();

    if (guestGoalIds.isEmpty && guestProfileIds.isEmpty) {
      print('No guest data to migrate');
      return MigrationResult(
        success: true,
        migratedGoals: 0,
        migratedProfiles: 0,
      );
    }

    print('Starting migration for user $userId');
    print('Guest goals to migrate: ${guestGoalIds.length}');
    print('Guest profiles to migrate: ${guestProfileIds.length}');

    int migratedGoals = 0;
    int migratedProfiles = 0;
    final List<String> errors = [];

    // Migrate goals
    for (final goalId in guestGoalIds) {
      try {
        // Update goal's user_id in database
        final response = await _supabase
            .from('goals')
            .update({'user_id': userId})
            .eq('id', goalId)
            .select();

        if (response.isNotEmpty) {
          migratedGoals++;
          print('Successfully migrated goal: $goalId');

          // Log the migration activity
          await _logMigrationActivity(userId, goalId, 'goal');
        } else {
          print('Goal not found or already migrated: $goalId');
        }
      } catch (e) {
        print('Error migrating goal $goalId: $e');
        errors.add('Goal $goalId: ${e.toString()}');
      }
    }

    // Migrate financial profiles
    for (final profileId in guestProfileIds) {
      try {
        // Update profile's user_id in database
        final response = await _supabase
            .from('financial_health_profiles')
            .update({'user_id': userId})
            .eq('id', profileId)
            .select();

        if (response.isNotEmpty) {
          migratedProfiles++;
          print('Successfully migrated profile: $profileId');

          // Log the migration activity
          await _logMigrationActivity(userId, profileId, 'profile');
        } else {
          print('Profile not found or already migrated: $profileId');
        }
      } catch (e) {
        print('Error migrating profile $profileId: $e');
        errors.add('Profile $profileId: ${e.toString()}');
      }
    }

    // Clear local storage after successful migration
    if (migratedGoals > 0) {
      await clearGuestGoalIds();
    }
    if (migratedProfiles > 0) {
      await clearGuestProfileIds();
    }

    final result = MigrationResult(
      success: errors.isEmpty,
      migratedGoals: migratedGoals,
      migratedProfiles: migratedProfiles,
      errors: errors.isEmpty ? null : errors,
    );

    print('Migration completed: $migratedGoals goals, $migratedProfiles profiles');
    if (errors.isNotEmpty) {
      print('Migration errors: ${errors.join(', ')}');
    }

    return result;
  }

  /// Log migration activity using activity logger
  /// Matches web's activity logging pattern
  Future<void> _logMigrationActivity(
    String userId,
    String itemId,
    String itemType,
  ) async {
    try {
      await _supabase.from('activity_logs').insert({
        'user_id': userId,
        'action': 'migrated_guest_$itemType',
        'resource_type': itemType,
        'resource_id': itemId,
        'metadata': {
          'migrated_at': DateTime.now().toIso8601String(),
          'source': 'mobile_app',
        },
      });
    } catch (e) {
      print('Error logging migration activity: $e');
      // Don't fail migration if logging fails
    }
  }

  /// Check if there are any guest items to migrate
  Future<bool> hasGuestDataToMigrate() async {
    final goalIds = await getGuestGoalIds();
    final profileIds = await getGuestProfileIds();
    return goalIds.isNotEmpty || profileIds.isNotEmpty;
  }
}

/// Result of guest data migration
class MigrationResult {
  final bool success;
  final int migratedGoals;
  final int migratedProfiles;
  final List<String>? errors;

  MigrationResult({
    required this.success,
    required this.migratedGoals,
    required this.migratedProfiles,
    this.errors,
  });

  @override
  String toString() {
    return 'MigrationResult(success: $success, goals: $migratedGoals, profiles: $migratedProfiles, errors: ${errors?.length ?? 0})';
  }
}
