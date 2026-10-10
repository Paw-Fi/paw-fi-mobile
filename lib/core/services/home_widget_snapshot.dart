import 'package:intl/intl.dart';
import 'package:moneko/core/services/widget_service.dart';

/// One committed financial snapshot, shared by both native widget readers.
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.userId,
    required this.currency,
    required this.periodMonth,
    required this.totalSpent,
    required this.totalBudget,
    required this.pockets,
    this.topCategories,
  });

  final String userId;
  final String currency;
  final String periodMonth;
  final double totalSpent;
  final double totalBudget;
  final List<WidgetPocketData> pockets;
  final List<WidgetPocketData>? topCategories;

  Map<String, Object?> toJson() {
    if (!totalSpent.isFinite || !totalBudget.isFinite) {
      throw StateError('Invalid home widget totals');
    }
    final format = NumberFormat.simpleCurrency(name: currency);
    return {
      'version': 1,
      'userId': userId,
      'currency': currency,
      'periodMonth': periodMonth,
      'totalSpent': format.format(totalSpent),
      'totalBudget': format.format(totalBudget),
      'remainingBudget': format.format(totalBudget - totalSpent),
      'progress':
          totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0,
      'pockets': pockets.map((item) => item.toJson()).toList(),
      if (topCategories != null)
        'topCategories': topCategories!.map((item) => item.toJson()).toList(),
    };
  }
}
