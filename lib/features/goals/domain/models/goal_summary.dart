class GoalSummary {
  final int totalGoals;
  final int activeGoals;
  final int completedGoals;
  final int savingsGoals;
  final int paydownGoals;
  final int onTrackGoals;
  final double totalTargetAmount;
  final double totalCurrentAmount;

  const GoalSummary({
    required this.totalGoals,
    required this.activeGoals,
    required this.completedGoals,
    required this.savingsGoals,
    required this.paydownGoals,
    required this.onTrackGoals,
    required this.totalTargetAmount,
    required this.totalCurrentAmount,
  });

  factory GoalSummary.fromJson(Map<String, dynamic> json) {
    return GoalSummary(
      totalGoals:
          json['totalGoals'] as int? ?? json['total_goals'] as int? ?? 0,
      activeGoals:
          json['activeGoals'] as int? ?? json['active_goals'] as int? ?? 0,
      completedGoals: json['completedGoals'] as int? ??
          json['completed_goals'] as int? ??
          0,
      savingsGoals:
          json['savingsGoals'] as int? ?? json['savings_goals'] as int? ?? 0,
      paydownGoals:
          json['paydownGoals'] as int? ?? json['paydown_goals'] as int? ?? 0,
      onTrackGoals:
          json['onTrackGoals'] as int? ?? json['on_track_goals'] as int? ?? 0,
      totalTargetAmount:
          (json['totalTargetAmount'] ?? json['total_target_amount'] ?? 0)
              .toDouble(),
      totalCurrentAmount:
          (json['totalCurrentAmount'] ?? json['total_current_amount'] ?? 0)
              .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalGoals': totalGoals,
      'activeGoals': activeGoals,
      'completedGoals': completedGoals,
      'savingsGoals': savingsGoals,
      'paydownGoals': paydownGoals,
      'onTrackGoals': onTrackGoals,
      'totalTargetAmount': totalTargetAmount,
      'totalCurrentAmount': totalCurrentAmount,
    };
  }

  double get overallProgress {
    if (totalTargetAmount == 0) return 0;
    return (totalCurrentAmount / totalTargetAmount) * 100;
  }

  bool get hasGoals => totalGoals > 0;
}
