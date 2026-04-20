import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/household.dart';

void main() {
  group('Household - Model Creation', () {
    test('creates household with all required fields', () {
      final now = DateTime(2024, 1, 1);
      final household = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      expect(household.id, 'hh_1');
      expect(household.name, 'Family Budget');
      expect(household.ownerId, 'user_1');
      expect(household.currency, 'USD');
      expect(household.coverImageUrl, null);
      expect(household.themeColor, null);
      expect(household.autoSplitEnabled, isTrue);
      expect(household.autoSplitConfig, isNull);
      expect(household.createdAt, now);
      expect(household.updatedAt, now);
    });

    test('creates household with optional fields', () {
      final now = DateTime(2024, 1, 1);
      final household = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        coverImageUrl: 'https://example.com/image.jpg',
        themeColor: '#FF5733',
        currency: 'EUR',
        createdAt: now,
        updatedAt: now,
      );

      expect(household.coverImageUrl, 'https://example.com/image.jpg');
      expect(household.themeColor, '#FF5733');
      expect(household.currency, 'EUR');
    });
  });

  group('Household - JSON Serialization', () {
    test('fromJson parses household correctly', () {
      final json = {
        'id': 'hh_1',
        'name': 'Family Budget',
        'owner_id': 'user_1',
        'cover_image_url': 'https://example.com/image.jpg',
        'theme_color': '#FF5733',
        'currency': 'usd',
        'ai_use_default_split': false,
        'ai_default_split_config': {
          'splitType': 'shares',
          'memberSplits': [
            {'userId': 'user_1', 'shares': 2},
            {'userId': 'user_2', 'shares': 1},
          ],
        },
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final household = Household.fromJson(json);

      expect(household.id, 'hh_1');
      expect(household.name, 'Family Budget');
      expect(household.ownerId, 'user_1');
      expect(household.coverImageUrl, 'https://example.com/image.jpg');
      expect(household.themeColor, '#FF5733');
      expect(household.currency, 'USD'); // Uppercase conversion
      expect(household.autoSplitEnabled, isFalse);
      expect(household.autoSplitConfig?['splitType'], 'shares');
      expect(household.createdAt, DateTime.utc(2024, 1, 1));
      expect(household.updatedAt, DateTime.utc(2024, 1, 1));
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'hh_1',
        'name': 'Family Budget',
        'owner_id': 'user_1',
        'currency': 'USD',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final household = Household.fromJson(json);

      expect(household.coverImageUrl, null);
      expect(household.themeColor, null);
      expect(household.autoSplitEnabled, isTrue);
      expect(household.autoSplitConfig, isNull);
    });

    test('fromJson converts currency to uppercase', () {
      final json = {
        'id': 'hh_1',
        'name': 'Test',
        'owner_id': 'user_1',
        'currency': 'eur',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final household = Household.fromJson(json);
      expect(household.currency, 'EUR');
    });

    test('toJson serializes household correctly', () {
      final now = DateTime(2024, 1, 1);
      final household = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        coverImageUrl: 'https://example.com/image.jpg',
        themeColor: '#FF5733',
        currency: 'USD',
        autoSplitEnabled: false,
        autoSplitConfig: {
          'splitType': 'percentage',
          'memberSplits': [
            {'userId': 'user_1', 'percentage': 70},
            {'userId': 'user_2', 'percentage': 30},
          ],
        },
        createdAt: now,
        updatedAt: now,
      );

      final json = household.toJson();

      expect(json['id'], 'hh_1');
      expect(json['name'], 'Family Budget');
      expect(json['owner_id'], 'user_1');
      expect(json['cover_image_url'], 'https://example.com/image.jpg');
      expect(json['theme_color'], '#FF5733');
      expect(json['currency'], 'USD');
      expect(json['ai_use_default_split'], isFalse);
      expect(json['ai_default_split_config'], isA<Map<String, dynamic>>());
      expect(json['created_at'], '2024-01-01T00:00:00.000');
      expect(json['updated_at'], '2024-01-01T00:00:00.000');
    });
  });

  group('Household - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      final now = DateTime(2024, 1, 1);
      final original = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        name: 'Updated Budget',
        currency: 'EUR',
        autoSplitEnabled: false,
        autoSplitConfig: {
          'splitType': 'amount',
          'memberSplits': [
            {'userId': 'user_1', 'amount': 2.0},
          ],
        },
      );

      expect(updated.id, 'hh_1');
      expect(updated.name, 'Updated Budget');
      expect(updated.currency, 'EUR');
      expect(updated.autoSplitEnabled, isFalse);
      expect(updated.autoSplitConfig?['splitType'], 'amount');
      expect(updated.ownerId, 'user_1');
    });

    test('copyWith without parameters returns identical values', () {
      final now = DateTime(2024, 1, 1);
      final original = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.ownerId, original.ownerId);
      expect(copy.currency, original.currency);
    });
  });

  group('Household - Equality', () {
    test('households with same values are equal', () {
      final now = DateTime(2024, 1, 1);
      final household1 = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      final household2 = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      expect(household1, equals(household2));
      expect(household1.hashCode, equals(household2.hashCode));
    });

    test('households with different values are not equal', () {
      final now = DateTime(2024, 1, 1);
      final household1 = Household(
        id: 'hh_1',
        name: 'Family Budget',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      final household2 = Household(
        id: 'hh_2',
        name: 'Family Budget',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      );

      expect(household1, isNot(equals(household2)));
    });
  });

  group('HouseholdRole - Enum', () {
    test('toJson returns correct string values', () {
      expect(HouseholdRole.owner.toJson(), 'owner');
      expect(HouseholdRole.admin.toJson(), 'admin');
      expect(HouseholdRole.member.toJson(), 'member');
    });

    test('fromJson parses correct enum values', () {
      expect(HouseholdRole.fromJson('owner'), HouseholdRole.owner);
      expect(HouseholdRole.fromJson('admin'), HouseholdRole.admin);
      expect(HouseholdRole.fromJson('member'), HouseholdRole.member);
    });

    test('fromJson throws on invalid value', () {
      expect(
        () => HouseholdRole.fromJson('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('HouseholdMember - Model Creation', () {
    test('creates member with all required fields', () {
      final now = DateTime(2024, 1, 1);
      final member = HouseholdMember(
        id: 'mem_1',
        householdId: 'hh_1',
        userId: 'user_1',
        role: HouseholdRole.member,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(member.id, 'mem_1');
      expect(member.householdId, 'hh_1');
      expect(member.userId, 'user_1');
      expect(member.role, HouseholdRole.member);
      expect(member.userEmail, null);
      expect(member.userName, null);
      expect(member.avatarUrl, null);
    });

    test('creates member with optional user data', () {
      final now = DateTime(2024, 1, 1);
      final member = HouseholdMember(
        id: 'mem_1',
        householdId: 'hh_1',
        userId: 'user_1',
        role: HouseholdRole.admin,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
        userEmail: 'user@example.com',
        userName: 'John Doe',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      expect(member.userEmail, 'user@example.com');
      expect(member.userName, 'John Doe');
      expect(member.avatarUrl, 'https://example.com/avatar.jpg');
    });
  });

  group('HouseholdMember - JSON Serialization', () {
    test('fromJson parses member correctly', () {
      final json = {
        'id': 'mem_1',
        'household_id': 'hh_1',
        'user_id': 'user_1',
        'role': 'owner',
        'joined_at': '2024-01-01T00:00:00.000Z',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'user_email': 'user@example.com',
        'user_name': 'John Doe',
      };

      final member = HouseholdMember.fromJson(json);

      expect(member.id, 'mem_1');
      expect(member.householdId, 'hh_1');
      expect(member.userId, 'user_1');
      expect(member.role, HouseholdRole.owner);
      expect(member.userEmail, 'user@example.com');
      expect(member.userName, 'John Doe');
    });

    test('fromJson parses nested users object', () {
      final json = {
        'id': 'mem_1',
        'household_id': 'hh_1',
        'user_id': 'user_1',
        'role': 'member',
        'joined_at': '2024-01-01T00:00:00.000Z',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'users': {
          'email': 'nested@example.com',
          'full_name': 'Jane Smith',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      };

      final member = HouseholdMember.fromJson(json);

      expect(member.userEmail, 'nested@example.com');
      expect(member.userName, 'Jane Smith');
      expect(member.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('toJson serializes member correctly', () {
      final now = DateTime(2024, 1, 1);
      final member = HouseholdMember(
        id: 'mem_1',
        householdId: 'hh_1',
        userId: 'user_1',
        role: HouseholdRole.admin,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
        userEmail: 'user@example.com',
        userName: 'John Doe',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      final json = member.toJson();

      expect(json['id'], 'mem_1');
      expect(json['household_id'], 'hh_1');
      expect(json['user_id'], 'user_1');
      expect(json['role'], 'admin');
      expect(json['user_email'], 'user@example.com');
      expect(json['user_name'], 'John Doe');
      expect(json['avatar_url'], 'https://example.com/avatar.jpg');
    });
  });

  group('HouseholdMember - Equality', () {
    test('members with same id are equal', () {
      final now = DateTime(2024, 1, 1);
      final member1 = HouseholdMember(
        id: 'mem_1',
        householdId: 'hh_1',
        userId: 'user_1',
        role: HouseholdRole.member,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final member2 = HouseholdMember(
        id: 'mem_1',
        householdId: 'hh_2',
        userId: 'user_2',
        role: HouseholdRole.admin,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(member1, equals(member2));
      expect(member1.hashCode, equals(member2.hashCode));
    });
  });

  group('InviteStatus - Enum', () {
    test('toJson returns correct string values', () {
      expect(InviteStatus.pending.toJson(), 'pending');
      expect(InviteStatus.accepted.toJson(), 'accepted');
      expect(InviteStatus.revoked.toJson(), 'revoked');
      expect(InviteStatus.expired.toJson(), 'expired');
    });

    test('fromJson parses correct enum values', () {
      expect(InviteStatus.fromJson('pending'), InviteStatus.pending);
      expect(InviteStatus.fromJson('accepted'), InviteStatus.accepted);
      expect(InviteStatus.fromJson('revoked'), InviteStatus.revoked);
      expect(InviteStatus.fromJson('expired'), InviteStatus.expired);
    });

    test('fromJson throws on invalid value', () {
      expect(
        () => InviteStatus.fromJson('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('HouseholdInvite - Model Creation', () {
    test('creates invite with required fields', () {
      final now = DateTime(2024, 1, 1);
      final invite = HouseholdInvite(
        id: 'inv_1',
        token: 'abc123',
        householdId: 'hh_1',
        inviterId: 'user_1',
        status: InviteStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      expect(invite.id, 'inv_1');
      expect(invite.token, 'abc123');
      expect(invite.householdId, 'hh_1');
      expect(invite.inviterId, 'user_1');
      expect(invite.status, InviteStatus.pending);
      expect(invite.invitedUserId, null);
      expect(invite.expiresAt, null);
      expect(invite.acceptedAt, null);
    });

    test('creates invite with all optional fields', () {
      final now = DateTime(2024, 1, 1);
      final expiresAt = DateTime(2024, 1, 7);
      final acceptedAt = DateTime(2024, 1, 2);

      final invite = HouseholdInvite(
        id: 'inv_1',
        token: 'abc123',
        householdId: 'hh_1',
        inviterId: 'user_1',
        invitedUserId: 'user_2',
        status: InviteStatus.accepted,
        expiresAt: expiresAt,
        acceptedAt: acceptedAt,
        invitedEmail: 'invited@example.com',
        personalMessage: 'Join our household!',
        createdAt: now,
        updatedAt: now,
        inviterEmail: 'inviter@example.com',
        householdName: 'Family Budget',
      );

      expect(invite.invitedUserId, 'user_2');
      expect(invite.expiresAt, expiresAt);
      expect(invite.acceptedAt, acceptedAt);
      expect(invite.invitedEmail, 'invited@example.com');
      expect(invite.personalMessage, 'Join our household!');
      expect(invite.inviterEmail, 'inviter@example.com');
      expect(invite.householdName, 'Family Budget');
    });
  });

  group('HouseholdInvite - JSON Serialization', () {
    test('fromJson parses invite correctly', () {
      final json = {
        'id': 'inv_1',
        'token': 'abc123',
        'household_id': 'hh_1',
        'inviter_id': 'user_1',
        'invited_user_id': 'user_2',
        'status': 'accepted',
        'expires_at': '2024-01-07T00:00:00.000Z',
        'accepted_at': '2024-01-02T00:00:00.000Z',
        'invited_email': 'invited@example.com',
        'personal_message': 'Join us!',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'inviter_email': 'inviter@example.com',
        'household_name': 'Family Budget',
      };

      final invite = HouseholdInvite.fromJson(json);

      expect(invite.id, 'inv_1');
      expect(invite.token, 'abc123');
      expect(invite.status, InviteStatus.accepted);
      expect(invite.invitedEmail, 'invited@example.com');
      expect(invite.personalMessage, 'Join us!');
      expect(invite.expiresAt, DateTime.utc(2024, 1, 7));
      expect(invite.acceptedAt, DateTime.utc(2024, 1, 2));
    });

    test('fromJson handles null dates', () {
      final json = {
        'id': 'inv_1',
        'token': 'abc123',
        'household_id': 'hh_1',
        'inviter_id': 'user_1',
        'status': 'pending',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final invite = HouseholdInvite.fromJson(json);

      expect(invite.expiresAt, null);
      expect(invite.acceptedAt, null);
    });

    test('toJson serializes invite correctly', () {
      final now = DateTime(2024, 1, 1);
      final expiresAt = DateTime(2024, 1, 7);

      final invite = HouseholdInvite(
        id: 'inv_1',
        token: 'abc123',
        householdId: 'hh_1',
        inviterId: 'user_1',
        status: InviteStatus.pending,
        expiresAt: expiresAt,
        invitedEmail: 'invited@example.com',
        createdAt: now,
        updatedAt: now,
      );

      final json = invite.toJson();

      expect(json['id'], 'inv_1');
      expect(json['token'], 'abc123');
      expect(json['status'], 'pending');
      expect(json['expires_at'], '2024-01-07T00:00:00.000');
      expect(json['invited_email'], 'invited@example.com');
    });

    test('toJson handles null expiresAt correctly', () {
      final now = DateTime(2024, 1, 1);

      final invite = HouseholdInvite(
        id: 'inv_1',
        token: 'abc123',
        householdId: 'hh_1',
        inviterId: 'user_1',
        status: InviteStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final json = invite.toJson();

      expect(json.containsKey('expires_at'), false);
    });
  });

  group('HouseholdInvite - Equality', () {
    test('invites with same id are equal', () {
      final now = DateTime(2024, 1, 1);
      final invite1 = HouseholdInvite(
        id: 'inv_1',
        token: 'abc123',
        householdId: 'hh_1',
        inviterId: 'user_1',
        status: InviteStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final invite2 = HouseholdInvite(
        id: 'inv_1',
        token: 'xyz789',
        householdId: 'hh_2',
        inviterId: 'user_2',
        status: InviteStatus.accepted,
        createdAt: now,
        updatedAt: now,
      );

      expect(invite1, equals(invite2));
      expect(invite1.hashCode, equals(invite2.hashCode));
    });
  });
}
