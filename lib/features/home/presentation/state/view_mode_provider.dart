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

  const ViewModeState({
    required this.mode,
  });

  ViewModeState copyWith({
    ViewMode? mode,
  }) {
    return ViewModeState(
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewModeState &&
          runtimeType == other.runtimeType &&
          mode == other.mode;

  @override
  int get hashCode => mode.hashCode;
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

  void setPersonalMode() {
    state = const ViewModeState(mode: ViewMode.personal);
    _persist(ViewMode.personal);
  }

  void toggleMode() {
    if (state.mode == ViewMode.personal) {
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
