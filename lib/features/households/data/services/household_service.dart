import 'package:moneko/core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Supabase service for household operations
class HouseholdService {
  final SupabaseClient _supabase;

  HouseholdService(this._supabase);

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    appLog(message,
        name: 'HouseholdService', error: error, stackTrace: stackTrace);
  }

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
    required String currency,
    String? coverImageUrl,
    String? themeColor,
    bool isPortfolio = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      _log('Creating household', error: {
        'name': name,
        'currency': currency.toUpperCase(),
        'coverImageUrl': coverImageUrl,
        'themeColor': themeColor,
        'isPortfolio': isPortfolio,
        'ownerId': userId,
      });

      final response = await _supabase
          .from('households')
          .insert({
            'name': name,
            'currency': currency.toUpperCase(),
            'cover_image_url': coverImageUrl,
            'theme_color': themeColor,
            'is_portfolio': isPortfolio,
            'owner_id': userId,
          })
          .select()
          .single();

      _log('Household created successfully: ${response['id']}');
      return response;
    } catch (e, stackTrace) {
      _log('Error creating household', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateHousehold({
    required String householdId,
    String? name,
    String? coverImageUrl,
    String? themeColor,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
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
    // Fetch household members rows
    final members = await _supabase
        .from('household_members')
        .select('*')
        .eq('household_id', householdId);

    final membersList = (members as List).cast<Map<String, dynamic>>();
    if (membersList.isEmpty) return membersList;

    // Collect user IDs then fetch users separately (avoids relationship/permission pitfalls)
    final userIds = membersList.map((m) => m['user_id'] as String).toList();
    final usersData = await _supabase
        .from('users')
        .select('id, email, full_name, avatar_url')
        .inFilter('id', userIds);

    final usersMap = <String, Map<String, dynamic>>{};
    for (var user in (usersData as List).cast<Map<String, dynamic>>()) {
      // Normalize like Profile page: prefer full_name, fallback to email local-part
      String? displayName = (user['full_name'] as String?)?.trim();
      final email = user['email'] as String?;
      if (displayName == null || displayName.isEmpty) {
        if (email != null && email.isNotEmpty) {
          displayName = email.split('@').first;
        }
      }
      if (displayName != null && displayName.isNotEmpty) {
        user['full_name'] = displayName;
      }
      usersMap[user['id'] as String] = user;
    }

    // Attach user obj under key 'users' for entity parser
    for (var member in membersList) {
      final userId = member['user_id'] as String;
      final user = usersMap[userId];
      if (user != null) {
        member['users'] = user;
      }
    }

    return membersList;
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
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      _log('Calling households-create-invite edge function', error: {
        'householdId': householdId,
        'invitedEmail': invitedEmail,
        'expiresInDays': expiresInDays,
      });

      // Build body with only non-null optional values
      final body = <String, dynamic>{
        'household_id': householdId,
        'expires_in_days': expiresInDays,
      };
      if (invitedEmail != null && invitedEmail.isNotEmpty) {
        body['invited_email'] = invitedEmail;
      }
      if (personalMessage != null && personalMessage.isNotEmpty) {
        body['personal_message'] = personalMessage;
      }

      // Add a timeout so the UI doesn't hang forever if the function stalls
      final response = await _supabase.functions
          .invoke('households-create-invite', body: body)
          .timeout(timeout);

      _log('Edge function response', error: {
        'status': response.status,
        'data': response.data,
      });

      if (response.status != 200) {
        throw Exception('Failed to create invite: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      final inviteUrl = data['invite_url'] as String;
      _log('Invite URL created: $inviteUrl');
      return inviteUrl;
    } catch (e, stackTrace) {
      _log('Error creating invite', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateInvite(String token) async {
    try {
      final response = await _supabase.functions.invoke(
        'households-validate-invite',
        body: {'token': token},
      );

      final data = (response.data ?? {}) as Map<String, dynamic>;
      data['http_status'] = response.status;
      return data;
    } catch (e) {
      // Gracefully convert Functions errors to a structured map for UI handling
      try {
        final dyn = e as dynamic;
        final status = (dyn.status as int?) ?? 500;
        final details = dyn.details;
        if (details is Map<String, dynamic>) {
          return {
            ...details,
            'http_status': status,
            'valid': details['valid'] == true ? true : false,
          };
        }
        return {
          'valid': false,
          'error': dyn.reasonPhrase?.toString() ?? e.toString(),
          'http_status': status,
        };
      } catch (_) {
        return {
          'valid': false,
          'error': e.toString(),
          'http_status': 500,
        };
      }
    }
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
    // CRITICAL: Do NOT filter splits by date!
    // Splits are matched to expenses by expense_id, and expenses are already date-filtered
    // If we filter splits by created_at, we'll miss splits created after the date range
    // even though the expense itself is within the range
    var query = _supabase
        .from('expense_split_groups')
        .select('*, expense_split_lines(*)')
        .eq('household_id', householdId);

    // Date filtering REMOVED - splits are filtered via expense matching, not date
    // This ensures all splits for household expenses are available regardless of when
    // the split was created

    final response = await query
        .order('created_at', ascending: false)
        .limit(300)
        .timeout(const Duration(seconds: 15));

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
    String? budgetType,
    bool? countSplitPortionOnly,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Gracefully handle uniqueness on (household_id, currency, period)
    // If a budget already exists for that tuple, update it instead of failing insert.
    // Note: We intentionally do NOT change period/currency when updating to avoid
    // violating the unique index again.
    final existing = await _supabase
        .from('shared_budgets')
        .select('id')
        .eq('household_id', householdId)
        .eq('currency', currency)
        .eq('period', period)
        .eq('is_active', true)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      // Update existing active budget for this (household, currency, period)
      final response = await _supabase
          .from('shared_budgets')
          .update({
            'name': name,
            'amount_cents': amountCents,
            'warn_threshold': warnThreshold ?? 0.8,
            'alert_threshold': alertThreshold ?? 1.0,
            'count_split_portion_only': countSplitPortionOnly ?? false,
            // Keep budget_type/user_id unchanged to respect existing record semantics
          })
          .eq('id', existing['id'] as String)
          .select()
          .single();
      return response;
    }

    // No existing budget: create a new one
    final data = <String, dynamic>{
      'household_id': householdId,
      'name': name,
      'period': period,
      'currency': currency,
      'amount_cents': amountCents,
      'warn_threshold': warnThreshold ?? 0.8,
      'alert_threshold': alertThreshold ?? 1.0,
      'budget_type': budgetType ?? 'household',
      'count_split_portion_only': countSplitPortionOnly ?? false,
      'is_active': true,
    };

    // Only add user_id for personal budgets
    if (budgetType == 'personal') {
      data['user_id'] = userId;
    }

    final response =
        await _supabase.from('shared_budgets').insert(data).select().single();

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
      updates['default_transaction_share_scope'] = defaultTransactionShareScope;
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

    final response =
        await _supabase.from('sharing_prefs').upsert(updates).select().single();

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

  Stream<List<Map<String, dynamic>>> watchHouseholdMembers(String householdId) {
    return _supabase
        .from('household_members')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((data) => data.cast<Map<String, dynamic>>());
  }

  Stream<List<Map<String, dynamic>>> watchHouseholdInvites(String householdId) {
    return _supabase
        .from('invites')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((data) => data.cast<Map<String, dynamic>>());
  }

  Stream<List<Map<String, dynamic>>> watchHouseholdBudgets(String householdId) {
    return _supabase
        .from('shared_budgets')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((data) => data.cast<Map<String, dynamic>>());
  }

  // ============================================================================
  // SETTLEMENT HELPERS
  // ============================================================================

  /// Get total unsettled amount (in cents) the current user owes to a specific member
  /// within a household, based on split lines where that member is the payer.
  Future<int> getUnsettledAmountToMember({
    required String householdId,
    required String memberUserId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final groups = await _supabase
        .from('expense_split_groups')
        .select('id')
        .eq('household_id', householdId)
        .eq('payer_user_id', memberUserId);

    final groupIds = (groups as List)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toList();

    if (groupIds.isEmpty) return 0;

    final lines = await _supabase
        .from('expense_split_lines')
        .select('amount_cents')
        .inFilter('split_group_id', groupIds)
        .eq('user_id', userId)
        .eq('is_settled', false);

    final cents = (lines as List)
        .map((e) => (e as Map<String, dynamic>)['amount_cents'] as int? ?? 0)
        .fold<int>(0, (s, v) => s + v.abs());

    return cents;
  }

  // ============================================================================
  // SETTLEMENT RECORDING (server-side RPC + notification enqueuing)
  // ============================================================================

  /// Settle all current user's dues to [memberUserId] and notify involved members (excluding self).
  /// Optional: provide [youOweCentsBefore] to include in notification payload without extra reads.
  Future<int> settleAllDebtsToMemberAndNotify({
    required String householdId,
    required String memberUserId,
    int? youOweCentsBefore,
    String? currency,
    String? settlementNote,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Use supplied precomputed value if provided (avoid extra reads)
    final amountCents = youOweCentsBefore ?? 0;
    final normalizedCurrency = currency?.toUpperCase();

    final result = await _supabase.rpc(
      'households_settle_all_debts_and_notify',
      params: {
        'p_household_id': householdId,
        'p_member_user_id': memberUserId,
        'p_mode': 'to_member',
        'p_you_owe_cents_before': amountCents,
        'p_you_are_owed_cents_before': 0,
        if (normalizedCurrency != null) 'p_currency': normalizedCurrency,
        if (settlementNote != null && settlementNote.isNotEmpty)
          'p_settlement_note': settlementNote,
      },
    );

    // RPC returns the number of lines updated
    return (result as int?) ?? 0;
  }

  /// Settle all dues where [memberUserId] owes the current user and notify the member.
  /// Optional: provide [theyOweYouCentsBefore] to include in notification payload without extra reads.
  Future<int> settleAllDebtsFromMemberAndNotify({
    required String householdId,
    required String memberUserId,
    int? theyOweYouCentsBefore,
    String? currency,
    String? settlementNote,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final amountCents = theyOweYouCentsBefore ?? 0;
    final normalizedCurrency = currency?.toUpperCase();

    final result = await _supabase.rpc(
      'households_settle_all_debts_and_notify',
      params: {
        'p_household_id': householdId,
        'p_member_user_id': memberUserId,
        'p_mode': 'from_member',
        'p_you_owe_cents_before': 0,
        'p_you_are_owed_cents_before': amountCents,
        if (normalizedCurrency != null) 'p_currency': normalizedCurrency,
        if (settlementNote != null && settlementNote.isNotEmpty)
          'p_settlement_note': settlementNote,
      },
    );

    return (result as int?) ?? 0;
  }

  Future<int> settleAmountAndNotify({
    required String householdId,
    required String memberUserId,
    required String mode,
    required int amountCents,
    String? currency,
    String? settlementNote,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final normalizedCurrency = currency?.trim().toUpperCase();

    final result = await _supabase.rpc(
      'households_settle_amount_and_notify',
      params: {
        'p_household_id': householdId,
        'p_member_user_id': memberUserId,
        'p_mode': mode,
        'p_amount_cents': amountCents,
        if (normalizedCurrency != null && normalizedCurrency.isNotEmpty)
          'p_currency': normalizedCurrency,
        if (settlementNote != null && settlementNote.isNotEmpty)
          'p_settlement_note': settlementNote,
      },
    );

    return (result as int?) ?? 0;
  }

  // ============================================================================
  // EXPRESS NETTING SUPPORT (pair-wise)
  // ============================================================================

  /// Settle ALL pair-wise dues between current user and [memberUserId] in both directions.
  ///
  /// This marks as settled:
  /// - Lines where current user owes the member (payer=member, user=current)
  /// - Lines where member owes the current user (payer=current, user=member)
  ///
  /// Returns total number of lines updated across both directions.
  Future<int> settleAllDebtsBetweenUsersAndNotify({
    required String householdId,
    required String memberUserId,
    int? youOweCentsBefore,
    int? youAreOwedCentsBefore,
    String? currency,
    String? settlementNote,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final normalizedCurrency = currency?.trim().toUpperCase();
    final oweCents = youOweCentsBefore ?? 0;
    final recvCents = youAreOwedCentsBefore ?? 0;

    final result = await _supabase.rpc(
      'households_settle_all_debts_and_notify',
      params: {
        'p_household_id': householdId,
        'p_member_user_id': memberUserId,
        'p_mode': 'both',
        'p_you_owe_cents_before': oweCents,
        'p_you_are_owed_cents_before': recvCents,
        if (normalizedCurrency != null) 'p_currency': normalizedCurrency,
        if (settlementNote != null && settlementNote.isNotEmpty)
          'p_settlement_note': settlementNote,
      },
    );

    return (result as int?) ?? 0;
  }
}
