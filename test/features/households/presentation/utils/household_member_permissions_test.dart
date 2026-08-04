import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/utils/household_member_permissions.dart';

void main() {
  test('only owners and admins can manage members and create invitations', () {
    expect(
      canManageHouseholdMembers(
        currentUserId: 'owner',
        currentUserMember: _member('owner', HouseholdRole.owner),
      ),
      isTrue,
    );
    expect(
      canManageHouseholdMembers(
        currentUserId: 'admin',
        currentUserMember: _member('admin', HouseholdRole.admin),
      ),
      isTrue,
    );
    expect(
      canManageHouseholdMembers(
        currentUserId: 'member',
        currentUserMember: _member('member', HouseholdRole.member),
      ),
      isFalse,
    );
  });

  test('admin can manage members but cannot manage owner or another admin', () {
    expect(
      canManageHouseholdMember(
        currentUserRole: HouseholdRole.admin,
        currentUserId: 'admin_1',
        member: _member('member', HouseholdRole.member),
      ),
      isTrue,
    );
    expect(
      canManageHouseholdMember(
        currentUserRole: HouseholdRole.admin,
        currentUserId: 'admin_1',
        member: _member('admin_2', HouseholdRole.admin),
      ),
      isFalse,
    );
    expect(
      canManageHouseholdMember(
        currentUserRole: HouseholdRole.admin,
        currentUserId: 'admin_1',
        member: _member('owner', HouseholdRole.owner),
      ),
      isFalse,
    );
  });

  test('an invite can be revoked by an admin or the original inviter', () {
    final invite = _invite(inviterId: 'inviter');

    expect(
      canRevokeHouseholdInvite(
        canManageMembers: true,
        invite: invite,
        currentUserId: 'admin',
      ),
      isTrue,
    );
    expect(
      canRevokeHouseholdInvite(
        canManageMembers: false,
        invite: invite,
        currentUserId: 'inviter',
      ),
      isTrue,
    );
    expect(
      canRevokeHouseholdInvite(
        canManageMembers: false,
        invite: invite,
        currentUserId: 'member',
      ),
      isFalse,
    );
  });
}

HouseholdMember _member(String userId, HouseholdRole role) {
  final now = DateTime(2026, 1, 1);
  return HouseholdMember(
    id: 'member_$userId',
    householdId: 'household_1',
    userId: userId,
    role: role,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

HouseholdInvite _invite({required String inviterId}) {
  final now = DateTime(2026, 1, 1);
  return HouseholdInvite(
    id: 'invite_1',
    token: 'token',
    householdId: 'household_1',
    inviterId: inviterId,
    status: InviteStatus.pending,
    createdAt: now,
    updatedAt: now,
  );
}
