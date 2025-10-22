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
    String? emoji,
    String? themeColor,
  }) async {
    await _repository.createHousehold(
      name: name,
      emoji: emoji,
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
  }) async {
    await _repository.createBudget(
      householdId: _householdId,
      name: name,
      period: period,
      currency: currency,
      amountCents: amountCents,
      warnThreshold: warnThreshold,
      alertThreshold: alertThreshold,
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

  const HouseholdSummaryParams({
    required this.householdId,
    required this.currency,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdSummaryParams &&
          runtimeType == other.runtimeType &&
          householdId == other.householdId &&
          currency == other.currency;

  @override
  int get hashCode => householdId.hashCode ^ currency.hashCode;
}

/// Household summary provider with currency support
final householdSummaryProvider =
    FutureProvider.family<HouseholdSummary?, HouseholdSummaryParams>(
  (ref, params) async {
    final repository = ref.watch(householdRepositoryProvider);
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0);

    final summary = await repository.getHouseholdSummary(
      householdId: params.householdId,
      currency: params.currency,
      startDate: startDate.toIso8601String(),
      endDate: endDate.toIso8601String(),
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
// SINGLE HOUSEHOLD
// ============================================================================

/// Single household provider
final householdProvider =
    FutureProvider.family<Household?, String>((ref, householdId) async {
  final repository = ref.watch(householdRepositoryProvider);
  return repository.getHousehold(householdId);
});
