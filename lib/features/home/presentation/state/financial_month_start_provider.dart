import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';

final financialMonthStartDayProvider = Provider<int>((ref) {
  final day = ref.watch(
    analyticsProvider.select(
      (state) => state.contact?.financialMonthStartDay,
    ),
  );
  return normalizeFinancialMonthStartDay(day);
});
