import 'package:flutter/foundation.dart';
import 'package:moneko/core/core.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/household.dart';
import '../../domain/entities/household_summary.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/shared_budget.dart';
import '../../domain/repositories/household_repository.dart';
import '../../data/repositories/household_repository_impl.dart';
import '../../data/services/household_service.dart';
import '../../data/services/device_registration_service.dart';
import '../../../home/presentation/models/expense_entry.dart';

// ============================================================================
// CORE PROVIDERS
// ============================================================================

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Household service provider
final householdServiceProvider = Provider<HouseholdService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return HouseholdService(supabase);
});

/// Household repository provider
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  final service = ref.watch(householdServiceProvider);
  return HouseholdRepositoryImpl(service);
});

/// Device registration service provider
final deviceRegistrationServiceProvider = Provider<DeviceRegistrationService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final messaging = FirebaseMessaging.instance;
  final localNotifications = FlutterLocalNotificationsPlugin();
  return DeviceRegistrationService(supabase, messaging, localNotifications);
});

// ============================================================================
// STATE NOTIFIERS
// ============================================================================

/// User households state notifier
class UserHouseholdsNotifier extends StateNotifier<AsyncValue<List<Household>>> {
  final HouseholdRepository _repository;
  final String _userId;

  UserHouseholdsNotifier(this._repository, this._userId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.getUserHouseholds(_userId));
    if (!mounted) return;
    state = result;
  }

  Future<void> createHousehold({
    required String name,
    required String currency,
    String? coverImageUrl,
    String? themeColor,
  }) async {
    await _repository.createHousehold(
      name: name,
      currency: currency,
      coverImageUrl: coverImageUrl,
      themeColor: themeColor,
    );
    await load();
  }
}

/// User households provider
final userHouseholdsProvider =
    StateNotifierProvider.family<UserHouseholdsNotifier, AsyncValue<List<Household>>, String>(
  (ref, userId) {
    final repository = ref.watch(householdRepositoryProvider);
    return UserHouseholdsNotifier(repository, userId);
  },
);

// ============================================================================
// HOUSEHOLD MEMBERS
// ============================================================================

/// Household members state notifier
class HouseholdMembersNotifier extends StateNotifier<AsyncValue<List<HouseholdMember>>> {
  final HouseholdRepository _repository;
  final String _householdId;

  HouseholdMembersNotifier(this._repository, this._householdId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.getHouseholdMembers(_householdId));
    if (!mounted) return;
    state = result;
  }

  Future<void> removeMember(String memberId) async {
    await _repository.removeMember(memberId);
    if (!mounted) return;
    await load();
  }

  Future<void> updateRole(String memberId, HouseholdRole role) async {
    await _repository.updateMemberRole(memberId, role);
    if (!mounted) return;
    await load();
  }
}

/// Household members provider
final householdMembersProvider = StateNotifierProvider.family<
    HouseholdMembersNotifier,
    AsyncValue<List<HouseholdMember>>,
    String>(
  (ref, householdId) {
    final repository = ref.watch(householdRepositoryProvider);
    return HouseholdMembersNotifier(repository, householdId);
  },
);

// ============================================================================
// HOUSEHOLD BUDGETS
// ============================================================================

/// Household budgets state notifier
class HouseholdBudgetsNotifier extends StateNotifier<AsyncValue<List<SharedBudget>>> {
  final HouseholdRepository _repository;
  final String _householdId;

  HouseholdBudgetsNotifier(this._repository, this._householdId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.getHouseholdBudgets(_householdId));
    if (!mounted) return;
    state = result;
  }

  Future<void> createBudget({
    required String name,
    required String period,
    required String currency,
    required int amountCents,
    double? warnThreshold,
    double? alertThreshold,
    String? budgetType,
    bool? countSplitPortionOnly,
  }) async {
    await _repository.createBudget(
      householdId: _householdId,
      name: name,
      period: period,
      currency: currency,
      amountCents: amountCents,
      warnThreshold: warnThreshold,
      alertThreshold: alertThreshold,
      budgetType: budgetType,
      countSplitPortionOnly: countSplitPortionOnly,
    );
    if (!mounted) return;
    await load();
  }
}

