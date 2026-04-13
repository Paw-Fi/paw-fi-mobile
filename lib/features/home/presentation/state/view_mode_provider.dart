import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

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
  final SharedPreferences? _prefs;

  ViewModeNotifier([this._prefs])
      : super(ViewModeState(mode: _readInitialMode(_prefs))) {
    if (_prefs == null) {
      _loadPersistedModeFallback();
    }
  }

  static ViewMode _readInitialMode(SharedPreferences? prefs) {
    final stored = prefs?.getString(_storageKey);
    if (stored == 'personal') {
      return ViewMode.personal;
    }
    return ViewMode.household;
  }

  Future<void> _loadPersistedModeFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored == 'household') {
        state = state.copyWith(mode: ViewMode.household);
      } else if (stored == 'personal') {
        state = state.copyWith(mode: ViewMode.personal);
      }
    } catch (_) {
      // Non-fatal fallback for tests/legacy constructor usage.
    }
  }

  Future<void> _persist(ViewMode mode) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(
          _storageKey, mode == ViewMode.household ? 'household' : 'personal');
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
  (ref) => ViewModeNotifier(ref.read(sharedPreferencesProvider)),
);
