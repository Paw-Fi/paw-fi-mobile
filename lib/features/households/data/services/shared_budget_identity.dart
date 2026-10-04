/// Filters that identify one shared-budget row without crossing budget types.
Map<String, String> sharedBudgetIdentityFilters({
  required String householdId,
  required String? budgetType,
  required String? userId,
}) {
  final resolvedType = budgetType ?? 'household';
  if (resolvedType != 'household' && resolvedType != 'personal') {
    throw ArgumentError.value(budgetType, 'budgetType');
  }
  if (householdId.trim().isEmpty) {
    throw ArgumentError.value(householdId, 'householdId');
  }
  if (resolvedType == 'personal' && (userId == null || userId.trim().isEmpty)) {
    throw ArgumentError.value(userId, 'userId');
  }
  return {
    'household_id': householdId,
    'budget_type': resolvedType,
    if (resolvedType == 'personal') 'user_id': userId!,
  };
}

/// Coalesce only edits to the same actor, budget type and native plan.
String sharedBudgetMutationId({
  required String householdId,
  required String userId,
  required String? budgetType,
  required String currency,
  required String period,
}) {
  final filters = sharedBudgetIdentityFilters(
    householdId: householdId,
    budgetType: budgetType,
    userId: userId,
  );
  if (userId.trim().isEmpty) {
    throw ArgumentError.value(userId, 'userId');
  }
  return 'mobile:shared_budget_${userId}_${filters['budget_type']}_${householdId}_${currency.trim().toUpperCase()}_${period.trim()}'
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
}
