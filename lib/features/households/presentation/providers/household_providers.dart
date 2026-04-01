import 'package:moneko/core/core.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';

import '../../domain/entities/household.dart';
import '../../domain/entities/household_summary.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/shared_budget.dart';
import '../../domain/utils/settlement_net_calculator.dart';
import '../../domain/repositories/household_repository.dart';
import '../../data/repositories/household_repository_impl.dart';
import '../../data/services/household_service.dart';
import '../../data/services/device_registration_service.dart';
import '../../../home/presentation/models/expense_entry.dart';
import 'household_optimistic_providers.dart';

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
final deviceRegistrationServiceProvider =
    Provider<DeviceRegistrationService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final messaging = FirebaseMessaging.instance;
  final localNotifications = FlutterLocalNotificationsPlugin();
  return DeviceRegistrationService(
    ref,
    supabase,
    messaging,
    localNotifications,
  );
});

// ============================================================================
// STATE NOTIFIERS
// ============================================================================

/// User households state notifier
class UserHouseholdsNotifier
    extends StateNotifier<AsyncValue<List<Household>>> {
  final HouseholdRepository _repository;
  final String _userId;
  final Ref _ref;

  UserHouseholdsNotifier(this._repository, this._userId, this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;

    // Preview mode: return mock households instantly
    final preview = _ref.read(previewModeProvider);
    if (preview.isActive) {
      state = AsyncValue.data(PreviewMockData.households);
      return;
    }

    state = const AsyncValue.loading();
    final result =
        await AsyncValue.guard(() => _repository.getUserHouseholds(_userId));
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
final userHouseholdsProvider = StateNotifierProvider.family<
    UserHouseholdsNotifier, AsyncValue<List<Household>>, String>(
  (ref, userId) {
    final repository = ref.watch(householdRepositoryProvider);
    return UserHouseholdsNotifier(repository, userId, ref);
  },
);

// ============================================================================
// HOUSEHOLD MEMBERS
// ============================================================================

/// Household members state notifier
class HouseholdMembersNotifier
    extends StateNotifier<AsyncValue<List<HouseholdMember>>> {
  final HouseholdRepository _repository;
  final String _householdId;

  HouseholdMembersNotifier(this._repository, this._householdId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
        () => _repository.getHouseholdMembers(_householdId));
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
    HouseholdMembersNotifier, AsyncValue<List<HouseholdMember>>, String>(
  (ref, householdId) {
    final repository = ref.watch(householdRepositoryProvider);
    return HouseholdMembersNotifier(repository, householdId);
  },
);

// ============================================================================
// HOUSEHOLD BUDGETS
// ============================================================================

/// Household budgets state notifier
class HouseholdBudgetsNotifier
    extends StateNotifier<AsyncValue<List<SharedBudget>>> {
  final HouseholdRepository _repository;
  final String _householdId;

  HouseholdBudgetsNotifier(this._repository, this._householdId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
        () => _repository.getHouseholdBudgets(_householdId));
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
    HouseholdBudgetsNotifier, AsyncValue<List<SharedBudget>>, String>(
  (ref, householdId) {
    final repository = ref.watch(householdRepositoryProvider);
    return HouseholdBudgetsNotifier(repository, householdId);
  },
);

// ============================================================================
// HOUSEHOLD INVITES
// ============================================================================

/// Household invites state notifier
class HouseholdInvitesNotifier
    extends StateNotifier<AsyncValue<List<HouseholdInvite>>> {
  final HouseholdRepository _repository;
  final String _householdId;

  HouseholdInvitesNotifier(this._repository, this._householdId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
        () => _repository.getHouseholdInvites(_householdId));
    if (!mounted) return;
    state = result;
  }

  Future<String> createInvite({
    String? invitedEmail,
    String? personalMessage,
    String? inviterName,
    String? householdName,
    int expiresInDays = 7,
  }) async {
    final token = await _repository.createInvite(
      householdId: _householdId,
      invitedEmail: invitedEmail,
      personalMessage: personalMessage,
      inviterName: inviterName,
      householdName: householdName,
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
    HouseholdInvitesNotifier, AsyncValue<List<HouseholdInvite>>, String>(
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
class SharingPrefsNotifier
    extends StateNotifier<AsyncValue<SharingPreferences?>> {
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
    final result =
        await AsyncValue.guard(() => _repository.getSharingPreferences(
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
final sharingPrefsProvider = StateNotifierProvider.family<SharingPrefsNotifier,
    AsyncValue<SharingPreferences?>, SharingPrefsParams>(
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

    // Use a tighter timeout so dashboard widgets fail fast instead of
    // appearing to load forever when the backend is slow/unresponsive.
    const timeout = Duration(seconds: 10);
    const maxAttempts = 1;
    Exception? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        // Simple backoff between retries
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }

      try {
        final summary = await repository
            .getHouseholdSummary(
              householdId: params.householdId,
              currency: params.currency,
              startDate: params.startDate,
              endDate: params.endDate,
            )
            .timeout(timeout);
        return summary;
      } on TimeoutException catch (e) {
        lastError = e;
        FirebaseCrashlytics.instance.log(
            '⚠️ householdSummaryProvider timeout (attempt $attempt/$maxAttempts) for ${params.householdId} ${params.currency}');
      } on FunctionException catch (e) {
        lastError = e;
        FirebaseCrashlytics.instance.log(
            '⚠️ householdSummaryProvider function error ${e.status} (attempt $attempt/$maxAttempts) for ${params.householdId} ${params.currency}');
        // For auth/permission issues, do not keep retrying
        if (e.status == 401 || e.status == 403) break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        FirebaseCrashlytics.instance.log(
            '⚠️ householdSummaryProvider error (attempt $attempt/$maxAttempts) for ${params.householdId} ${params.currency}: $e');
      }
    }

    throw lastError ?? Exception('Unknown household summary error');
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
    final optimistic = ref.watch(
      householdOptimisticSplitsProvider
          .select((state) => state[params.householdId] ?? const []),
    );

    // Get splits for the household
    final splits = await repository.getHouseholdSplits(
      householdId: params.householdId,
    );

    if (optimistic.isNotEmpty) {
      ref
          .read(householdOptimisticSplitsProvider.notifier)
          .pruneIfInServer(params.householdId, splits);
    }

    return mergeHouseholdSplits(splits, optimistic);
  },
);

// ============================================================================
// HOUSEHOLD EXPENSES
// ============================================================================

/// Parameter class for household expenses provider
class HouseholdExpensesParams {
  final String householdId;
  final int limit;
  final DateTime? startDate; // NEW: Date filter
  final DateTime? endDate; // NEW: Date filter

  const HouseholdExpensesParams({
    required this.householdId,
    this.limit = 1000, // Increased default from 500 to 1000 for better UX
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
  int get hashCode =>
      householdId.hashCode ^
      limit.hashCode ^
      (startDate?.hashCode ?? 0) ^
      (endDate?.hashCode ?? 0);
}

/// Household expenses provider
/// NOTE: Uses direct database query instead of backend endpoint because:
/// 1. Needs user_id and contact_id for user enrichment (not returned by backend)
/// 2. Needs to fetch and join with users table for display names
/// 3. Backend endpoint is optimized for simple lists, not joined data
/// Includes recurring rows so household dashboards match home totals
final householdExpensesProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, HouseholdExpensesParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseClientProvider);
    // Reduce timeout so the UI can surface an error state quickly rather than
    // waiting ~25s before giving up on a stuck query.
    const timeout = Duration(seconds: 10);
    try {
      // Fetch expenses (RLS allows: own or any with same household membership)
      // Include ALL expenses with this household_id, regardless of split_group_id.
      // Expenses logged via WhatsApp AI bot may not have a split group yet.
      const expenseSelectFields =
          'id, contact_id, user_id, household_id, date, amount_cents, currency, category, raw_text, breakdown, receipt_image_url, created_at, updated_at, split_group_id, type, is_recurring, account_id';

      dynamic buildExpensesQuery() {
        var query = supabase
            .from('expenses')
            .select(expenseSelectFields)
            .eq('household_id', params.householdId);

        if (params.startDate != null) {
          query = query.gte('date', formatDateOnlyYmd(params.startDate!));
        }
        if (params.endDate != null) {
          query = query.lte('date', formatDateOnlyYmd(params.endDate!));
        }

        return query;
      }

      List<Map<String, dynamic>> expensesList;
      if (params.limit <= 0) {
        const pageSize = 1000;
        const maxPages = 200;
        final allRows = <Map<String, dynamic>>[];
        var offset = 0;
        var reachedMaxPages = true;

        for (var page = 0; page < maxPages; page++) {
          final response = await buildExpensesQuery()
              .order('date', ascending: false)
              .order('created_at', ascending: false)
              .order('id', ascending: false)
              .range(offset, offset + pageSize - 1)
              .timeout(timeout);
          final batch = (response as List).cast<Map<String, dynamic>>();
          if (batch.isEmpty) {
            reachedMaxPages = false;
            break;
          }

          allRows.addAll(batch);
          if (batch.length < pageSize) {
            reachedMaxPages = false;
            break;
          }
          offset += pageSize;
        }

        if (reachedMaxPages && allRows.isNotEmpty) {
          FirebaseCrashlytics.instance.log(
            '⚠️ householdExpensesProvider reached max pages '
            '(household=${params.householdId}, pages=$maxPages, pageSize=$pageSize)',
          );
        }

        expensesList = allRows;
      } else {
        final response = await buildExpensesQuery()
            .order('date', ascending: false)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(params.limit)
            .timeout(timeout);
        expensesList = (response as List).cast<Map<String, dynamic>>();
      }

      if (expensesList.isEmpty) return [];

      // Collect userIds to enrich display (optional)
      final userIds = expensesList
          .map((e) => e['user_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();
      FirebaseCrashlytics.instance
          .log('🔍 Found ${userIds.length} unique user IDs');

      Map<String, Map<String, dynamic>> usersMap = {};
      if (userIds.isNotEmpty) {
        try {
          const chunkSize = 200;
          for (var i = 0; i < userIds.length; i += chunkSize) {
            final end = (i + chunkSize < userIds.length)
                ? i + chunkSize
                : userIds.length;
            final chunk = userIds.sublist(i, end);
            final usersData = await supabase
                .from('users')
                .select('id, full_name, email, avatar_url')
                .inFilter('id', chunk);
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
          }
        } catch (e) {
          appLog('Error fetching users: $e',
              name: 'HouseholdProviders', error: e);
        }
      }

      for (var expense in expensesList) {
        final userId = expense['user_id'] as String?;
        if (userId != null && usersMap.containsKey(userId)) {
          expense['users'] = usersMap[userId];
        }
      }

      final entries = expensesList.map(ExpenseEntry.fromJson).toList();
      final optimistic = ref.watch(
        householdOptimisticExpensesProvider
            .select((state) => state[params.householdId] ?? const []),
      );
      if (optimistic.isNotEmpty) {
        ref
            .read(householdOptimisticExpensesProvider.notifier)
            .pruneIfInServer(params.householdId, entries);
      }
      return mergeHouseholdExpenses(entries, optimistic);
    } on TimeoutException catch (e, st) {
      FirebaseCrashlytics.instance.log(
        '⚠️ householdExpensesProvider timeout for '
        '${params.householdId} (limit=${params.limit}): $e',
      );
      FirebaseCrashlytics.instance
          .log('❌ Error loading household expenses (timeout): $e\n$st');
      // Bubble up to UI to show consistent error state
      rethrow;
    } catch (e, st) {
      FirebaseCrashlytics.instance
          .log('❌ Error loading household expenses: $e\n$st');
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
  const baseUrl =
      'https://pbopcsmrcykdzbilpilf.supabase.co/storage/v1/object/public/group-cover-photos/';

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

  appLog('Household cover images loaded: count=${images.length}',
      name: 'HouseholdProviders');
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
// HOUSEHOLD SETTLEMENT PAYMENTS (for settlement suggestions card)
// ============================================================================

/// Settlement payment records provider — watched by SettlementSuggestionsCard
/// for reactive updates. Invalidated after settlement via
/// cacheInvalidatorProvider or explicit ref.invalidate().
///
/// Keyed by householdId only (no currency). This ensures exactly one cache
/// entry per household so invalidation after settlement always hits the
/// correct instance regardless of which currency the UI is displaying.
/// Currency filtering is done client-side by the net calculator.
final householdSettlementPaymentsProvider = FutureProvider.autoDispose
    .family<List<SettlementPaymentRecord>, String>((ref, householdId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) return const <SettlementPaymentRecord>[];

  try {
    final response = await supabase
        .from('household_settlement_events')
        .select('payer_user_id, participant_user_id, amount_cents, currency')
        .eq('household_id', householdId)
        .or('payer_user_id.eq.$currentUserId,participant_user_id.eq.$currentUserId');

    final rows = (response as List).cast<Map<String, dynamic>>();
    final out = <SettlementPaymentRecord>[];
    for (final row in rows) {
      final payer = row['payer_user_id'] as String?;
      final participant = row['participant_user_id'] as String?;
      if (payer == null || payer.isEmpty) continue;
      if (participant == null || participant.isEmpty) continue;
      if (payer == participant) continue;
      final amount = (row['amount_cents'] as int? ?? 0).abs();
      if (amount <= 0) continue;
      final currency = row['currency'] as String?;
      out.add(SettlementPaymentRecord(
        payerUserId: payer,
        participantUserId: participant,
        amountCents: amount,
        currency: currency,
      ));
    }
    return out;
  } catch (e) {
    return const <SettlementPaymentRecord>[];
  }
});

// ============================================================================
// HOUSEHOLD SETTLEMENT HISTORY (from household_settlement_events)
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
  final String? expenseId;
  final String? expenseDescription;
  final String? expenseCategory;
  final String? expenseRawText;
  final String? settledByUserId;
  final String? payerUserId;
  final String? participantUserId;
  final String? settlementNote;

  const SettlementLine({
    required this.splitGroupId,
    required this.amountCents,
    required this.settledAt,
    this.expenseId,
    this.expenseDescription,
    this.expenseCategory,
    this.expenseRawText,
    this.settledByUserId,
    this.payerUserId,
    this.participantUserId,
    this.settlementNote,
  });
}

class SettlementEvent {
  final DateTime settledAt;
  final String payerUserId;
  final String participantUserId;
  final String currency;
  final int amountCents;
  final int lineCount;
  final String? splitGroupId;
  final List<SettlementLine> lines;
  final String? settledByUserId;
  final bool isExpressNetting;
  final int payerToParticipantCents; // total participant owes payer
  final int participantToPayerCents; // total payer owes participant
  final String? settlementNote;

  const SettlementEvent({
    required this.settledAt,
    required this.payerUserId,
    required this.participantUserId,
    required this.currency,
    required this.amountCents,
    required this.lineCount,
    this.splitGroupId,
    this.lines = const [],
    this.settledByUserId,
    this.isExpressNetting = false,
    this.payerToParticipantCents = 0,
    this.participantToPayerCents = 0,
    this.settlementNote,
  });
}

/// Settlements timeline provider (newest first)
final householdSettlementHistoryProvider = FutureProvider.autoDispose
    .family<List<SettlementEvent>, SettlementHistoryParams>(
        (ref, params) async {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      FirebaseCrashlytics.instance.log(
          '[settlement_history] no current user; skip load household=${params.householdId}');
      return const <SettlementEvent>[];
    }
    FirebaseCrashlytics.instance.log(
        '[settlement_history] start household=${params.householdId} limit=${params.limit} user=$currentUserId');

    // Query 1: lines where current user is participant
    final responseParticipant = await supabase
        .from('household_settlement_events')
        .select(
            'id, created_at, amount_cents, payer_user_id, participant_user_id, actor_user_id, settlement_note, currency, is_express_netting')
        .eq('household_id', params.householdId)
        .eq('participant_user_id', currentUserId)
        .order('created_at', ascending: false)
        .limit(params.limit)
        .timeout(const Duration(seconds: 10));

    // Query 2: lines where current user is payer
    final responsePayer = await supabase
        .from('household_settlement_events')
        .select(
            'id, created_at, amount_cents, payer_user_id, participant_user_id, actor_user_id, settlement_note, currency, is_express_netting')
        .eq('household_id', params.householdId)
        .eq('payer_user_id', currentUserId)
        .order('created_at', ascending: false)
        .limit(params.limit)
        .timeout(const Duration(seconds: 10));

    FirebaseCrashlytics.instance.log(
        '[settlement_history] raw response types: participant=${responseParticipant.runtimeType} payer=${responsePayer.runtimeType} household=${params.householdId}');

    final rows = <Map<String, dynamic>>[
      ...(responseParticipant as List).cast<Map<String, dynamic>>(),
      ...(responsePayer as List).cast<Map<String, dynamic>>(),
    ];
    FirebaseCrashlytics.instance.log(
        '[settlement_history] fetched rows=${rows.length} household=${params.householdId}');
    if (rows.isNotEmpty) {
      final sample = rows.first;
      FirebaseCrashlytics.instance.log(
          '[settlement_history] sample created_at=${sample['created_at']} payer=${sample['payer_user_id']} participant=${sample['participant_user_id']} amount=${sample['amount_cents']} currency=${sample['currency']}');
    } else {
      FirebaseCrashlytics.instance.log(
          '[settlement_history] no rows returned for household=${params.householdId}');
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id != null && id.isNotEmpty) {
        byId[id] = row;
      }
    }

    final events = <SettlementEvent>[];
    for (final row in byId.values) {
      final createdAtStr = row['created_at'] as String?;
      final settledAt =
          createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      if (settledAt == null) continue;

      final payerUserId = row['payer_user_id'] as String?;
      final participantUserId = row['participant_user_id'] as String?;
      if (payerUserId == null || payerUserId.isEmpty) continue;
      if (participantUserId == null || participantUserId.isEmpty) continue;

      final currency = (row['currency'] as String? ?? '').toUpperCase();
      final amount = (row['amount_cents'] as int? ?? 0).abs();
      if (amount <= 0) continue;

      final isExpressNetting = row['is_express_netting'] as bool? ?? false;

      events.add(
        SettlementEvent(
          settledAt: settledAt,
          payerUserId: payerUserId,
          participantUserId: participantUserId,
          currency: currency,
          amountCents: amount,
          lineCount: 1,
          splitGroupId: null,
          lines: const <SettlementLine>[],
          settledByUserId: row['actor_user_id'] as String?,
          isExpressNetting: isExpressNetting,
          payerToParticipantCents: 0,
          participantToPayerCents: amount,
          settlementNote: row['settlement_note'] as String?,
        ),
      );
    }

    events.sort((a, b) => b.settledAt.compareTo(a.settledAt));
    final limited =
        params.limit > 0 ? events.take(params.limit).toList() : events;
    FirebaseCrashlytics.instance.log(
        '[settlement_history] aggregated events=${limited.length} household=${params.householdId}');
    return limited;
  } catch (e, st) {
    FirebaseCrashlytics.instance.log(
        '[settlement_history] error household=${params.householdId}: $e\n$st');
    return const <SettlementEvent>[];
  }
});
