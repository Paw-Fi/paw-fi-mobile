import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';

void main() {
  test('household owner can edit before member data loads', () {
    expect(
      canEditHouseholdSettings(
        household: _household(ownerId: 'owner'),
        currentUserId: 'owner',
        currentUserMember: null,
      ),
      isTrue,
    );
  });

  test('household admin can edit settings', () {
    expect(
      canEditHouseholdSettings(
        household: _household(ownerId: 'owner'),
        currentUserId: 'admin',
        currentUserMember: _member('admin', HouseholdRole.admin),
      ),
      isTrue,
    );
  });

  test('regular household member cannot edit settings', () {
    expect(
      canEditHouseholdSettings(
        household: _household(ownerId: 'owner'),
        currentUserId: 'member',
        currentUserMember: _member('member', HouseholdRole.member),
      ),
      isFalse,
    );
  });
}

Household _household({required String ownerId}) {
  final now = DateTime(2026, 1, 1);
  return Household(
    id: 'household_1',
    name: 'Home',
    ownerId: ownerId,
    currency: 'USD',
    createdAt: now,
    updatedAt: now,
  );
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
