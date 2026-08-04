import '../../domain/entities/household.dart';

bool canManageHouseholdMembers({
  required String? currentUserId,
  required HouseholdMember? currentUserMember,
}) {
  if (currentUserId == null) return false;

  return currentUserMember?.role == HouseholdRole.owner ||
      currentUserMember?.role == HouseholdRole.admin;
}

bool canManageHouseholdMember({
  required HouseholdRole currentUserRole,
  required HouseholdMember member,
  required String? currentUserId,
}) {
  if (member.userId == currentUserId || member.role == HouseholdRole.owner) {
    return false;
  }

  return currentUserRole == HouseholdRole.owner ||
      (currentUserRole == HouseholdRole.admin &&
          member.role == HouseholdRole.member);
}

bool canRevokeHouseholdInvite({
  required bool canManageMembers,
  required HouseholdInvite invite,
  required String? currentUserId,
}) {
  return canManageMembers || invite.inviterId == currentUserId;
}
