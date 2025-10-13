import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, AnalyticsData>((ref) {
  return AnalyticsNotifier();
});
