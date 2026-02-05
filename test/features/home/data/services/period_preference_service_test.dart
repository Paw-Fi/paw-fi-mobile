import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/home/data/services/period_preference_service.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/period_selection.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and loads preset selection', () async {
    final service = PeriodPreferenceService();
    await service
        .setSelection(PeriodSelection.preset(DateRangeFilter.thisYear));

    final selection = await service.getSelection();
    expect(selection?.kind, PeriodSelectionKind.preset);
    expect(selection?.preset, DateRangeFilter.thisYear);
  });

  test('stores and loads month selection', () async {
    final service = PeriodPreferenceService();
    await service.setSelection(PeriodSelection.month(DateTime(2025, 12, 15)));

    final selection = await service.getSelection();
    expect(selection?.kind, PeriodSelectionKind.month);
    expect(selection?.month, DateTime(2025, 12, 1));
  });

  test('stores and loads custom selection', () async {
    final service = PeriodPreferenceService();
    await service.setSelection(
      PeriodSelection.custom(DateTime(2024, 3, 2), DateTime(2024, 3, 20)),
    );

    final selection = await service.getSelection();
    expect(selection?.kind, PeriodSelectionKind.custom);
    expect(selection?.customStart, DateTime(2024, 3, 2));
    expect(selection?.customEnd, DateTime(2024, 3, 20));
  });
}