/// Household budgets provider
final householdBudgetsProvider = StateNotifierProvider.family<
    HouseholdBudgetsNotifier,
    AsyncValue<List<SharedBudget>>,
    String>(
  (ref, householdId) {
    final repository = ref.watch(householdRepositoryProvider);
    return HouseholdBudgetsNotifier(repository, householdId);
  },
);

// ============================================================================
// HOUSEHOLD INVITES
// ============================================================================

/// Household invites state notifier
class HouseholdInvitesNotifier extends StateNotifier<AsyncValue<List<HouseholdInvite>>> {
  final HouseholdRepository _repository;
  final String _householdId;

  HouseholdInvitesNotifier(this._repository, this._householdId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.getHouseholdInvites(_householdId));
    if (!mounted) return;
    state = result;
  }

  Future<String> createInvite({
    String? invitedEmail,
    String? personalMessage,
    int expiresInDays = 7,
  }) async {
    final token = await _repository.createInvite(
      householdId: _householdId,
      invitedEmail: invitedEmail,
      personalMessage: personalMessage,
      expiresInDays: expiresInDays,
    );
    if (!mounted) return token;
    await load();
    return token;
  }

  Future<void> revokeInvite({String? inviteId, String? token}) async {
    await _repository.revokeInvite(inviteId: inviteId, token: token);
    if (!mounted) return;
    await load();
  }
}

/// Household invites provider
final householdInvitesProvider = StateNotifierProvider.family<
    HouseholdInvitesNotifier,
    AsyncValue<List<HouseholdInvite>>,
    String>(
  (ref, householdId) {
    final repository = ref.watch(householdRepositoryProvider);
    return HouseholdInvitesNotifier(repository, householdId);
  },
);

// ============================================================================
// SHARING PREFERENCES
// ============================================================================

/// Parameter class for sharing preferences provider
class SharingPrefsParams {
  final String userId;
  final String householdId;

  const SharingPrefsParams({
    required this.userId,
    required this.householdId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharingPrefsParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          householdId == other.householdId;

  @override
  int get hashCode => userId.hashCode ^ householdId.hashCode;
}

/// Sharing preferences state notifier
class SharingPrefsNotifier extends StateNotifier<AsyncValue<SharingPreferences?>> {
  final HouseholdRepository _repository;
  final String _userId;
  final String _householdId;

  SharingPrefsNotifier(this._repository, this._userId, this._householdId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.getSharingPreferences(
          userId: _userId,
          householdId: _householdId,
        ));
    if (!mounted) return;
    state = result;
  }

  Future<void> updatePreferences({
    ShareScope? defaultTransactionShareScope,
    ShareScope? defaultAccountShareScope,
    Map<String, String>? perCategoryOverrides,
    bool? enableNudges,
    String? nudgeQuietHoursStart,
    String? nudgeQuietHoursEnd,
  }) async {
    await _repository.updateSharingPreferences(
      userId: _userId,
      householdId: _householdId,
      defaultTransactionShareScope: defaultTransactionShareScope,
      defaultAccountShareScope: defaultAccountShareScope,
      perCategoryOverrides: perCategoryOverrides,
      enableNudges: enableNudges,
      nudgeQuietHoursStart: nudgeQuietHoursStart,
      nudgeQuietHoursEnd: nudgeQuietHoursEnd,
    );
    if (!mounted) return;
    await load();
  }
}

/// Sharing preferences provider
final sharingPrefsProvider = StateNotifierProvider.family<
    SharingPrefsNotifier,
    AsyncValue<SharingPreferences?>,
    SharingPrefsParams>(
  (ref, params) {
    final repository = ref.watch(householdRepositoryProvider);
    return SharingPrefsNotifier(repository, params.userId, params.householdId);
  },
);

// ============================================================================
// HOUSEHOLD SUMMARY
// ============================================================================

/// Parameter class for household summary provider
class HouseholdSummaryParams {
  final String householdId;
  final String currency;
  final String startDate;
  final String endDate;

