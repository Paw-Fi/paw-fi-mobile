import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/goals/domain/models/goal_summary.dart';

void main() {
  group('GoalSummary - Model Creation', () {
    test('creates goal summary with all fields', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 6,
        completedGoals: 4,
        savingsGoals: 7,
        paydownGoals: 3,
        onTrackGoals: 5,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 25000.0,
      );

      expect(summary.totalGoals, 10);
      expect(summary.activeGoals, 6);
      expect(summary.completedGoals, 4);
      expect(summary.savingsGoals, 7);
      expect(summary.paydownGoals, 3);
      expect(summary.onTrackGoals, 5);
      expect(summary.totalTargetAmount, 50000.0);
      expect(summary.totalCurrentAmount, 25000.0);
    });

    test('creates goal summary with zero values', () {
      const summary = GoalSummary(
        totalGoals: 0,
        activeGoals: 0,
        completedGoals: 0,
        savingsGoals: 0,
        paydownGoals: 0,
        onTrackGoals: 0,
        totalTargetAmount: 0.0,
        totalCurrentAmount: 0.0,
      );

      expect(summary.totalGoals, 0);
      expect(summary.totalTargetAmount, 0.0);
      expect(summary.totalCurrentAmount, 0.0);
    });
  });

  group('GoalSummary - JSON Serialization', () {
    test('fromJson parses with camelCase keys', () {
      final json = {
        'totalGoals': 10,
        'activeGoals': 6,
        'completedGoals': 4,
        'savingsGoals': 7,
        'paydownGoals': 3,
        'onTrackGoals': 5,
        'totalTargetAmount': 50000.0,
        'totalCurrentAmount': 25000.0,
      };

      final summary = GoalSummary.fromJson(json);

      expect(summary.totalGoals, 10);
      expect(summary.activeGoals, 6);
      expect(summary.completedGoals, 4);
      expect(summary.savingsGoals, 7);
      expect(summary.paydownGoals, 3);
      expect(summary.onTrackGoals, 5);
      expect(summary.totalTargetAmount, 50000.0);
      expect(summary.totalCurrentAmount, 25000.0);
    });

    test('fromJson parses with snake_case keys', () {
      final json = {
        'total_goals': 10,
        'active_goals': 6,
        'completed_goals': 4,
        'savings_goals': 7,
        'paydown_goals': 3,
        'on_track_goals': 5,
        'total_target_amount': 50000.0,
        'total_current_amount': 25000.0,
      };

      final summary = GoalSummary.fromJson(json);

      expect(summary.totalGoals, 10);
      expect(summary.activeGoals, 6);
      expect(summary.completedGoals, 4);
      expect(summary.savingsGoals, 7);
      expect(summary.paydownGoals, 3);
      expect(summary.onTrackGoals, 5);
      expect(summary.totalTargetAmount, 50000.0);
      expect(summary.totalCurrentAmount, 25000.0);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final summary = GoalSummary.fromJson(json);

      expect(summary.totalGoals, 0);
      expect(summary.activeGoals, 0);
      expect(summary.completedGoals, 0);
      expect(summary.savingsGoals, 0);
      expect(summary.paydownGoals, 0);
      expect(summary.onTrackGoals, 0);
      expect(summary.totalTargetAmount, 0.0);
      expect(summary.totalCurrentAmount, 0.0);
    });

    test('fromJson handles integer amounts', () {
      final json = {
        'totalGoals': 5,
        'activeGoals': 3,
        'completedGoals': 2,
        'savingsGoals': 4,
        'paydownGoals': 1,
        'onTrackGoals': 2,
        'totalTargetAmount': 10000,
        'totalCurrentAmount': 5000,
      };

      final summary = GoalSummary.fromJson(json);

      expect(summary.totalTargetAmount, 10000.0);
      expect(summary.totalCurrentAmount, 5000.0);
    });

    test('toJson serializes correctly', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 6,
        completedGoals: 4,
        savingsGoals: 7,
        paydownGoals: 3,
        onTrackGoals: 5,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 25000.0,
      );

      final json = summary.toJson();

      expect(json['totalGoals'], 10);
      expect(json['activeGoals'], 6);
      expect(json['completedGoals'], 4);
      expect(json['savingsGoals'], 7);
      expect(json['paydownGoals'], 3);
      expect(json['onTrackGoals'], 5);
      expect(json['totalTargetAmount'], 50000.0);
      expect(json['totalCurrentAmount'], 25000.0);
    });
  });

  group('GoalSummary - Computed Properties', () {
    test('overallProgress calculates correctly', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 6,
        completedGoals: 4,
        savingsGoals: 7,
        paydownGoals: 3,
        onTrackGoals: 5,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 25000.0,
      );

      expect(summary.overallProgress, 50.0);
    });

    test('overallProgress returns 0 when target is 0', () {
      const summary = GoalSummary(
        totalGoals: 5,
        activeGoals: 3,
        completedGoals: 2,
        savingsGoals: 4,
        paydownGoals: 1,
        onTrackGoals: 2,
        totalTargetAmount: 0.0,
        totalCurrentAmount: 1000.0,
      );

      expect(summary.overallProgress, 0.0);
    });

    test('overallProgress handles 100% completion', () {
      const summary = GoalSummary(
        totalGoals: 5,
        activeGoals: 0,
        completedGoals: 5,
        savingsGoals: 3,
        paydownGoals: 2,
        onTrackGoals: 5,
        totalTargetAmount: 10000.0,
        totalCurrentAmount: 10000.0,
      );

      expect(summary.overallProgress, 100.0);
    });

    test('overallProgress handles over 100% completion', () {
      const summary = GoalSummary(
        totalGoals: 5,
        activeGoals: 0,
        completedGoals: 5,
        savingsGoals: 3,
        paydownGoals: 2,
        onTrackGoals: 5,
        totalTargetAmount: 10000.0,
        totalCurrentAmount: 15000.0,
      );

      expect(summary.overallProgress, 150.0);
    });

    test('hasGoals returns true when goals exist', () {
      const summary = GoalSummary(
        totalGoals: 5,
        activeGoals: 3,
        completedGoals: 2,
        savingsGoals: 4,
        paydownGoals: 1,
        onTrackGoals: 2,
        totalTargetAmount: 10000.0,
        totalCurrentAmount: 5000.0,
      );

      expect(summary.hasGoals, true);
    });

    test('hasGoals returns false when no goals exist', () {
      const summary = GoalSummary(
        totalGoals: 0,
        activeGoals: 0,
        completedGoals: 0,
        savingsGoals: 0,
        paydownGoals: 0,
        onTrackGoals: 0,
        totalTargetAmount: 0.0,
        totalCurrentAmount: 0.0,
      );

      expect(summary.hasGoals, false);
    });
  });

  group('GoalSummary - Edge Cases', () {
    test('handles very large amounts', () {
      const summary = GoalSummary(
        totalGoals: 1000,
        activeGoals: 600,
        completedGoals: 400,
        savingsGoals: 700,
        paydownGoals: 300,
        onTrackGoals: 500,
        totalTargetAmount: 999999999.99,
        totalCurrentAmount: 500000000.00,
      );

      expect(summary.overallProgress, closeTo(50.0, 0.01));
    });

    test('handles very small fractional amounts', () {
      const summary = GoalSummary(
        totalGoals: 1,
        activeGoals: 1,
        completedGoals: 0,
        savingsGoals: 1,
        paydownGoals: 0,
        onTrackGoals: 1,
        totalTargetAmount: 0.01,
        totalCurrentAmount: 0.005,
      );

      expect(summary.overallProgress, 50.0);
    });

    test('handles negative goal counts', () {
      const summary = GoalSummary(
        totalGoals: -5,
        activeGoals: -3,
        completedGoals: -2,
        savingsGoals: -4,
        paydownGoals: -1,
        onTrackGoals: -2,
        totalTargetAmount: 10000.0,
        totalCurrentAmount: 5000.0,
      );

      expect(summary.totalGoals, -5);
      expect(summary.hasGoals, false);
    });

    test('handles mismatched goal type counts', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 6,
        completedGoals: 4,
        savingsGoals: 15, // More than total
        paydownGoals: 3,
        onTrackGoals: 5,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 25000.0,
      );

      expect(summary.savingsGoals, 15);
      expect(summary.totalGoals, 10);
    });

    test('handles all goals completed', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 0,
        completedGoals: 10,
        savingsGoals: 6,
        paydownGoals: 4,
        onTrackGoals: 10,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 50000.0,
      );

      expect(summary.completedGoals, summary.totalGoals);
      expect(summary.activeGoals, 0);
      expect(summary.overallProgress, 100.0);
    });

    test('handles no goals on track', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 10,
        completedGoals: 0,
        savingsGoals: 6,
        paydownGoals: 4,
        onTrackGoals: 0,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 5000.0,
      );

      expect(summary.onTrackGoals, 0);
      expect(summary.activeGoals, 10);
    });

    test('handles only savings goals', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 10,
        completedGoals: 0,
        savingsGoals: 10,
        paydownGoals: 0,
        onTrackGoals: 5,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 25000.0,
      );

      expect(summary.savingsGoals, 10);
      expect(summary.paydownGoals, 0);
    });

    test('handles only paydown goals', () {
      const summary = GoalSummary(
        totalGoals: 10,
        activeGoals: 10,
        completedGoals: 0,
        savingsGoals: 0,
        paydownGoals: 10,
        onTrackGoals: 5,
        totalTargetAmount: 50000.0,
        totalCurrentAmount: 25000.0,
      );

      expect(summary.savingsGoals, 0);
      expect(summary.paydownGoals, 10);
    });

    test('handles floating point precision in progress', () {
      const summary = GoalSummary(
        totalGoals: 3,
        activeGoals: 3,
        completedGoals: 0,
        savingsGoals: 2,
        paydownGoals: 1,
        onTrackGoals: 2,
        totalTargetAmount: 3.0,
        totalCurrentAmount: 1.0,
      );

      expect(summary.overallProgress, closeTo(33.33, 0.01));
    });

    test('handles current amount exceeding target', () {
      const summary = GoalSummary(
        totalGoals: 5,
        activeGoals: 2,
        completedGoals: 3,
        savingsGoals: 3,
        paydownGoals: 2,
        onTrackGoals: 5,
        totalTargetAmount: 10000.0,
        totalCurrentAmount: 20000.0,
      );

      expect(summary.overallProgress, 200.0);
    });

    test('handles zero current amount', () {
      const summary = GoalSummary(
        totalGoals: 5,
        activeGoals: 5,
        completedGoals: 0,
        savingsGoals: 3,
        paydownGoals: 2,
        onTrackGoals: 0,
        totalTargetAmount: 10000.0,
        totalCurrentAmount: 0.0,
      );

      expect(summary.overallProgress, 0.0);
    });

    test('handles large goal counts', () {
      const summary = GoalSummary(
        totalGoals: 999999,
        activeGoals: 600000,
        completedGoals: 399999,
        savingsGoals: 700000,
        paydownGoals: 299999,
        onTrackGoals: 500000,
        totalTargetAmount: 1000000000.0,
        totalCurrentAmount: 500000000.0,
      );

      expect(summary.totalGoals, 999999);
      expect(summary.overallProgress, 50.0);
    });
  });
}
