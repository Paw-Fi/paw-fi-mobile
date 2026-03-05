// Selected household provider with local storage persistence
// Ensures selected household persists across app navigation and restarts

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:moneko/features/auth/auth.dart';
import '../../domain/entities/household.dart';
import 'household_providers.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';

/// Storage key for selected household ID
const String _kLegacySelectedHouseholdIdKey = 'selected_household_id';

String _selectedHouseholdIdKeyForUser(String userId) =>
    'selected_household_id:$userId';

/// Selected household state
class SelectedHouseholdState {
  final String? householdId;
  final Household? household;
  final bool isLoading;
  final String? error;

  const SelectedHouseholdState({
    this.householdId,
    this.household,
    this.isLoading = false,
    this.error,
  });

  SelectedHouseholdState copyWith({
    String? householdId,
    Household? household,
    bool? isLoading,
    String? error,
    bool clearHouseholdId = false,
    bool clearHousehold = false,
    bool clearError = false,
  }) {
    return SelectedHouseholdState(
      householdId: clearHouseholdId ? null : (householdId ?? this.householdId),
      household: clearHousehold ? null : (household ?? this.household),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasSelection => householdId != null && household != null;
}

/// Selected household notifier
/// Handles loading from storage, selecting household, and persisting selection
class SelectedHouseholdNotifier extends StateNotifier<SelectedHouseholdState> {
  final Ref ref;
  final SharedPreferences prefs;
  final String _userId;
  int _operationId = 0;

  SelectedHouseholdNotifier(this.ref, this.prefs, this._userId)
      : super(_initialState(prefs, _userId));

  static SelectedHouseholdState _initialState(
    SharedPreferences prefs,
    String userId,
  ) {
    if (userId.isEmpty) return const SelectedHouseholdState();

    final perUser = prefs.getString(_selectedHouseholdIdKeyForUser(userId));
    final legacy = prefs.getString(_kLegacySelectedHouseholdIdKey);

    final raw = perUser ?? legacy;
    final initialId = (raw != null && raw.trim().isNotEmpty) ? raw : null;
    return SelectedHouseholdState(
      householdId: initialId,
      household: null,
      isLoading: false,
      error: null,
    );
  }

  /// Initialize - loads selected household from storage
  Future<void> initialize({List<Household>? preloadedHouseholds}) async {
    final preview = ref.read(previewModeProvider);
    if (_userId.isEmpty && !preview.isActive) {
      state = const SelectedHouseholdState();
      return;
    }

    final operationId = ++_operationId;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      debugPrint('🔍 Initializing selected household for user: $_userId');

      final households = preview.isActive
          ? PreviewMockData.households
          : preloadedHouseholds ?? await _waitForHouseholds(_userId);

      if (households == null || households.isEmpty) {
        debugPrint('📭 No households found for user (or load failed)');
        state = const SelectedHouseholdState(isLoading: false);
        return;
      }

      // Prefer the in-memory selection first if it is still valid for this list.
      Household? selectedHousehold;
      final currentId = state.householdId;
      if (currentId != null) {
        for (final h in households) {
          if (h.id == currentId) {
            selectedHousehold = h;
            break;
          }
        }
      }

      // Otherwise, restore from storage (per-user key, with legacy migration).
      if (selectedHousehold == null) {
        final savedId = await _readPersistedId(households);
        debugPrint('💾 Saved household ID from storage: $savedId');
        if (savedId != null) {
          for (final h in households) {
            if (h.id == savedId) {
              selectedHousehold = h;
              debugPrint('✅ Restored saved household: ${h.name}');
              break;
            }
          }
        }
      }

      // Still nothing? Default to the first household.
      selectedHousehold ??= households.first;
      final selectedId = selectedHousehold.id;
      if (currentId != null && currentId != selectedId) {
        debugPrint(
          '⚠️ Current selection invalid ($currentId), falling back to first: $selectedId',
        );
      }

      // Update state
      if (_operationId != operationId) return;
      state = SelectedHouseholdState(
        householdId: selectedId,
        household: selectedHousehold,
        isLoading: false,
        error: null,
      );

      // Persist to storage (per-user key)
      await _saveToStorage(selectedId);
    } catch (e, stack) {
      debugPrint('❌ Error initializing selected household: $e');
      debugPrint('Stack: $stack');
      if (_operationId != operationId) return;
      state = SelectedHouseholdState(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Wait for households provider to finish loading with proper polling.
  /// Returns the list of households or null if timeout/error.
  Future<List<Household>?> _waitForHouseholds(
    String userId, {
    Duration timeout = const Duration(seconds: 15),
    Duration pollInterval = const Duration(milliseconds: 150),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final state = ref.read(userHouseholdsProvider(userId));

      // If we have data and not loading, return it
      if (state.hasValue && !state.isLoading) {
        return state.value;
      }

      // If there's an error and not loading, return null
      if (state.hasError && !state.isLoading) {
        debugPrint('⚠️ Households resolved with error: ${state.error}');
        return null;
      }

      // Still loading - wait and retry
      await Future.delayed(pollInterval);
    }

    // Timeout reached
    final finalState = ref.read(userHouseholdsProvider(userId));
    debugPrint(
        '⚠️ Timeout (${timeout.inSeconds}s) waiting for households, hasValue=${finalState.hasValue}');
    return finalState.valueOrNull;
  }

  /// Select a household by ID
  Future<void> selectHousehold(String householdId) async {
    if (_userId.isEmpty) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }

    if (householdId.trim().isEmpty) {
      debugPrint('⚠️ selectHousehold called with empty ID, ignoring');
      return;
    }

    final operationId = ++_operationId;
    try {
      debugPrint('🎯 Selecting household: $householdId');

      // Prefer local list to avoid unnecessary network calls.
      Household? resolved;
      final householdsState = ref.read(userHouseholdsProvider(_userId));
      final households = householdsState.valueOrNull;
      if (households != null) {
        for (final h in households) {
          if (h.id == householdId) {
            resolved = h;
            break;
          }
        }
      }

      // Fallback: fetch household details (may fail offline). Still persist ID even if null.
      resolved ??= await ref.read(householdProvider(householdId).future);

      // Update state
      state = SelectedHouseholdState(
        householdId: householdId,
        household: resolved,
        isLoading: false,
        error: resolved == null ? 'Household not found' : null,
      );

      // Persist to storage
      await _saveToStorage(householdId);

      if (_operationId != operationId) return;
      if (resolved != null) {
        debugPrint('✅ Selected household: ${resolved.name}');
      } else {
        debugPrint(
            '⚠️ Selected household persisted but could not be resolved yet');
      }
    } catch (e, stack) {
      debugPrint('❌ Error selecting household: $e');
      debugPrint('Stack: $stack');
      if (_operationId != operationId) return;
      // Keep the selected ID if possible, so the choice persists even if fetching fails.
      state = state.copyWith(error: e.toString());
      await _saveToStorage(householdId);
    }
  }

  /// Clear selection
  Future<void> clearSelection() async {
    debugPrint('🗑️ Clearing household selection');
    if (mounted) {
      state = const SelectedHouseholdState();
    }
    if (_userId.isNotEmpty) {
      await prefs.remove(_selectedHouseholdIdKeyForUser(_userId));
    }
    await prefs.remove(_kLegacySelectedHouseholdIdKey);
  }

  /// Refresh current household data
  Future<void> refresh() async {
    if (state.householdId == null) return;

    debugPrint('🔄 Refreshing household: ${state.householdId}');
    await selectHousehold(state.householdId!);
  }

  /// Save to local storage
  Future<void> _saveToStorage(String householdId) async {
    if (_userId.isEmpty) return;

    try {
      await prefs.setString(
        _selectedHouseholdIdKeyForUser(_userId),
        householdId,
      );
      final legacy = prefs.getString(_kLegacySelectedHouseholdIdKey);
      if (legacy == householdId) {
        await prefs.remove(_kLegacySelectedHouseholdIdKey);
      }
      debugPrint(
        '💾 Saved household selection to storage (user=$_userId): $householdId',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to save to storage: $e');
      // Non-critical error, continue anyway
    }
  }

  Future<String?> _readPersistedId(List<Household> households) async {
    final perUserKey = _selectedHouseholdIdKeyForUser(_userId);

    final perUserSaved = prefs.getString(perUserKey);
    if (perUserSaved != null && households.any((h) => h.id == perUserSaved)) {
      return perUserSaved;
    }

    final legacySaved = prefs.getString(_kLegacySelectedHouseholdIdKey);
    if (legacySaved != null && households.any((h) => h.id == legacySaved)) {
      // Migrate legacy → per-user once we confirm it is valid for this account.
      try {
        await prefs.setString(perUserKey, legacySaved);
        await prefs.remove(_kLegacySelectedHouseholdIdKey);
        debugPrint('🔁 Migrated legacy selected household ID → per-user key');
      } catch (_) {}
      return legacySaved;
    }

    return null;
  }
}

/// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

/// Selected household provider
/// Use this to access and update the currently selected household
final selectedHouseholdProvider =
    StateNotifierProvider<SelectedHouseholdNotifier, SelectedHouseholdState>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authProvider.select((u) => u.uid));
    return SelectedHouseholdNotifier(ref, prefs, userId);
  },
);

/// Convenience provider to get just the household ID
final selectedHouseholdIdProvider = Provider<String?>((ref) {
  return ref.watch(selectedHouseholdProvider).householdId;
});

/// Convenience provider to get just the household object
final selectedHouseholdObjectProvider = Provider<Household?>((ref) {
  return ref.watch(selectedHouseholdProvider).household;
});

/// Auto-initialize provider
/// Watches auth state and initializes selected household when user logs in
final selectedHouseholdInitializerProvider = Provider<void>((ref) {
  // This provider auto-runs when dependencies change
  // You should watch this in your app root to ensure initialization
  ref.listen(
    selectedHouseholdProvider,
    (previous, next) {
      debugPrint(
          '🔔 Selected household state changed: ${next.household?.name ?? "none"}');
    },
  );
});
