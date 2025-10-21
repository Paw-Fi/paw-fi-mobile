import '../entities/household.dart';
import '../entities/household_summary.dart';
import '../entities/expense_split.dart';
import '../entities/shared_budget.dart';

/// Repository interface for household operations
abstract class HouseholdRepository {
  // Household CRUD
  Future<List<Household>> getUserHouseholds(String userId);
  Future<Household?> getHousehold(String householdId);
  Future<Household> createHousehold({
    required String name,
    String? emoji,
    String? themeColor,
  });
  Future<Household> updateHousehold({
    required String householdId,
    String? name,
    String? emoji,
    String? themeColor,
  });
  Future<void> deleteHousehold(String householdId);

  // Members
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId);
  Future<void> removeMember(String memberId);
  Future<void> updateMemberRole(String memberId, HouseholdRole role);
  Future<void> leaveHousehold(String householdId);

  // Invites
  Future<List<HouseholdInvite>> getHouseholdInvites(String householdId);
  Future<String> createInvite({
    required String householdId,
    String? invitedEmail,
    String? personalMessage,
    int expiresInDays,
  });
  Future<Map<String, dynamic>> validateInvite(String token);
  Future<Map<String, dynamic>> acceptInvite(String token);
  Future<void> revokeInvite({String? inviteId, String? token});

  // Splits
  Future<List<ExpenseSplitGroup>> getHouseholdSplits({
    required String householdId,
    String? startDate,
    String? endDate,
  });
  Future<Map<String, dynamic>> computeSplit(SplitRequest request);
  Future<void> settleSplit(String splitLineId);

  // Budgets
  Future<List<SharedBudget>> getHouseholdBudgets(String householdId);
  Future<SharedBudget> createBudget({
    required String householdId,
    required String name,
    required String period,
    required String currency,
    required int amountCents,
    double? warnThreshold,
    double? alertThreshold,
  });
  Future<SharedBudget> updateBudget({
    required String budgetId,
    String? name,
    int? amountCents,
    double? warnThreshold,
    double? alertThreshold,
    bool? isActive,
  });
  Future<void> deleteBudget(String budgetId);

  // Sharing preferences
  Future<SharingPreferences?> getSharingPreferences({
    required String userId,
    required String householdId,
  });
  Future<SharingPreferences> updateSharingPreferences({
    required String userId,
    required String householdId,
    ShareScope? defaultTransactionShareScope,
    ShareScope? defaultAccountShareScope,
    Map<String, String>? perCategoryOverrides,
    bool? enableNudges,
    String? nudgeQuietHoursStart,
    String? nudgeQuietHoursEnd,
  });

  // Summary
  Future<HouseholdSummary> getHouseholdSummary({
    required String householdId,
    required String currency,
    String? startDate,
    String? endDate,
  });

  // Realtime subscriptions (optional)
  Stream<List<HouseholdMember>>? watchHouseholdMembers(String householdId);
  Stream<List<HouseholdInvite>>? watchHouseholdInvites(String householdId);
  Stream<List<SharedBudget>>? watchHouseholdBudgets(String householdId);
}
