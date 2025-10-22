import 'package:hooks_riverpod/hooks_riverpod.dart';

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
  ViewModeNotifier() : super(const ViewModeState(mode: ViewMode.personal));

  void setMode(ViewMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setHouseholdMode(String householdId) {
    state = ViewModeState(
      mode: ViewMode.household,
      selectedHouseholdId: householdId,
    );
  }

  void setPersonalMode() {
    state = const ViewModeState(mode: ViewMode.personal);
  }

  void toggleMode() {
    if (state.mode == ViewMode.personal) {
      // When switching to household mode, we need a household ID
      // This should be set by the UI when a household is selected
      state = state.copyWith(mode: ViewMode.household);
    } else {
      setPersonalMode();
    }
  }
}

/// View mode provider
final viewModeProvider = StateNotifierProvider<ViewModeNotifier, ViewModeState>(
  (ref) => ViewModeNotifier(),
);
