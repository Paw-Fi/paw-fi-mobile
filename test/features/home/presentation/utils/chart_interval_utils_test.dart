import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';

void main() {
  test('month range filters request daily summary buckets', () {
    expect(
      getSummaryIntervalGranularityFromFilter(DateRangeFilter.lastMonth),
      'daily',
    );
    expect(
      getSummaryIntervalGranularityFromFilter(DateRangeFilter.last3Months),
      'daily',
    );
  });

  test('single-day filters fall back to daily RPC buckets', () {
    expect(
      getSummaryIntervalGranularityFromFilter(DateRangeFilter.today),
      'daily',
    );
  });
}
