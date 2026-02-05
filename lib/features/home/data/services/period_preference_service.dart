import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/period_selection.dart';

/// Service for managing period selection preferences in local storage
class PeriodPreferenceService {
  static const String _periodKindKey = 'selected_period_kind';
  static const String _periodPresetKey = 'selected_period_preset';
  static const String _periodMonthKey = 'selected_period_month';
  static const String _customStartKey = 'custom_range_start';
  static const String _customEndKey = 'custom_range_end';

  // In-memory cache to reduce SharedPreferences reads
  PeriodSelection? _cachedSelection;

  Future<PeriodSelection?> getSelection() async {
    if (_cachedSelection != null) return _cachedSelection;
    final prefs = await SharedPreferences.getInstance();
    final kind = prefs.getString(_periodKindKey);
    if (kind == null) return null;

    PeriodSelection? selection;
    switch (kind) {
      case 'preset':
        final presetName = prefs.getString(_periodPresetKey);
        final preset = DateRangeFilter.values.firstWhere(
          (e) => e.name == presetName,
          orElse: () => DateRangeFilter.thisMonth,
        );
        selection = PeriodSelection.preset(preset);
        break;
      case 'month':
        final monthValue = prefs.getString(_periodMonthKey);
        if (monthValue == null) return null;
        final month = DateTime.parse(monthValue);
        selection = PeriodSelection.month(month);
        break;
      case 'custom':
        final start = prefs.getString(_customStartKey);
        final end = prefs.getString(_customEndKey);
        if (start == null || end == null) return null;
        selection = PeriodSelection.custom(
          DateTime.parse(start),
          DateTime.parse(end),
        );
        break;
    }

    _cachedSelection = selection;
    return selection;
  }

  Future<void> setSelection(PeriodSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    switch (selection.kind) {
      case PeriodSelectionKind.preset:
        await prefs.setString(_periodKindKey, 'preset');
        await prefs.setString(
          _periodPresetKey,
          selection.preset?.name ?? DateRangeFilter.thisMonth.name,
        );
        break;
      case PeriodSelectionKind.month:
        await prefs.setString(_periodKindKey, 'month');
        final month = selection.month ?? DateTime.now();
        await prefs.setString(_periodMonthKey, _formatDate(month));
        break;
      case PeriodSelectionKind.custom:
        if (selection.customStart == null || selection.customEnd == null) {
          return;
        }
        await prefs.setString(_periodKindKey, 'custom');
        await prefs.setString(
            _customStartKey, _formatDate(selection.customStart!));
        await prefs.setString(_customEndKey, _formatDate(selection.customEnd!));
        break;
    }

    _cachedSelection = selection;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_periodKindKey);
    await prefs.remove(_periodPresetKey);
    await prefs.remove(_periodMonthKey);
    await prefs.remove(_customStartKey);
    await prefs.remove(_customEndKey);
    _cachedSelection = null;
  }

  String _formatDate(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;
}
