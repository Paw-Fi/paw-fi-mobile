import '../../domain/repositories/household_repository.dart';
import '../../domain/entities/household.dart';
import '../../domain/entities/household_summary.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/shared_budget.dart';
import '../services/household_service.dart';

/// Implementation of household repository using Supabase
class HouseholdRepositoryImpl implements HouseholdRepository {
  final HouseholdService _service;

  HouseholdRepositoryImpl(this._service);

  @override
  Future<List<Household>> getUserHouseholds(String userId) async {
    final data = await _service.getUserHouseholds(userId);
    return data.map((json) => Household.fromJson(json)).toList();
  }

  @override
  Future<Household?> getHousehold(String householdId) async {
    final data = await _service.getHousehold(householdId);
    return data != null ? Household.fromJson(data) : null;
  }

  @override
  Future<Household> createHousehold({
    required String name,
    required String currency,
    String? coverImageUrl,
    String? themeColor,
    bool isPortfolio = false,
  }) async {
    final data = await _service.createHousehold(
      name: name,
      currency: currency,
      coverImageUrl: coverImageUrl,
      themeColor: themeColor,
      isPortfolio: isPortfolio,
    );
    return Household.fromJson(data);
  }

  @override
  Future<Household> updateHousehold({
    required String householdId,
    String? name,
    String? coverImageUrl,
    String? themeColor,
  }) async {
    final data = await _service.updateHousehold(
      householdId: householdId,
      name: name,
      coverImageUrl: coverImageUrl,
      themeColor: themeColor,
    );
    return Household.fromJson(data);
  }

  @override
  Future<void> deleteHousehold(String householdId) async {
    await _service.deleteHousehold(householdId);
  }

  @override
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId) async {
    final data = await _service.getHouseholdMembers(householdId);
    return data.map((json) => HouseholdMember.fromJson(json)).toList();
  }

  @override
  Future<void> removeMember(String memberId) async {
    await _service.removeMember(memberId);
  }

  @override
  Future<void> updateMemberRole(String memberId, HouseholdRole role) async {
    await _service.updateMemberRole(memberId, role.name);
  }

  @override
  Future<void> leaveHousehold(String householdId) async {
    await _service.leaveHousehold(householdId);
  }

  @override
  Future<List<HouseholdInvite>> getHouseholdInvites(String householdId) async {
    final data = await _service.getHouseholdInvites(householdId);
    return data.map((json) => HouseholdInvite.fromJson(json)).toList();
  }

  @override
  Future<String> createInvite({
    required String householdId,
    String? invitedEmail,
    String? personalMessage,
    String? inviterName,
    String? householdName,
    int expiresInDays = 7,
  }) async {
    return await _service.createInvite(
      householdId: householdId,
      invitedEmail: invitedEmail,
      personalMessage: personalMessage,
      inviterName: inviterName,
      householdName: householdName,
      expiresInDays: expiresInDays,
    );
  }

  @override
  Future<Map<String, dynamic>> validateInvite(String token) async {
    return await _service.validateInvite(token);
  }

  @override
  Future<Map<String, dynamic>> acceptInvite(String token) async {
    return await _service.acceptInvite(token);
  }

  @override
  Future<void> revokeInvite({String? inviteId, String? token}) async {
    await _service.revokeInvite(inviteId: inviteId, token: token);
  }

  @override
  Future<List<ExpenseSplitGroup>> getHouseholdSplits({
    required String householdId,
    String? startDate,
    String? endDate,
  }) async {
    final data = await _service.getHouseholdSplits(
      householdId: householdId,
      startDate: startDate,
      endDate: endDate,
    );
    return data.map((json) => ExpenseSplitGroup.fromJson(json)).toList();
  }

  @override
  Future<Map<String, dynamic>> computeSplit(SplitRequest request) async {
    return await _service.computeSplit(request.toJson());
  }

  @override
  Future<List<SharedBudget>> getHouseholdBudgets(String householdId) async {
    final data = await _service.getHouseholdBudgets(householdId);
    return data.map((json) => SharedBudget.fromJson(json)).toList();
  }

  @override
  Future<SharedBudget> createBudget({
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
    final data = await _service.createBudget(
      householdId: householdId,
      name: name,
      period: period,
      currency: currency,
      amountCents: amountCents,
      warnThreshold: warnThreshold,
      alertThreshold: alertThreshold,
      budgetType: budgetType,
      countSplitPortionOnly: countSplitPortionOnly,
    );
    return SharedBudget.fromJson(data);
  }

  @override
  Future<SharedBudget> updateBudget({
    required String budgetId,
    String? name,
    int? amountCents,
    double? warnThreshold,
    double? alertThreshold,
    bool? isActive,
  }) async {
    final data = await _service.updateBudget(
      budgetId: budgetId,
      name: name,
      amountCents: amountCents,
      warnThreshold: warnThreshold,
      alertThreshold: alertThreshold,
      isActive: isActive,
    );
    return SharedBudget.fromJson(data);
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    await _service.deleteBudget(budgetId);
  }

  @override
  Future<SharingPreferences?> getSharingPreferences({
    required String userId,
    required String householdId,
  }) async {
    final data = await _service.getSharingPreferences(
      userId: userId,
      householdId: householdId,
    );
    return data != null ? SharingPreferences.fromJson(data) : null;
  }

  @override
  Future<SharingPreferences> updateSharingPreferences({
    required String userId,
    required String householdId,
    ShareScope? defaultTransactionShareScope,
    ShareScope? defaultAccountShareScope,
    Map<String, String>? perCategoryOverrides,
    bool? enableNudges,
    String? nudgeQuietHoursStart,
    String? nudgeQuietHoursEnd,
  }) async {
    final data = await _service.upsertSharingPreferences(
      userId: userId,
      householdId: householdId,
      defaultTransactionShareScope: defaultTransactionShareScope?.name,
      defaultAccountShareScope: defaultAccountShareScope?.name,
      perCategoryOverrides: perCategoryOverrides,
      enableNudges: enableNudges,
      nudgeQuietHoursStart: nudgeQuietHoursStart,
      nudgeQuietHoursEnd: nudgeQuietHoursEnd,
    );
    return SharingPreferences.fromJson(data);
  }

  @override
  Future<HouseholdSummary> getHouseholdSummary({
    required String householdId,
    required String currency,
    String? startDate,
    String? endDate,
  }) async {
    final data = await _service.getHouseholdSummary(
      householdId: householdId,
      currency: currency,
      startDate: startDate,
      endDate: endDate,
    );
    return HouseholdSummary.fromJson(data);
  }

  @override
  Stream<List<HouseholdMember>>? watchHouseholdMembers(String householdId) {
    return _service.watchHouseholdMembers(householdId).map(
        (data) => data.map((json) => HouseholdMember.fromJson(json)).toList());
  }

  @override
  Stream<List<HouseholdInvite>>? watchHouseholdInvites(String householdId) {
    return _service.watchHouseholdInvites(householdId).map(
        (data) => data.map((json) => HouseholdInvite.fromJson(json)).toList());
  }

  @override
  Stream<List<SharedBudget>>? watchHouseholdBudgets(String householdId) {
    return _service.watchHouseholdBudgets(householdId).map(
        (data) => data.map((json) => SharedBudget.fromJson(json)).toList());
  }
}
