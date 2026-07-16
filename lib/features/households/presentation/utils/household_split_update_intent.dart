bool shouldSendHouseholdSplitPayerMutation({
  required bool isSharedSpace,
  required bool hasExistingSplitGroup,
  required bool staysInSameSharedHousehold,
  required bool payerChangedByUser,
}) {
  if (!isSharedSpace) return false;
  return !hasExistingSplitGroup ||
      !staysInSameSharedHousehold ||
      payerChangedByUser;
}

bool isExplicitHouseholdReSplitRequested({
  required bool splitChangedByUser,
  bool payerChangedByUser = false,
}) {
  return splitChangedByUser || payerChangedByUser;
}

String? resolveHouseholdPayerAfterMemberLoad({
  required String? currentPayerUserId,
  required List<String> currentMemberUserIds,
  required bool isNewExpense,
  required bool hasExistingSplitGroup,
}) {
  if (currentPayerUserId != null &&
      currentMemberUserIds.contains(currentPayerUserId)) {
    return currentPayerUserId;
  }

  // Existing split groups may legitimately retain a payer who later left the
  // household. Keep that identity until the stored group finishes loading;
  // an explicit payer change remains available in the editor.
  if (!isNewExpense &&
      hasExistingSplitGroup &&
      currentPayerUserId != null &&
      currentPayerUserId.isNotEmpty) {
    return currentPayerUserId;
  }

  return currentMemberUserIds.isEmpty ? null : currentMemberUserIds.first;
}
