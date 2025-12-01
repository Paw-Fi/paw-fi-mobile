import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_config.dart';

class DashboardRepository {
  static const String _kPersonalLayoutKey = 'personal_dashboard_layout';
  static const String _kHouseholdLayoutKeyPrefix =
      'household_dashboard_layout_';

  final SharedPreferences _prefs;
  final SupabaseClient _supabase;

  DashboardRepository(this._prefs, this._supabase);

  // ==========================================================================
  // PERSONAL DASHBOARD
  // ==========================================================================

  Future<List<DashboardWidgetConfig>?> loadPersonalLayout(String userId) async {
    try {
      // 1. Try Local Storage first for speed
      final localJson = _prefs.getString('$_kPersonalLayoutKey$userId');
      if (localJson != null) {
        final List<dynamic> decoded = jsonDecode(localJson);
        return decoded.map((e) => DashboardWidgetConfig.fromJson(e)).toList();
      }

      // 2. Try Remote (Supabase) if local is empty
      // Assuming 'home_layout' column exists in 'users' table
      final response = await _supabase
          .from('users')
          .select('home_layout')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['home_layout'] != null) {
        final List<dynamic> remoteList = response['home_layout'];
        final configs =
            remoteList.map((e) => DashboardWidgetConfig.fromJson(e)).toList();

        // Cache locally
        await _saveLocalPersonal(userId, configs);
        return configs;
      }
    } catch (e) {
      debugPrint('Error loading personal layout: $e');
    }
    return null;
  }

  Future<void> savePersonalLayout(
      String userId, List<DashboardWidgetConfig> configs) async {
    // 1. Save Local
    await _saveLocalPersonal(userId, configs);

    // 2. Save Remote
    try {
      final jsonList = configs.map((e) => e.toJson()).toList();
      await _supabase.from('users').update({
        'home_layout': jsonList,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Error saving personal layout to Supabase: $e');
      // Non-blocking error, we rely on local storage
    }
  }

  Future<void> _saveLocalPersonal(
      String userId, List<DashboardWidgetConfig> configs) async {
    final jsonList = configs.map((e) => e.toJson()).toList();
    await _prefs.setString('$_kPersonalLayoutKey$userId', jsonEncode(jsonList));
  }

  // ==========================================================================
  // HOUSEHOLD DASHBOARD
  // ==========================================================================

  Future<List<DashboardWidgetConfig>?> loadHouseholdLayout(
      String householdId) async {
    try {
      // 1. Try Local Storage
      final localJson =
          _prefs.getString('$_kHouseholdLayoutKeyPrefix$householdId');
      if (localJson != null) {
        final List<dynamic> decoded = jsonDecode(localJson);
        return decoded.map((e) => DashboardWidgetConfig.fromJson(e)).toList();
      }

      // 2. Try Remote
      // Assuming 'dashboard_layout' column exists in 'households' table
      final response = await _supabase
          .from('households')
          .select('dashboard_layout')
          .eq('id', householdId)
          .maybeSingle();

      if (response != null && response['dashboard_layout'] != null) {
        final List<dynamic> remoteList = response['dashboard_layout'];
        final configs =
            remoteList.map((e) => DashboardWidgetConfig.fromJson(e)).toList();

        // Cache locally
        await _saveLocalHousehold(householdId, configs);
        return configs;
      }
    } catch (e) {
      debugPrint('Error loading household layout: $e');
    }
    return null;
  }

  Future<void> saveHouseholdLayout(
      String householdId, List<DashboardWidgetConfig> configs) async {
    // 1. Save Local
    await _saveLocalHousehold(householdId, configs);

    // 2. Save Remote
    try {
      final jsonList = configs.map((e) => e.toJson()).toList();
      await _supabase.from('households').update({
        'dashboard_layout': jsonList,
      }).eq('id', householdId);
    } catch (e) {
      debugPrint('Error saving household layout to Supabase: $e');
    }
  }

  Future<void> _saveLocalHousehold(
      String householdId, List<DashboardWidgetConfig> configs) async {
    final jsonList = configs.map((e) => e.toJson()).toList();
    await _prefs.setString(
        '$_kHouseholdLayoutKeyPrefix$householdId', jsonEncode(jsonList));
  }
}
