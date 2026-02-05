import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/data/services/period_preference_service.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/period_selection.dart';

final periodPreferenceServiceProvider = Provider<PeriodPreferenceService>(
  (ref) => PeriodPreferenceService(),
);

class PeriodFilterNotifier extends StateNotifier<PeriodSelection> {
  PeriodFilterNotifier(this._service)
      : super(PeriodSelection.preset(DateRangeFilter.thisMonth));

  final PeriodPreferenceService _service;
  bool _hasUserSelection = false;

  Future<void> loadSelection() async {
    if (_hasUserSelection) return;
    final stored = await _service.getSelection();
    if (stored != null && !_hasUserSelection) {
      state = stored;
    }
  }

  Future<void> setPreset(DateRangeFilter preset) async {
    final selection = PeriodSelection.preset(preset);
    _hasUserSelection = true;
    state = selection;
    await _service.setSelection(selection);
  }

  Future<void> setMonth(DateTime month) async {
    final selection = PeriodSelection.month(month);
    _hasUserSelection = true;
    state = selection;
    await _service.setSelection(selection);
  }

  Future<void> setCustomRange(DateTime start, DateTime end) async {
    final selection = PeriodSelection.custom(start, end);
    _hasUserSelection = true;
    state = selection;
    await _service.setSelection(selection);
  }

  Future<void> shiftMonth(int delta) async {
    if (state.kind != PeriodSelectionKind.month) return;
    final base = state.month ?? DateTime.now();
    final target = DateTime(base.year, base.month + delta, 1);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final clamped = target.isAfter(currentMonth) ? currentMonth : target;
    await setMonth(clamped);
  }
}

final periodFilterProvider =
    StateNotifierProvider<PeriodFilterNotifier, PeriodSelection>((ref) {
  final service = ref.read(periodPreferenceServiceProvider);
  final notifier = PeriodFilterNotifier(service);
  notifier.loadSelection();
  return notifier;
});
