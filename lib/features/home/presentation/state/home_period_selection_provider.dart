import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';

class HomePeriodSelectionState {
  const HomePeriodSelectionState({
    required this.mode,
    required this.selectedDate,
    required this.isHydrated,
  });

  final HomePeriodMode mode;
  final DateTime selectedDate;
  final bool isHydrated;

  HomePeriodSelectionState copyWith({
    HomePeriodMode? mode,
    DateTime? selectedDate,
    bool? isHydrated,
  }) {
    return HomePeriodSelectionState(
      mode: mode ?? this.mode,
      selectedDate: selectedDate ?? this.selectedDate,
      isHydrated: isHydrated ?? this.isHydrated,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomePeriodSelectionState &&
      other.mode == mode &&
      other.selectedDate == selectedDate &&
      other.isHydrated == isHydrated;

  @override
  int get hashCode => Object.hash(mode, selectedDate, isHydrated);
}

class HomePeriodSelectionStore {
  static const _keyPrefix = 'home_period_selection_v1_';

  Future<HomePeriodSelectionState?> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('$_keyPrefix$userId');
      if (encoded == null) return null;
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final mode = HomePeriodMode.values.firstWhere(
        (candidate) => candidate.name == value['mode'],
        orElse: () => HomePeriodMode.monthly,
      );
      final date = DateTime.tryParse(value['selectedDate'] as String? ?? '');
      if (date == null) return null;
      return HomePeriodSelectionState(
        mode: mode,
        selectedDate: normalizeHomePeriodDate(date),
        isHydrated: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String userId, HomePeriodSelectionState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix$userId',
      jsonEncode({
        'mode': state.mode.name,
        'selectedDate': state.selectedDate.toIso8601String().split('T').first,
      }),
    );
  }
}

final homePeriodSelectionStoreProvider = Provider<HomePeriodSelectionStore>(
  (ref) => HomePeriodSelectionStore(),
);

final homePeriodNowProvider = Provider<DateTime>((ref) => DateTime.now());
final homePeriodClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final homePeriodFinancialMonthStartDayProvider = Provider<int>(
  (ref) => ref.watch(financialMonthStartDayProvider),
);

class HomePeriodSelectionNotifier
    extends StateNotifier<HomePeriodSelectionState> {
  HomePeriodSelectionNotifier({
    required this.userId,
    required HomePeriodSelectionStore store,
    required DateTime Function() now,
    required int financialMonthStartDay,
    required bool isPreviewMode,
  })  : _store = store,
        _now = now,
        _financialMonthStartDay = financialMonthStartDay,
        _isPreviewMode = isPreviewMode,
        super(_defaultState(now(), financialMonthStartDay)) {
    _hydrate();
  }

  final String userId;
  final HomePeriodSelectionStore _store;
  final DateTime Function() _now;
  final int _financialMonthStartDay;
  final bool _isPreviewMode;
  bool _hasUserSelection = false;

  static HomePeriodSelectionState _defaultState(DateTime now, int startDay) {
    return HomePeriodSelectionState(
      mode: HomePeriodMode.monthly,
      selectedDate: normalizeHomePeriodSelection(
        now,
        mode: HomePeriodMode.monthly,
        now: now,
        financialMonthStartDay: startDay,
      ),
      isHydrated: false,
    );
  }

  Future<void> _hydrate() async {
    if (_isPreviewMode) {
      state = state.copyWith(isHydrated: true);
      return;
    }
    final stored = await _store.load(userId);
    if (_hasUserSelection) return;
    if (stored == null) {
      state = state.copyWith(isHydrated: true);
      return;
    }
    state = HomePeriodSelectionState(
      mode: stored.mode,
      selectedDate: normalizeHomePeriodSelection(
        stored.selectedDate,
        mode: stored.mode,
        now: _now(),
        financialMonthStartDay: _financialMonthStartDay,
      ),
      isHydrated: true,
    );
  }

  Future<void> select(DateTime date) => _setSelection(
        mode: state.mode,
        selectedDate: date,
      );

  Future<void> setMode(HomePeriodMode mode) {
    return _setSelection(
      mode: mode,
      selectedDate: convertHomePeriodMode(
        mode: state.mode,
        selectedDate: state.selectedDate,
        nextMode: mode,
        now: _now(),
        financialMonthStartDay: _financialMonthStartDay,
      ),
    );
  }

  Future<void> _setSelection({
    required HomePeriodMode mode,
    required DateTime selectedDate,
  }) async {
    final normalized = normalizeHomePeriodSelection(
      selectedDate,
      mode: mode,
      now: _now(),
      financialMonthStartDay: _financialMonthStartDay,
    );
    final next = HomePeriodSelectionState(
      mode: mode,
      selectedDate: normalized,
      isHydrated: true,
    );
    _hasUserSelection = true;
    state = next;
    if (!_isPreviewMode) {
      await _store.save(userId, next);
    }
  }
}

final homePeriodSelectionProvider = StateNotifierProvider.family<
    HomePeriodSelectionNotifier,
    HomePeriodSelectionState,
    String>((ref, userId) {
  return HomePeriodSelectionNotifier(
    userId: userId,
    store: ref.read(homePeriodSelectionStoreProvider),
    now: ref.read(homePeriodClockProvider),
    financialMonthStartDay: ref.watch(homePeriodFinancialMonthStartDayProvider),
    isPreviewMode: ref.watch(previewModeProvider).isActive,
  );
});

final homePeriodDateRangeProvider =
    Provider.family<HomePeriodDateRange, String>(
  (ref, userId) {
    final selection = ref.watch(homePeriodSelectionProvider(userId));
    return resolveHomePeriodRange(
      mode: selection.mode,
      selectedDate: selection.selectedDate,
      financialMonthStartDay:
          ref.watch(homePeriodFinancialMonthStartDayProvider),
    );
  },
);
