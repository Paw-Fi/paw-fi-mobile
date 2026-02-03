import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/utils/payer_resolver.dart';
import 'package:moneko/features/households/domain/entities/household.dart';

void main() {
  group('resolveHouseholdPayerUserIdFromHint', () {
    final members = <HouseholdMember>[
      HouseholdMember(
        id: 'm1',
        householdId: 'h1',
        userId: 'user_alice',
        role: HouseholdRole.member,
        joinedAt: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        userEmail: 'alice@example.com',
        userName: 'Alice Johnson',
      ),
      HouseholdMember(
        id: 'm2',
        householdId: 'h1',
        userId: 'user_bob',
        role: HouseholdRole.member,
        joinedAt: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        userEmail: 'bob@example.com',
        userName: 'Bob Smith',
      ),
    ];

    test('matches by exact email', () {
      final id = resolveHouseholdPayerUserIdFromHint(
        members: members,
        hint: 'bob@example.com',
      );
      expect(id, 'user_bob');
    });

    test('matches by full name (case-insensitive)', () {
      final id = resolveHouseholdPayerUserIdFromHint(
        members: members,
        hint: 'bob smith',
      );
      expect(id, 'user_bob');
    });

    test('matches by first name', () {
      final id = resolveHouseholdPayerUserIdFromHint(
        members: members,
        hint: 'Alice',
      );
      expect(id, 'user_alice');
    });

    test('strips leading "paid by"', () {
      final id = resolveHouseholdPayerUserIdFromHint(
        members: members,
        hint: 'paid by Bob',
      );
      expect(id, 'user_bob');
    });

    test('returns null when no match', () {
      final id = resolveHouseholdPayerUserIdFromHint(
        members: members,
        hint: 'Charlie',
      );
      expect(id, null);
    });
  });
}
