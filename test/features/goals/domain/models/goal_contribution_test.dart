import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/goals/domain/models/goal_contribution.dart';

void main() {
  group('GoalContribution - Model Creation', () {
    test('creates goal contribution with all fields', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        householdId: 'household_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        normalizedAmount: 100.0,
        fxRate: 1.0,
        baseCurrency: 'USD',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: ['user_1', 'user_2'],
        source: 'manual',
        note: 'Monthly savings',
        attachmentUrls: ['https://example.com/receipt.pdf'],
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
        isOwner: true,
        isAcknowledged: true,
        privacyRedacted: false,
      );

      expect(contribution.id, 'contrib_123');
      expect(contribution.goalId, 'goal_1');
      expect(contribution.userId, 'user_1');
      expect(contribution.householdId, 'household_1');
      expect(contribution.amount, 100.0);
      expect(contribution.currency, 'USD');
      expect(contribution.contributionType, 'contribution');
      expect(contribution.normalizedAmount, 100.0);
      expect(contribution.fxRate, 1.0);
      expect(contribution.baseCurrency, 'USD');
      expect(contribution.privacyScope, 'full');
      expect(contribution.ownerType, 'me');
      expect(contribution.acknowledgedBy, ['user_1', 'user_2']);
      expect(contribution.source, 'manual');
      expect(contribution.note, 'Monthly savings');
      expect(contribution.attachmentUrls, ['https://example.com/receipt.pdf']);
      expect(contribution.contributionDate, DateTime(2024, 1, 15));
      expect(contribution.isOwner, true);
      expect(contribution.isAcknowledged, true);
      expect(contribution.privacyRedacted, false);
    });

    test('creates goal contribution with null optional fields', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        householdId: null,
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        normalizedAmount: null,
        fxRate: null,
        baseCurrency: null,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        note: null,
        attachmentUrls: null,
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.householdId, null);
      expect(contribution.normalizedAmount, null);
      expect(contribution.fxRate, null);
      expect(contribution.baseCurrency, null);
      expect(contribution.note, null);
      expect(contribution.attachmentUrls, null);
      expect(contribution.isOwner, false);
      expect(contribution.isAcknowledged, false);
      expect(contribution.privacyRedacted, false);
    });
  });

  group('GoalContribution - Contribution Types', () {
    test('identifies contribution type correctly', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.isContribution, true);
      expect(contribution.isWithdrawal, false);
      expect(contribution.isInterest, false);
      expect(contribution.isAdjustment, false);
    });

    test('identifies withdrawal type correctly', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: -50.0,
        currency: 'USD',
        contributionType: 'withdrawal',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.isContribution, false);
      expect(contribution.isWithdrawal, true);
      expect(contribution.isInterest, false);
      expect(contribution.isAdjustment, false);
    });

    test('identifies interest type correctly', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 5.0,
        currency: 'USD',
        contributionType: 'interest',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'automatic',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.isContribution, false);
      expect(contribution.isWithdrawal, false);
      expect(contribution.isInterest, true);
      expect(contribution.isAdjustment, false);
    });

    test('identifies adjustment type correctly', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 10.0,
        currency: 'USD',
        contributionType: 'adjustment',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.isContribution, false);
      expect(contribution.isWithdrawal, false);
      expect(contribution.isInterest, false);
      expect(contribution.isAdjustment, true);
    });
  });

  group('GoalContribution - JSON Serialization', () {
    test('fromJson parses goal contribution correctly', () {
      final json = {
        'id': 'contrib_123',
        'goal_id': 'goal_1',
        'user_id': 'user_1',
        'household_id': 'household_1',
        'amount_cents': 10000,
        'currency': 'USD',
        'contribution_type': 'contribution',
        'normalized_amount_cents': 10000,
        'fx_rate': 1.0,
        'base_currency': 'USD',
        'privacy_scope': 'full',
        'owner_type': 'me',
        'acknowledged_by': ['user_1', 'user_2'],
        'source': 'manual',
        'note': 'Monthly savings',
        'attachment_urls': ['https://example.com/receipt.pdf'],
        'contribution_date': '2024-01-15',
        'created_at': '2024-01-15T10:00:00Z',
        'updated_at': '2024-01-15T11:00:00Z',
        'isOwner': true,
        'isAcknowledged': true,
        'privacyRedacted': false,
      };

      final contribution = GoalContribution.fromJson(json);

      expect(contribution.id, 'contrib_123');
      expect(contribution.goalId, 'goal_1');
      expect(contribution.userId, 'user_1');
      expect(contribution.householdId, 'household_1');
      expect(contribution.amount, 100.0);
      expect(contribution.currency, 'USD');
      expect(contribution.contributionType, 'contribution');
      expect(contribution.normalizedAmount, 100.0);
      expect(contribution.fxRate, 1.0);
      expect(contribution.baseCurrency, 'USD');
      expect(contribution.privacyScope, 'full');
      expect(contribution.ownerType, 'me');
      expect(contribution.acknowledgedBy, ['user_1', 'user_2']);
      expect(contribution.source, 'manual');
      expect(contribution.note, 'Monthly savings');
      expect(contribution.attachmentUrls, ['https://example.com/receipt.pdf']);
      expect(contribution.isOwner, true);
      expect(contribution.isAcknowledged, true);
      expect(contribution.privacyRedacted, false);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'contrib_123',
        'goal_id': 'goal_1',
        'user_id': 'user_1',
        'household_id': null,
        'amount_cents': 10000,
        'currency': 'USD',
        'contribution_type': 'contribution',
        'normalized_amount_cents': null,
        'fx_rate': null,
        'base_currency': null,
        'privacy_scope': null,
        'owner_type': null,
        'acknowledged_by': null,
        'source': null,
        'note': null,
        'attachment_urls': null,
        'contribution_date': '2024-01-15',
        'created_at': '2024-01-15T10:00:00Z',
        'updated_at': '2024-01-15T11:00:00Z',
        'isOwner': null,
        'isAcknowledged': null,
        'privacyRedacted': null,
      };

      final contribution = GoalContribution.fromJson(json);

      expect(contribution.householdId, null);
      expect(contribution.normalizedAmount, null);
      expect(contribution.fxRate, null);
      expect(contribution.baseCurrency, null);
      expect(contribution.privacyScope, 'full');
      expect(contribution.ownerType, 'me');
      expect(contribution.acknowledgedBy, []);
      expect(contribution.source, 'manual');
      expect(contribution.note, null);
      expect(contribution.attachmentUrls, null);
      expect(contribution.isOwner, false);
      expect(contribution.isAcknowledged, false);
      expect(contribution.privacyRedacted, false);
    });

    test('fromJson converts cents to dollars correctly', () {
      final json = {
        'id': 'contrib_123',
        'goal_id': 'goal_1',
        'user_id': 'user_1',
        'amount_cents': 12345,
        'currency': 'USD',
        'contribution_type': 'contribution',
        'normalized_amount_cents': 12345,
        'privacy_scope': 'full',
        'owner_type': 'me',
        'acknowledged_by': [],
        'source': 'manual',
        'contribution_date': '2024-01-15',
        'created_at': '2024-01-15T10:00:00Z',
        'updated_at': '2024-01-15T11:00:00Z',
      };

      final contribution = GoalContribution.fromJson(json);

      expect(contribution.amount, 123.45);
      expect(contribution.normalizedAmount, 123.45);
    });

    test('toJson serializes goal contribution correctly', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        householdId: 'household_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        normalizedAmount: 100.0,
        fxRate: 1.0,
        baseCurrency: 'USD',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: ['user_1', 'user_2'],
        source: 'manual',
        note: 'Monthly savings',
        attachmentUrls: ['https://example.com/receipt.pdf'],
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
        isOwner: true,
        isAcknowledged: true,
        privacyRedacted: false,
      );

      final json = contribution.toJson();

      expect(json['id'], 'contrib_123');
      expect(json['goal_id'], 'goal_1');
      expect(json['user_id'], 'user_1');
      expect(json['household_id'], 'household_1');
      expect(json['amount_cents'], 10000);
      expect(json['currency'], 'USD');
      expect(json['contribution_type'], 'contribution');
      expect(json['normalized_amount_cents'], 10000);
      expect(json['fx_rate'], 1.0);
      expect(json['base_currency'], 'USD');
      expect(json['privacy_scope'], 'full');
      expect(json['owner_type'], 'me');
      expect(json['acknowledged_by'], ['user_1', 'user_2']);
      expect(json['source'], 'manual');
      expect(json['note'], 'Monthly savings');
      expect(json['attachment_urls'], ['https://example.com/receipt.pdf']);
      expect(json['contribution_date'], '2024-01-15');
      expect(json['isOwner'], true);
      expect(json['isAcknowledged'], true);
      expect(json['privacyRedacted'], false);
    });

    test('toJson converts dollars to cents correctly', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 123.45,
        currency: 'USD',
        contributionType: 'contribution',
        normalizedAmount: 123.45,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      final json = contribution.toJson();

      expect(json['amount_cents'], 12345);
      expect(json['normalized_amount_cents'], 12345);
    });

    test('toJson formats contribution_date as date only', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15, 14, 30, 45),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      final json = contribution.toJson();

      expect(json['contribution_date'], '2024-01-15');
    });
  });

  group('GoalContribution - Edge Cases', () {
    test('handles zero amount', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 0.0,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.amount, 0.0);
    });

    test('handles negative amount for withdrawal', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: -100.0,
        currency: 'USD',
        contributionType: 'withdrawal',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.amount, -100.0);
      expect(contribution.isWithdrawal, true);
    });

    test('handles very large amounts', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 999999.99,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.amount, 999999.99);
    });

    test('handles various currency codes', () {
      final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CNY'];

      for (final currency in currencies) {
        final contribution = GoalContribution(
          id: 'contrib_123',
          goalId: 'goal_1',
          userId: 'user_1',
          amount: 100.0,
          currency: currency,
          contributionType: 'contribution',
          privacyScope: 'full',
          ownerType: 'me',
          acknowledgedBy: [],
          source: 'manual',
          contributionDate: DateTime(2024, 1, 15),
          createdAt: DateTime(2024, 1, 15, 10, 0),
          updatedAt: DateTime(2024, 1, 15, 11, 0),
        );

        expect(contribution.currency, currency);
      }
    });

    test('handles various source types', () {
      final sources = ['manual', 'automatic', 'recurring', 'interest'];

      for (final source in sources) {
        final contribution = GoalContribution(
          id: 'contrib_123',
          goalId: 'goal_1',
          userId: 'user_1',
          amount: 100.0,
          currency: 'USD',
          contributionType: 'contribution',
          privacyScope: 'full',
          ownerType: 'me',
          acknowledgedBy: [],
          source: source,
          contributionDate: DateTime(2024, 1, 15),
          createdAt: DateTime(2024, 1, 15, 10, 0),
          updatedAt: DateTime(2024, 1, 15, 11, 0),
        );

        expect(contribution.source, source);
      }
    });

    test('handles multiple acknowledged users', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: ['user_1', 'user_2', 'user_3', 'user_4'],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.acknowledgedBy.length, 4);
    });

    test('handles multiple attachment URLs', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        attachmentUrls: [
          'https://example.com/receipt1.pdf',
          'https://example.com/receipt2.pdf',
          'https://example.com/receipt3.pdf',
        ],
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.attachmentUrls!.length, 3);
    });

    test('handles FX rate conversion', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 100.0,
        currency: 'EUR',
        contributionType: 'contribution',
        normalizedAmount: 110.0,
        fxRate: 1.1,
        baseCurrency: 'USD',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.amount, 100.0);
      expect(contribution.normalizedAmount, 110.0);
      expect(contribution.fxRate, 1.1);
      expect(contribution.baseCurrency, 'USD');
    });

    test('handles privacy redaction', () {
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'household',
        ownerType: 'household',
        acknowledgedBy: [],
        source: 'manual',
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
        privacyRedacted: true,
      );

      expect(contribution.privacyRedacted, true);
    });

    test('handles long notes', () {
      final longNote = 'This is a very long note ' * 50;
      final contribution = GoalContribution(
        id: 'contrib_123',
        goalId: 'goal_1',
        userId: 'user_1',
        amount: 100.0,
        currency: 'USD',
        contributionType: 'contribution',
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        source: 'manual',
        note: longNote,
        contributionDate: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 15, 11, 0),
      );

      expect(contribution.note, longNote);
    });
  });
}
