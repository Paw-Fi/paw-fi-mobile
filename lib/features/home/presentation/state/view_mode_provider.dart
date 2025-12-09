import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// View mode for home page
enum ViewMode {
  personal,
  household;

  String toDisplayString() {
    switch (this) {
      case ViewMode.personal:
        return 'Single';
      case ViewMode.household:
        return 'Joint';
    }
  }
}

/// View mode state
class ViewModeState {
  final ViewMode mode;
  final String? selectedHouseholdId;

  const ViewModeState({
    required this.mode,
    this.selectedHouseholdId,
  });

  ViewModeState copyWith({
    ViewMode? mode,
    String? selectedHouseholdId,
  }) {
    return ViewModeState(
      mode: mode ?? this.mode,
      selectedHouseholdId: selectedHouseholdId ?? this.selectedHouseholdId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewModeState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          selectedHouseholdId == other.selectedHouseholdId;

  @override
  int get hashCode => mode.hashCode ^ selectedHouseholdId.hashCode;
}

/// View mode notifier
class ViewModeNotifier extends StateNotifier<ViewModeState> {
  static const _storageKey = 'moneko_view_mode';

  ViewModeNotifier() : super(const ViewModeState(mode: ViewMode.household)) {
    _loadPersistedMode();
  }

  Future<void> _loadPersistedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored == 'household') {
        // Keep selectedHouseholdId as-is (handled by its own provider)
        state = state.copyWith(mode: ViewMode.household);
      } else if (stored == 'personal') {
        state = state.copyWith(mode: ViewMode.personal);
      }
    } catch (_) {
      // Non-fatal: default remains household
    }
  }

  Future<void> _persist(ViewMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode == ViewMode.household ? 'household' : 'personal');
    } catch (_) {
      // ignore persistence errors
    }
  }

  void setMode(ViewMode mode) {
    state = state.copyWith(mode: mode);
    _persist(mode);
  }

  void setHouseholdMode(String householdId) {
    state = ViewModeState(
      mode: ViewMode.household,
      selectedHouseholdId: householdId,
    );
    _persist(ViewMode.household);
  }

  void setPersonalMode() {
    state = const ViewModeState(mode: ViewMode.personal);
    _persist(ViewMode.personal);
  }

  void toggleMode() {
    if (state.mode == ViewMode.personal) {
      // When switching to household mode, we need a household ID
      // This should be set by the UI when a household is selected
      state = state.copyWith(mode: ViewMode.household);
      _persist(ViewMode.household);
    } else {
      setPersonalMode();
    }
  }
}

/// View mode provider
final viewModeProvider = StateNotifierProvider<ViewModeNotifier, ViewModeState>(
  (ref) => ViewModeNotifier(),
);
