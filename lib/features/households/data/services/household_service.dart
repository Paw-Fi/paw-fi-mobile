import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_summary.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/shared_budget.dart';

/// Supabase service for household operations
class HouseholdService {
  final SupabaseClient _supabase;

  HouseholdService(this._supabase);

  // ============================================================================
  // HOUSEHOLDS
  // ============================================================================

  Future<List<Map<String, dynamic>>> getUserHouseholds(String userId) async {
    final response = await _supabase
        .from('household_members')
        .select('household_id, households(*)')
        .eq('user_id', userId);

    return (response as List).map((item) {
      return item['households'] as Map<String, dynamic>;
    }).toList();
  }

  Future<Map<String, dynamic>?> getHousehold(String householdId) async {
    final response = await _supabase
        .from('households')
        .select()
        .eq('id', householdId)
        .maybeSingle();

    return response;
  }

  Future<Map<String, dynamic>> createHousehold({
    required String name,
    String? emoji,
    String? themeColor,
  }) async {
    final response = await _supabase.from('households').insert({
      'name': name,
      'emoji': emoji,
      'theme_color': themeColor,
      'owner_id': _supabase.auth.currentUser!.id,
    }).select().single();

    return response;
  }

  Future<Map<String, dynamic>> updateHousehold({
    required String householdId,
    String? name,
    String? emoji,
    String? themeColor,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (emoji != null) updates['emoji'] = emoji;
    if (themeColor != null) updates['theme_color'] = themeColor;

    final response = await _supabase
        .from('households')
        .update(updates)
        .eq('id', householdId)
        .select()
        .single();

    return response;
  }

  Future<void> deleteHousehold(String householdId) async {
    await _supabase.from('households').delete().eq('id', householdId);
  }

  // ============================================================================
  // MEMBERS
  // ============================================================================

  Future<List<Map<String, dynamic>>> getHouseholdMembers(
      String householdId) async {
    final response = await _supabase
        .from('household_members')
        .select()
        .eq('household_id', householdId);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> removeMember(String memberId) async {
    await _supabase.from('household_members').delete().eq('id', memberId);
  }

  Future<void> updateMemberRole(String memberId, String role) async {
    await _supabase
        .from('household_members')
        .update({'role': role}).eq('id', memberId);
  }

  Future<void> leaveHousehold(String householdId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('household_members')
        .delete()
        .eq('household_id', householdId)
        .eq('user_id', userId);
  }

  // ============================================================================
  // INVITES (via Edge Functions)
  // ============================================================================

  Future<List<Map<String, dynamic>>> getHouseholdInvites(
      String householdId) async {
    final response = await _supabase
        .from('invites')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<String> createInvite({
    required String householdId,
    String? invitedEmail,
    String? personalMessage,
    int expiresInDays = 7,
  }) async {
    final response = await _supabase.functions.invoke(
      'households-create-invite',
      body: {
        'household_id': householdId,
        'invited_email': invitedEmail,
        'personal_message': personalMessage,
        'expires_in_days': expiresInDays,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to create invite: ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    return data['invite_url'] as String;
  }

  Future<Map<String, dynamic>> validateInvite(String token) async {
    final response = await _supabase.functions.invoke(
      'households-validate-invite',
      body: {'token': token},
    );

    if (response.status != 200) {
      throw Exception('Failed to validate invite: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptInvite(String token) async {
    final response = await _supabase.functions.invoke(
      'households-accept-invite',
      body: {'token': token},
    );

    if (response.status != 200) {
      throw Exception('Failed to accept invite: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  Future<void> revokeInvite({String? inviteId, String? token}) async {
    final response = await _supabase.functions.invoke(
      'households-revoke-invite',
      body: {
        if (inviteId != null) 'invite_id': inviteId,
        if (token != null) 'token': token,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to revoke invite: ${response.data}');
    }
  }

  // ============================================================================
  // SPLITS (via Edge Functions)
  // ============================================================================

  Future<List<Map<String, dynamic>>> getHouseholdSplits({
    required String householdId,
    String? startDate,
    String? endDate,
  }) async {
    var query = _supabase
        .from('expense_split_groups')
        .select('*, expense_split_lines(*)')
        .eq('household_id', householdId);

    if (startDate != null) {
      query = query.gte('created_at', startDate);
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> computeSplit(
      Map<String, dynamic> request) async {
    final response = await _supabase.functions.invoke(
      'households-compute-splits',
      body: request,
    );

    if (response.status != 200) {
      throw Exception('Failed to compute split: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  Future<void> settleSplit(String splitLineId) async {
    await _supabase.from('expense_split_lines').update({
      'is_settled': true,
      'settled_at': DateTime.now().toIso8601String(),
    }).eq('id', splitLineId);
  }

  // ============================================================================
  // BUDGETS
  // ============================================================================

  Future<List<Map<String, dynamic>>> getHouseholdBudgets(
      String householdId) async {
    final response = await _supabase
        .from('shared_budgets')
        .select()
        .eq('household_id', householdId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createBudget({
    required String householdId,
    required String name,
    required String period,
    required String currency,
    required int amountCents,
    double? warnThreshold,
    double? alertThreshold,
  }) async {
    final response = await _supabase.from('shared_budgets').insert({
      'household_id': householdId,
      'name': name,
      'period': period,
      'currency': currency,
      'amount_cents': amountCents,
      'warn_threshold': warnThreshold ?? 0.8,
      'alert_threshold': alertThreshold ?? 1.0,
    }).select().single();

    return response;
  }

  Future<Map<String, dynamic>> updateBudget({
    required String budgetId,
    String? name,
    int? amountCents,
    double? warnThreshold,
    double? alertThreshold,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (amountCents != null) updates['amount_cents'] = amountCents;
    if (warnThreshold != null) updates['warn_threshold'] = warnThreshold;
    if (alertThreshold != null) updates['alert_threshold'] = alertThreshold;
    if (isActive != null) updates['is_active'] = isActive;

    final response = await _supabase
        .from('shared_budgets')
        .update(updates)
        .eq('id', budgetId)
        .select()
        .single();

    return response;
  }

  Future<void> deleteBudget(String budgetId) async {
    await _supabase.from('shared_budgets').delete().eq('id', budgetId);
  }

  // ============================================================================
  // SHARING PREFERENCES
  // ============================================================================

  Future<Map<String, dynamic>?> getSharingPreferences({
    required String userId,
    required String householdId,
  }) async {
    final response = await _supabase
        .from('sharing_prefs')
        .select()
        .eq('user_id', userId)
        .eq('household_id', householdId)
        .maybeSingle();

    return response;
  }

  Future<Map<String, dynamic>> upsertSharingPreferences({
    required String userId,
    required String householdId,
    String? defaultTransactionShareScope,
    String? defaultAccountShareScope,
    Map<String, String>? perCategoryOverrides,
    bool? enableNudges,
    String? nudgeQuietHoursStart,
    String? nudgeQuietHoursEnd,
  }) async {
    final updates = <String, dynamic>{
      'user_id': userId,
      'household_id': householdId,
    };

    if (defaultTransactionShareScope != null) {
      updates['default_transaction_share_scope'] =
          defaultTransactionShareScope;
    }
    if (defaultAccountShareScope != null) {
      updates['default_account_share_scope'] = defaultAccountShareScope;
    }
    if (perCategoryOverrides != null) {
      updates['per_category_overrides'] = perCategoryOverrides;
    }
    if (enableNudges != null) updates['enable_nudges'] = enableNudges;
    if (nudgeQuietHoursStart != null) {
      updates['nudge_quiet_hours_start'] = nudgeQuietHoursStart;
    }
    if (nudgeQuietHoursEnd != null) {
      updates['nudge_quiet_hours_end'] = nudgeQuietHoursEnd;
    }

    final response = await _supabase.from('sharing_prefs').upsert(updates).select().single();

    return response;
  }

  // ============================================================================
  // SUMMARY (via Edge Function)
  // ============================================================================

  Future<Map<String, dynamic>> getHouseholdSummary({
    required String householdId,
    required String currency,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _supabase.functions.invoke(
      'households-summary',
      body: {
        'household_id': householdId,
        'currency': currency,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to get household summary: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  // ============================================================================
  // REALTIME SUBSCRIPTIONS
  // ============================================================================

  Stream<List<Map<String, dynamic>>> watchHouseholdMembers(
      String householdId) {
    return _supabase
        .from('household_members')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((data) => data.cast<Map<String, dynamic>>());
  }

  Stream<List<Map<String, dynamic>>> watchHouseholdInvites(
      String householdId) {
    return _supabase
        .from('invites')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((data) => data.cast<Map<String, dynamic>>());
  }

  Stream<List<Map<String, dynamic>>> watchHouseholdBudgets(
      String householdId) {
    return _supabase
        .from('shared_budgets')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((data) => data.cast<Map<String, dynamic>>());
  }
}
