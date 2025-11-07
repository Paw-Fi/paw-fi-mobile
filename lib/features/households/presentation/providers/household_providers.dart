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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getUserHouseholds(_userId));
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getHouseholdMembers(_householdId));
  }

  Future<void> removeMember(String memberId) async {
    await _repository.removeMember(memberId);
    await load();
  }

  Future<void> updateRole(String memberId, HouseholdRole role) async {
    await _repository.updateMemberRole(memberId, role);
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getHouseholdBudgets(_householdId));
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getHouseholdInvites(_householdId));
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
    await load();
    return token;
  }

  Future<void> revokeInvite({String? inviteId, String? token}) async {
    await _repository.revokeInvite(inviteId: inviteId, token: token);
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getSharingPreferences(
          userId: _userId,
          householdId: _householdId,
        ));
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

  const HouseholdExpensesParams({
    required this.householdId,
    this.limit = 10,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdExpensesParams &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          limit == other.limit;

  @override
  int get hashCode => householdId.hashCode ^ limit.hashCode;
}

/// Household expenses provider
final householdExpensesProvider =
    FutureProvider.family<List<ExpenseEntry>, HouseholdExpensesParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseClientProvider);
    try {
      // Fetch expenses (RLS allows: own or any with same household membership)
      // CRITICAL: Only fetch household expenses (split_group_id NOT NULL)
      final expenses = await supabase
          .from('expenses')
          .select('id, contact_id, user_id, household_id, date, amount_cents, currency, category, raw_text, receipt_image_url, created_at, split_group_id, type')
          .eq('household_id', params.householdId)
          .not('split_group_id', 'is', null) // Explicit filter for household expenses
          .order('created_at', ascending: false)
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
