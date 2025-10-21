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

  Future<void> createBudget(Map<String, dynamic> budgetData) async {
    await _repository.createSharedBudget(budgetData);
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
// HOUSEHOLD SUMMARY
// ============================================================================

/// Household summary provider (future provider - loads once when needed)
final householdSummaryProvider =
    FutureProvider.family<HouseholdSummary?, String>((ref, householdId) async {
  final repository = ref.watch(householdRepositoryProvider);
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, 1);
  final endDate = DateTime(now.year, now.month + 1, 0);

  final summary = await repository.getHouseholdSummary(
    householdId,
    startDate.toIso8601String(),
    endDate.toIso8601String(),
  );
  return summary;
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
