import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/goal.dart';
import '../../domain/models/goal_contribution.dart';
import '../../domain/models/goal_summary.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Goals list provider
final goalsListProvider = StateNotifierProvider<GoalsListNotifier, AsyncValue<List<Goal>>>((ref) {
  return GoalsListNotifier(ref);
});

class GoalsListNotifier extends StateNotifier<AsyncValue<List<Goal>>> {
  final Ref ref;

  GoalsListNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadGoals(String userId, {String? householdId, String? category, String? status}) async {
    state = const AsyncValue.loading();

    try {
      final supabase = ref.read(supabaseProvider);

      final queryParams = <String, String>{
        'userId': userId,
        if (householdId != null) 'householdId': householdId,
        if (category != null) 'category': category,
        if (status != null) 'status': status,
      };

      final response = await supabase.functions.invoke(
        'list-goals',
        method: HttpMethod.get,
        queryParameters: queryParams,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final goalsData = data['goals'] as List<dynamic>;
        final goals = goalsData.map((json) => Goal.fromJson(json as Map<String, dynamic>)).toList();
        state = AsyncValue.data(goals);
      } else {
        state = AsyncValue.error('Failed to load goals', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void refresh(String userId, {String? householdId}) {
    loadGoals(userId, householdId: householdId);
  }
}

// Goal summary provider
final goalSummaryProvider = StateNotifierProvider<GoalSummaryNotifier, AsyncValue<GoalSummary>>((ref) {
  return GoalSummaryNotifier(ref);
});

class GoalSummaryNotifier extends StateNotifier<AsyncValue<GoalSummary>> {
  final Ref ref;

  GoalSummaryNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> loadSummary(String userId, {String? householdId}) async {
    state = const AsyncValue.loading();

    try {
      final supabase = ref.read(supabaseProvider);

      final queryParams = <String, String>{
        'userId': userId,
        if (householdId != null) 'householdId': householdId,
      };

      final response = await supabase.functions.invoke(
        'list-goals',
        method: HttpMethod.get,
        queryParameters: queryParams,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final summary = GoalSummary.fromJson(data['summary'] as Map<String, dynamic>);
        state = AsyncValue.data(summary);
      } else {
        state = AsyncValue.error('Failed to load summary', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Create goal provider
final createGoalProvider = StateNotifierProvider<CreateGoalNotifier, AsyncValue<Goal?>>((ref) {
  return CreateGoalNotifier(ref);
});

class CreateGoalNotifier extends StateNotifier<AsyncValue<Goal?>> {
  final Ref ref;

  CreateGoalNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> createGoal({
    required String userId,
    String? householdId,
    required String title,
    required String category,
    required double targetAmount,
    double? currentAmount,
    required String currency,
    required String targetDate,
    String? goalType,
    String? privacyScope,
    String? ownerType,
    String? description,
    String? icon,
    String? idempotencyKey,
  }) async {
    state = const AsyncValue.loading();

    try {
      final supabase = ref.read(supabaseProvider);

      final response = await supabase.functions.invoke(
        'create-goal',
        body: {
          'userId': userId,
          if (householdId != null) 'householdId': householdId,
          'title': title,
          'category': category,
          'targetAmount': targetAmount,
          if (currentAmount != null) 'currentAmount': currentAmount,
          'currency': currency,
          'targetDate': targetDate,
          if (goalType != null) 'goalType': goalType,
          if (privacyScope != null) 'privacyScope': privacyScope,
          if (ownerType != null) 'ownerType': ownerType,
          if (description != null) 'description': description,
          if (icon != null) 'icon': icon,
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final goal = Goal.fromJson(data['goal'] as Map<String, dynamic>);
        state = AsyncValue.data(goal);

        // Refresh goals list
        ref.read(goalsListProvider.notifier).refresh(userId, householdId: householdId);
        ref.read(goalSummaryProvider.notifier).loadSummary(userId, householdId: householdId);
      } else {
        state = AsyncValue.error('Failed to create goal', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Add contribution provider
final addContributionProvider = StateNotifierProvider<AddContributionNotifier, AsyncValue<GoalContribution?>>((ref) {
  return AddContributionNotifier(ref);
});

class AddContributionNotifier extends StateNotifier<AsyncValue<GoalContribution?>> {
  final Ref ref;

  AddContributionNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> addContribution({
    required String userId,
    required String goalId,
    required double amount,
    required String currency,
    required String contributionType,
    String? source,
    String? note,
    List<String>? attachmentUrls,
    String? contributionDate,
    String? privacyScope,
    String? ownerType,
    String? idempotencyKey,
    String? householdId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final supabase = ref.read(supabaseProvider);

      final response = await supabase.functions.invoke(
        'add-contribution',
        body: {
          'userId': userId,
          'goalId': goalId,
          'amount': amount,
          'currency': currency,
          'contributionType': contributionType,
          if (source != null) 'source': source,
          if (note != null) 'note': note,
          if (attachmentUrls != null) 'attachmentUrls': attachmentUrls,
          if (contributionDate != null) 'contributionDate': contributionDate,
          if (privacyScope != null) 'privacyScope': privacyScope,
          if (ownerType != null) 'ownerType': ownerType,
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final contribution = GoalContribution.fromJson(data['contribution'] as Map<String, dynamic>);
        state = AsyncValue.data(contribution);

        // Refresh goals list and summary
        ref.read(goalsListProvider.notifier).refresh(userId, householdId: householdId);
        ref.read(goalSummaryProvider.notifier).loadSummary(userId, householdId: householdId);
      } else {
        state = AsyncValue.error('Failed to add contribution', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Acknowledge goal provider
final acknowledgeGoalProvider = StateNotifierProvider<AcknowledgeGoalNotifier, AsyncValue<bool>>((ref) {
  return AcknowledgeGoalNotifier(ref);
});

class AcknowledgeGoalNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;

  AcknowledgeGoalNotifier(this.ref) : super(const AsyncValue.data(false));

  Future<void> acknowledgeGoal(String userId, String goalId, {String? householdId}) async {
    state = const AsyncValue.loading();

    try {
      final supabase = ref.read(supabaseProvider);

      final response = await supabase.functions.invoke(
        'acknowledge-goal',
        body: {
          'userId': userId,
          'goalId': goalId,
        },
      );

      if (response.status == 200) {
        state = const AsyncValue.data(true);

        // Optimistically update the goals list
        final currentState = ref.read(goalsListProvider);
        currentState.whenData((goals) {
          final updatedGoals = goals.map((goal) {
            if (goal.id == goalId) {
              return goal.copyWith(
                acknowledgedBy: [...goal.acknowledgedBy, userId],
                isAcknowledged: true,
              );
            }
            return goal;
          }).toList();
          ref.read(goalsListProvider.notifier).state = AsyncValue.data(updatedGoals);
        });
      } else {
        state = AsyncValue.error('Failed to acknowledge goal', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
