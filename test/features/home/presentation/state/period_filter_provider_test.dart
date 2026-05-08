import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/data/services/period_preference_service.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/period_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/period_selection.dart';

class _FakePeriodPreferenceService extends PeriodPreferenceService {
  PeriodSelection? lastSelection;
  PeriodSelection? storedSelection;

  @override
  Future<PeriodSelection?> getSelection() async => storedSelection;

  @override
  Future<void> setSelection(PeriodSelection selection) async {
    lastSelection = selection;
    storedSelection = selection;
  }
}

void main() {
  test('resolvePeriodDateRange returns month boundaries', () {
    final selection = PeriodSelection.month(DateTime(2026, 2, 20));
    final range = resolvePeriodDateRange(selection);

    expect(range.start, DateTime(2026, 2, 1));
    expect(range.end, DateTime(2026, 2, 28));
  });

  test('resolvePeriodDateRange uses preset when provided', () {
    final selection = PeriodSelection.preset(DateRangeFilter.thisMonth);
    final now = DateTime(2026, 2, 4, 10, 30);
    final range = resolvePeriodDateRange(selection, now: now);

    expect(range.start, DateTime(2026, 2, 1));
    expect(range.end, DateTime(2026, 2, 4));
  });

  test('resolvePeriodDateRange includes current month for last 3 months', () {
    final selection = PeriodSelection.preset(DateRangeFilter.last3Months);
    final now = DateTime(2026, 5, 8, 10, 30);
    final range = resolvePeriodDateRange(selection, now: now);

    expect(range.start, DateTime(2026, 3, 1));
    expect(range.end, DateTime(2026, 5, 8));
  });

  test('PeriodFilterNotifier shiftMonth uses current month selection',
      () async {
    final fakeService = _FakePeriodPreferenceService();
    final container = ProviderContainer(
      overrides: [
        periodPreferenceServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(periodFilterProvider.notifier);
    await notifier.setMonth(DateTime(2025, 12, 11));
    await notifier.shiftMonth(1);

    final selection = container.read(periodFilterProvider);
    expect(selection.kind, PeriodSelectionKind.month);
    expect(selection.month, DateTime(2026, 1, 1));
  });
}