  const HouseholdSummaryParams({
    required this.householdId,
    required this.currency,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdSummaryParams &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          currency == other.currency &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      householdId.hashCode ^
      currency.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}

/// Household summary provider with currency and date range support
final householdSummaryProvider =
    FutureProvider.family<HouseholdSummary?, HouseholdSummaryParams>(
  (ref, params) async {
    final repository = ref.watch(householdRepositoryProvider);

    final summary = await repository.getHouseholdSummary(
      householdId: params.householdId,
      currency: params.currency,
      startDate: params.startDate,
      endDate: params.endDate,
    );
    return summary;
  },
);

// ============================================================================
// HOUSEHOLD SPLITS
// ============================================================================

/// Parameter class for household splits provider
class HouseholdSplitsParams {
  final String householdId;
  final String? dateRange;

  const HouseholdSplitsParams({
    required this.householdId,
    this.dateRange,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdSplitsParams &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          dateRange == other.dateRange;

  @override
  int get hashCode => householdId.hashCode ^ (dateRange?.hashCode ?? 0);
}

/// Household splits provider
final householdSplitsProvider =
    FutureProvider.family<List<ExpenseSplitGroup>, HouseholdSplitsParams>(
  (ref, params) async {
    final repository = ref.watch(householdRepositoryProvider);

    // Get splits for the household
    final splits = await repository.getHouseholdSplits(
      householdId: params.householdId,
    );

    return splits;
  },
);

// ============================================================================
// HOUSEHOLD EXPENSES
// ============================================================================

/// Parameter class for household expenses provider
class HouseholdExpensesParams {
  final String householdId;
  final int limit;
  final DateTime? startDate;  // NEW: Date filter
  final DateTime? endDate;    // NEW: Date filter

  const HouseholdExpensesParams({
    required this.householdId,
    this.limit = 1000,  // Increased default from 500 to 1000 for better UX
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdExpensesParams &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          limit == other.limit &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => householdId.hashCode ^ limit.hashCode ^ 
                      (startDate?.hashCode ?? 0) ^ (endDate?.hashCode ?? 0);
}

/// Household expenses provider
/// NOTE: Uses direct database query instead of backend endpoint because:
/// 1. Needs user_id and contact_id for user enrichment (not returned by backend)
/// 2. Needs to fetch and join with users table for display names
/// 3. Backend endpoint is optimized for simple lists, not joined data
/// The is_recurring filter is applied here to ensure data separation
final householdExpensesProvider =
    FutureProvider.family<List<ExpenseEntry>, HouseholdExpensesParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseClientProvider);
    try {
      // Fetch expenses (RLS allows: own or any with same household membership)
      // CRITICAL: Only fetch household expenses (split_group_id NOT NULL)
      // Exclude recurring items here; recurring are surfaced in the dedicated
      // recurring flow.
      var expensesQuery = supabase
          .from('expenses')
          .select('id, contact_id, user_id, household_id, date, amount_cents, currency, category, raw_text, receipt_image_url, created_at, updated_at, split_group_id, type, is_recurring')
          .eq('household_id', params.householdId)
          .not('split_group_id', 'is', null) // Explicit filter for household expenses
          .or('is_recurring.eq.false,is_recurring.is.null');
      
      // Apply date filters if provided
      if (params.startDate != null) {
        expensesQuery = expensesQuery.gte('date', params.startDate!.toIso8601String());
      }
      if (params.endDate != null) {
        expensesQuery = expensesQuery.lte('date', params.endDate!.toIso8601String());
      }
      
      final expenses = await expensesQuery
          .order('date', ascending: false)
          .limit(params.limit);

      final expensesList = (expenses as List).cast<Map<String, dynamic>>();
      if (expensesList.isEmpty) return [];

      // Collect userIds to enrich display (optional)
      final userIds = expensesList
          .map((e) => e['user_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();
      debugPrint('🔍 Found ${userIds.length} unique user IDs: $userIds');

      Map<String, Map<String, dynamic>> usersMap = {};
      if (userIds.isNotEmpty) {
        try {
          final usersData = await supabase
              .from('users')
              .select('id, full_name, email, avatar_url')
              .inFilter('id', userIds);
          for (var user in (usersData as List).cast<Map<String, dynamic>>()) {
            String? displayName = user['full_name'] as String?;
            final email = user['email'] as String?;
            if (displayName == null || displayName.isEmpty) {
              displayName = (email != null && email.isNotEmpty)
                  ? email.split('@').first
                  : 'User';
            }
            user['full_name'] = displayName;
            usersMap[user['id'] as String] = user;
          }
        } catch (e) {
          appLog('Error fetching users: $e', name: 'HouseholdProviders', error: e);
        }
      }

      for (var expense in expensesList) {
        final userId = expense['user_id'] as String?;
        if (userId != null && usersMap.containsKey(userId)) {
          expense['users'] = usersMap[userId];
        }
      }

      return expensesList.map(ExpenseEntry.fromJson).toList();
    } catch (e, st) {
      debugPrint('❌ Error loading household expenses: $e\n$st');
      // Bubble up to UI to show consistent error state
      rethrow;
    }
  },
);

// ============================================================================
// COVER IMAGES
// ============================================================================

/// Provider for available household cover images
/// Hardcoded list of all available cover images
final coverImagesProvider = FutureProvider<List<String>>((ref) async {
  const baseUrl = 'https://pbopcsmrcykdzbilpilf.supabase.co/storage/v1/object/public/group-cover-photos/';

  final images = [
    '${baseUrl}balloons.png',
    '${baseUrl}basket.png',
    '${baseUrl}car.png',
    '${baseUrl}circle.png',
    '${baseUrl}coffees.png',
    '${baseUrl}hands.png',
    '${baseUrl}heart.png',
    '${baseUrl}house.png',
    '${baseUrl}notebook.png',
    '${baseUrl}piggy-bank.png',
    '${baseUrl}pizza.png',
    '${baseUrl}rings.png',
    '${baseUrl}shoes.png',
    '${baseUrl}shopping_bag.png',
  ];

  appLog('Household cover images loaded: count=${images.length}', name: 'HouseholdProviders');
  appLog('First image URL: ${images.first}', name: 'HouseholdProviders');
  appLog('Last image URL: ${images.last}', name: 'HouseholdProviders');

  return images;
});

// ============================================================================
// SINGLE HOUSEHOLD
// ============================================================================

/// Single household provider
final householdProvider =
    FutureProvider.family<Household?, String>((ref, householdId) async {
  final repository = ref.watch(householdRepositoryProvider);
  return repository.getHousehold(householdId);
});

// ============================================================================
// HOUSEHOLD SETTLEMENT HISTORY (derived from settled split lines)
// ============================================================================

class SettlementHistoryParams {
  final String householdId;
  final int limit;
  const SettlementHistoryParams({required this.householdId, this.limit = 200});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettlementHistoryParams &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          limit == other.limit;

  @override
  int get hashCode => householdId.hashCode ^ limit.hashCode;
}

class SettlementLine {
  final String splitGroupId;
  final int amountCents;
  final DateTime settledAt;
  final String? description;
  final String? expenseId;

  const SettlementLine({
    required this.splitGroupId,
    required this.amountCents,
    required this.settledAt,
    this.description,
    this.expenseId,
  });
}

class SettlementEvent {
  final DateTime settledAt;
  final String payerUserId;
  final String participantUserId;
  final String currency;
  final int amountCents;
  final int lineCount;
  final String? description;
  final String? splitGroupId;
  final List<SettlementLine> lines;

  const SettlementEvent({
    required this.settledAt,
    required this.payerUserId,
    required this.participantUserId,
    required this.currency,
    required this.amountCents,
    required this.lineCount,
    this.description,
    this.splitGroupId,
    this.lines = const [],
  });
}

/// Settlements timeline provider (newest first)
final householdSettlementHistoryProvider = FutureProvider.autoDispose
    .family<List<SettlementEvent>, SettlementHistoryParams>((ref, params) async {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      print(
          '[settlement_history] no current user; skip load household=${params.householdId}');
      return const <SettlementEvent>[];
    }
    print(
        '[settlement_history] start household=${params.householdId} limit=${params.limit} user=$currentUserId');

    // Query 1: lines where current user is participant
    final responseParticipant = await supabase
        .from('expense_split_lines')
        .select(
            'settled_at, amount_cents, user_id, split_group_id, expense_split_groups!inner(payer_user_id, currency, household_id, description, expense_id)')
        .eq('is_settled', true)
        .not('settled_at', 'is', null)
        .eq('expense_split_groups.household_id', params.householdId)
        .eq('user_id', currentUserId)
        .order('settled_at', ascending: false)
        .limit(params.limit)
        .timeout(const Duration(seconds: 10));

    // Query 2: lines where current user is payer
    final responsePayer = await supabase
        .from('expense_split_lines')
        .select(
            'settled_at, amount_cents, user_id, split_group_id, expense_split_groups!inner(payer_user_id, currency, household_id, description, expense_id)')
        .eq('is_settled', true)
        .not('settled_at', 'is', null)
        .eq('expense_split_groups.household_id', params.householdId)
        .eq('expense_split_groups.payer_user_id', currentUserId)
        .order('settled_at', ascending: false)
        .limit(params.limit)
        .timeout(const Duration(seconds: 10));

    print(
        '[settlement_history] raw response types: participant=${responseParticipant.runtimeType} payer=${responsePayer.runtimeType} household=${params.householdId}');

    final rows = <Map<String, dynamic>>[
      ...(responseParticipant as List).cast<Map<String, dynamic>>(),
      ...(responsePayer as List).cast<Map<String, dynamic>>(),
    ];
    print(
        '[settlement_history] fetched rows=${rows.length} household=${params.householdId}');
    if (rows.isNotEmpty) {
      final sample = rows.first;
      print(
          '[settlement_history] sample settled_at=${sample['settled_at']} payer=${(sample['expense_split_groups'] as Map?)?['payer_user_id']} participant=${sample['user_id']} amount=${sample['amount_cents']} currency=${(sample['expense_split_groups'] as Map?)?['currency']}');
    } else {
      print('[settlement_history] no rows returned for household=${params.householdId}');
    }

    // Aggregate by payer + participant + currency + settled minute to reduce noise
    final Map<String, SettlementEvent> grouped = {};
    int skippedMissingDate = 0;
    int skippedMissingIds = 0;
    int skippedZeroAmount = 0;
    for (final row in rows) {
      final settledAtStr = row['settled_at'] as String?;
      final settledAt =
          settledAtStr != null ? DateTime.parse(settledAtStr) : null;
      if (settledAt == null) {
        skippedMissingDate++;
        continue;
      }
      final minute =
          DateTime(settledAt.year, settledAt.month, settledAt.day, settledAt.hour, settledAt.minute);

      final group = row['expense_split_groups'] as Map<String, dynamic>? ?? {};
      final payerId = group['payer_user_id'] as String? ?? '';
      final participantId = row['user_id'] as String? ?? '';
      if (payerId.isEmpty || participantId.isEmpty) {
        skippedMissingIds++;
        continue;
      }

      final currency = (group['currency'] as String? ?? '').toUpperCase();
      final amount = (row['amount_cents'] as int? ?? 0).abs();
      if (amount <= 0) {
        skippedZeroAmount++;
        continue;
      }
      // Use epoch millis for the time bucket to avoid locale/colon issues in keys
      final key =
          '${payerId}_${participantId}_${currency}_${minute.millisecondsSinceEpoch}';

      final line = SettlementLine(
        splitGroupId: (row['split_group_id'] as String?) ?? '',
        amountCents: amount,
        settledAt: settledAt,
        description: group['description'] as String?,
        expenseId: group['expense_id'] as String?,
      );

      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = SettlementEvent(
          settledAt: minute,
          payerUserId: payerId,
          participantUserId: participantId,
          currency: currency,
          amountCents: amount,
          lineCount: 1,
          description: group['description'] as String?,
          splitGroupId: row['split_group_id'] as String?,
          lines: [line],
        );
      } else {
        final updatedLines = [...existing.lines, line];
        grouped[key] = SettlementEvent(
          settledAt: existing.settledAt,
          payerUserId: existing.payerUserId,
          participantUserId: existing.participantUserId,
          currency: existing.currency,
          amountCents: existing.amountCents + amount,
          lineCount: updatedLines.length,
          description: existing.description ?? group['description'] as String?,
          splitGroupId:
              existing.splitGroupId ?? row['split_group_id'] as String?,
          lines: updatedLines,
        );
      }
    }

    final events = grouped.values.toList()
      ..sort((a, b) => b.settledAt.compareTo(a.settledAt));
    print(
        '[settlement_history] aggregated events=${events.length} skippedMissingDate=$skippedMissingDate skippedMissingIds=$skippedMissingIds skippedZeroAmount=$skippedZeroAmount household=${params.householdId}');
    return events;
  } catch (e, st) {
    print(
        '[settlement_history] error household=${params.householdId}: $e\n$st');
    return const <SettlementEvent>[];
  }
});
