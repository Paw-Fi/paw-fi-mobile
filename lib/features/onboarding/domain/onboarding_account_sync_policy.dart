bool hasMeaningfulOnboardingData({
  required bool hasExpenses,
  required bool hasBudgetAmounts,
  required bool hasBudgetEnvelopes,
  required bool hasHouseholdMembership,
}) {
  return hasExpenses ||
      hasBudgetAmounts ||
      hasBudgetEnvelopes ||
      hasHouseholdMembership;
}

bool shouldCreateStarterBudget({
  required bool forceSync,
  required bool hasExistingBudgetPockets,
}) {
  return forceSync || !hasExistingBudgetPockets;
}
