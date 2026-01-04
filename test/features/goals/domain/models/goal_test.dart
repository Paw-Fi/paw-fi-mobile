import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/goals/domain/models/goal.dart';

void main() {
  group('Goal - Model Creation', () {
    test('creates goal with all required fields', () {
      final now = DateTime(2024, 1, 1);
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Emergency Fund',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 5000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 50.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: now,
        updatedAt: now,
      );

      expect(goal.id, 'goal_1');
      expect(goal.userId, 'user_1');
      expect(goal.title, 'Emergency Fund');
      expect(goal.goalType, 'savings');
      expect(goal.category, 'savings');
      expect(goal.targetAmount, 10000.0);
      expect(goal.currentAmount, 5000.0);
      expect(goal.currency, 'USD');
      expect(goal.status, 'active');
      expect(goal.progressPercentage, 50.0);
      expect(goal.isOnTrack, true);
      expect(goal.isOwner, false);
      expect(goal.isAcknowledged, false);
      expect(goal.privacyRedacted, false);
    });

    test('creates goal with all optional fields', () {
      final now = DateTime(2024, 1, 1);
      final completed = DateTime(2024, 6, 1);
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        householdId: 'hh_1',
        title: 'Vacation Fund',
        description: 'Save for summer vacation',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 5000.0,
        currentAmount: 5000.0,
        currency: 'USD',
        targetDate: '2024-06-01',
        startDate: '2024-01-01',
        status: 'completed',
        progressPercentage: 100.0,
        isOnTrack: true,
        privacyScope: 'private',
        ownerType: 'household',
        acknowledgedBy: ['user_1', 'user_2'],
        baseCurrency: 'EUR',
        fxRate: 0.9,
        normalizedTargetAmount: 4500.0,
        normalizedCurrentAmount: 4500.0,
        icon: '🏖️',
        createdAt: now,
        updatedAt: now,
        completedAt: completed,
        isOwner: true,
        isAcknowledged: true,
        privacyRedacted: false,
      );

      expect(goal.householdId, 'hh_1');
      expect(goal.description, 'Save for summer vacation');
      expect(goal.baseCurrency, 'EUR');
      expect(goal.fxRate, 0.9);
      expect(goal.normalizedTargetAmount, 4500.0);
      expect(goal.normalizedCurrentAmount, 4500.0);
      expect(goal.icon, '🏖️');
      expect(goal.completedAt, completed);
      expect(goal.isOwner, true);
      expect(goal.isAcknowledged, true);
      expect(goal.acknowledgedBy.length, 2);
    });
  });

  group('Goal - JSON Serialization', () {
    test('fromJson parses goal correctly', () {
      final json = {
        'id': 'goal_1',
        'user_id': 'user_1',
        'household_id': 'hh_1',
        'title': 'Emergency Fund',
        'description': 'Save for emergencies',
        'goal_type': 'savings',
        'category': 'savings',
        'target_amount': 10000.0,
        'current_amount': 5000.0,
        'currency': 'USD',
        'target_date': '2024-12-31',
        'start_date': '2024-01-01',
        'status': 'active',
        'progress_percentage': 50.0,
        'is_on_track': true,
        'privacy_scope': 'full',
        'owner_type': 'me',
        'acknowledged_by': ['user_1', 'user_2'],
        'base_currency': 'EUR',
        'fx_rate': 0.9,
        'normalized_target_amount': 900000,
        'normalized_current_amount': 450000,
        'icon': '💰',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'completed_at': '2024-06-01T00:00:00.000Z',
        'isOwner': true,
        'isAcknowledged': true,
        'privacyRedacted': false,
      };

      final goal = Goal.fromJson(json);

      expect(goal.id, 'goal_1');
      expect(goal.userId, 'user_1');
      expect(goal.householdId, 'hh_1');
      expect(goal.title, 'Emergency Fund');
      expect(goal.description, 'Save for emergencies');
      expect(goal.goalType, 'savings');
      expect(goal.category, 'savings');
      expect(goal.targetAmount, 10000.0);
      expect(goal.currentAmount, 5000.0);
      expect(goal.currency, 'USD');
      expect(goal.targetDate, '2024-12-31');
      expect(goal.startDate, '2024-01-01');
      expect(goal.status, 'active');
      expect(goal.progressPercentage, 50.0);
      expect(goal.isOnTrack, true);
      expect(goal.privacyScope, 'full');
      expect(goal.ownerType, 'me');
      expect(goal.acknowledgedBy, ['user_1', 'user_2']);
      expect(goal.baseCurrency, 'EUR');
      expect(goal.fxRate, 0.9);
      expect(goal.normalizedTargetAmount, 9000.0);
      expect(goal.normalizedCurrentAmount, 4500.0);
      expect(goal.icon, '💰');
      expect(goal.createdAt, DateTime.utc(2024, 1, 1));
      expect(goal.updatedAt, DateTime.utc(2024, 1, 1));
      expect(goal.completedAt, DateTime.utc(2024, 6, 1));
      expect(goal.isOwner, true);
      expect(goal.isAcknowledged, true);
      expect(goal.privacyRedacted, false);
    });

    test('fromJson handles default values', () {
      final json = {
        'id': 'goal_1',
        'user_id': 'user_1',
        'title': 'Goal',
        'goal_type': 'savings',
        'category': 'savings',
        'target_amount': 1000.0,
        'current_amount': 0.0,
        'currency': 'USD',
        'target_date': '2024-12-31',
        'start_date': '2024-01-01',
        'status': 'active',
        'progress_percentage': 0.0,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final goal = Goal.fromJson(json);

      expect(goal.isOnTrack, false);
      expect(goal.privacyScope, 'full');
      expect(goal.ownerType, 'me');
      expect(goal.acknowledgedBy, []);
      expect(goal.isOwner, false);
      expect(goal.isAcknowledged, false);
      expect(goal.privacyRedacted, false);
    });

    test('fromJson handles null normalized amounts', () {
      final json = {
        'id': 'goal_1',
        'user_id': 'user_1',
        'title': 'Goal',
        'goal_type': 'savings',
        'category': 'savings',
        'target_amount': 1000.0,
        'current_amount': 0.0,
        'currency': 'USD',
        'target_date': '2024-12-31',
        'start_date': '2024-01-01',
        'status': 'active',
        'progress_percentage': 0.0,
        'is_on_track': true,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'normalized_target_amount': null,
        'normalized_current_amount': null,
      };

      final goal = Goal.fromJson(json);

      expect(goal.normalizedTargetAmount, null);
      expect(goal.normalizedCurrentAmount, null);
    });

    test('toJson serializes goal correctly', () {
      final now = DateTime(2024, 1, 1);
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        householdId: 'hh_1',
        title: 'Emergency Fund',
        description: 'Save for emergencies',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 5000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 50.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: ['user_1'],
        baseCurrency: 'EUR',
        fxRate: 0.9,
        normalizedTargetAmount: 9000.0,
        normalizedCurrentAmount: 4500.0,
        icon: '💰',
        createdAt: now,
        updatedAt: now,
        isOwner: true,
        isAcknowledged: true,
        privacyRedacted: false,
      );

      final json = goal.toJson();

      expect(json['id'], 'goal_1');
      expect(json['user_id'], 'user_1');
      expect(json['household_id'], 'hh_1');
      expect(json['title'], 'Emergency Fund');
      expect(json['description'], 'Save for emergencies');
      expect(json['goal_type'], 'savings');
      expect(json['category'], 'savings');
      expect(json['target_amount'], 10000.0);
      expect(json['current_amount'], 5000.0);
      expect(json['currency'], 'USD');
      expect(json['target_date'], '2024-12-31');
      expect(json['start_date'], '2024-01-01');
      expect(json['status'], 'active');
      expect(json['progress_percentage'], 50.0);
      expect(json['is_on_track'], true);
      expect(json['privacy_scope'], 'full');
      expect(json['owner_type'], 'me');
      expect(json['acknowledged_by'], ['user_1']);
      expect(json['base_currency'], 'EUR');
      expect(json['fx_rate'], 0.9);
      expect(json['normalized_target_amount'], 900000);
      expect(json['normalized_current_amount'], 450000);
      expect(json['icon'], '💰');
      expect(json['created_at'], '2024-01-01T00:00:00.000');
      expect(json['updated_at'], '2024-01-01T00:00:00.000');
      expect(json['isOwner'], true);
      expect(json['isAcknowledged'], true);
      expect(json['privacyRedacted'], false);
    });
  });

  group('Goal - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      final now = DateTime(2024, 1, 1);
      final original = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Emergency Fund',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 5000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 50.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        currentAmount: 7500.0,
        progressPercentage: 75.0,
        status: 'in_progress',
      );

      expect(updated.id, 'goal_1');
      expect(updated.currentAmount, 7500.0);
      expect(updated.progressPercentage, 75.0);
      expect(updated.status, 'in_progress');
      expect(updated.targetAmount, 10000.0);
      expect(updated.title, 'Emergency Fund');
    });
  });

  group('Goal - Computed Properties', () {
    test('amountRemaining calculates correctly', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 3000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 30.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.amountRemaining, 7000.0);
    });

    test('isHouseholdGoal returns true when householdId is set', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        householdId: 'hh_1',
        title: 'Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 0.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 0.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'household',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.isHouseholdGoal, true);
    });

    test('isHouseholdGoal returns false when householdId is null', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 0.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 0.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.isHouseholdGoal, false);
    });

    test('isSavings returns true for savings category', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 0.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 0.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.isSavings, true);
      expect(goal.isPaydown, false);
    });

    test('isPaydown returns true for paydown category', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Debt Payoff',
        goalType: 'debt',
        category: 'paydown',
        targetAmount: 10000.0,
        currentAmount: 3000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 30.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.isPaydown, true);
      expect(goal.isSavings, false);
    });

    test('isActive returns true for active status', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 0.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 0.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.isActive, true);
      expect(goal.isCompleted, false);
    });

    test('isCompleted returns true for completed status', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 10000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'completed',
        progressPercentage: 100.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        completedAt: DateTime(2024, 6, 1),
      );

      expect(goal.isCompleted, true);
      expect(goal.isActive, false);
    });
  });

  group('Goal - Edge Cases', () {
    test('handles zero current amount', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'New Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 0.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 0.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.currentAmount, 0.0);
      expect(goal.amountRemaining, 10000.0);
    });

    test('handles goal exceeding target', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Exceeded Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 12000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'completed',
        progressPercentage: 120.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.currentAmount, 12000.0);
      expect(goal.amountRemaining, -2000.0);
    });

    test('handles multiple acknowledged users', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        householdId: 'hh_1',
        title: 'Household Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 5000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 50.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'household',
        acknowledgedBy: ['user_1', 'user_2', 'user_3', 'user_4'],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.acknowledgedBy.length, 4);
    });

    test('handles privacy redacted goal', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        householdId: 'hh_1',
        title: 'Private Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 5000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 50.0,
        isOnTrack: true,
        privacyScope: 'private',
        ownerType: 'me',
        acknowledgedBy: [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        privacyRedacted: true,
      );

      expect(goal.privacyRedacted, true);
      expect(goal.privacyScope, 'private');
    });

    test('handles currency conversion with fx rate', () {
      final goal = Goal(
        id: 'goal_1',
        userId: 'user_1',
        title: 'Multi-currency Goal',
        goalType: 'savings',
        category: 'savings',
        targetAmount: 10000.0,
        currentAmount: 5000.0,
        currency: 'USD',
        targetDate: '2024-12-31',
        startDate: '2024-01-01',
        status: 'active',
        progressPercentage: 50.0,
        isOnTrack: true,
        privacyScope: 'full',
        ownerType: 'me',
        acknowledgedBy: [],
        baseCurrency: 'EUR',
        fxRate: 0.85,
        normalizedTargetAmount: 8500.0,
        normalizedCurrentAmount: 4250.0,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(goal.fxRate, 0.85);
      expect(goal.normalizedTargetAmount, 8500.0);
      expect(goal.normalizedCurrentAmount, 4250.0);
    });
  });
}
