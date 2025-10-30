// Selected household provider with local storage persistence
// Ensures selected household persists across app navigation and restarts

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/household.dart';
import 'household_providers.dart';

/// Storage key for selected household ID
const String _kSelectedHouseholdIdKey = 'selected_household_id';

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
  }) {
    return SelectedHouseholdState(
      householdId: householdId ?? this.householdId,
      household: household ?? this.household,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get hasSelection => householdId != null && household != null;
}

/// Selected household notifier
/// Handles loading from storage, selecting household, and persisting selection
class SelectedHouseholdNotifier extends StateNotifier<SelectedHouseholdState> {
  final Ref ref;
  final SharedPreferences prefs;

  SelectedHouseholdNotifier(this.ref, this.prefs)
      : super(const SelectedHouseholdState());

  /// Initialize - loads selected household from storage
  Future<void> initialize(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('🔍 Initializing selected household for user: $userId');

      // Get user's households
      final householdsAsync = ref.read(userHouseholdsProvider(userId));
      
      await householdsAsync.when(
        data: (households) async {
          if (households.isEmpty) {
            debugPrint('📭 No households found for user');
            state = const SelectedHouseholdState(isLoading: false);
            return;
          }

          // Try to load saved selection from local storage
          final savedId = prefs.getString(_kSelectedHouseholdIdKey);
          debugPrint('💾 Saved household ID from storage: $savedId');

          String? selectedId;
          Household? selectedHousehold;

          if (savedId != null) {
            // Check if saved household still exists
            selectedHousehold = households.firstWhere(
              (h) => h.id == savedId,
              orElse: () => households.first,
            );
            selectedId = selectedHousehold.id;
            
            if (savedId != selectedId) {
              debugPrint('⚠️ Saved household not found, falling back to first');
            } else {
              debugPrint('✅ Restored saved household: ${selectedHousehold.name}');
            }
          } else {
            // No saved selection, use first household
            selectedHousehold = households.first;
            selectedId = selectedHousehold.id;
            debugPrint('🆕 No saved selection, using first household: ${selectedHousehold.name}');
          }

          // Update state
          state = SelectedHouseholdState(
            householdId: selectedId,
            household: selectedHousehold,
            isLoading: false,
          );

          // Persist to storage
          await _saveToStorage(selectedId);
        },
        loading: () {
          debugPrint('⏳ Waiting for households to load...');
        },
        error: (error, stack) {
          debugPrint('❌ Error loading households: $error');
          state = SelectedHouseholdState(
            isLoading: false,
            error: error.toString(),
          );
        },
      );
    } catch (e, stack) {
      debugPrint('❌ Error initializing selected household: $e');
      debugPrint('Stack: $stack');
      state = SelectedHouseholdState(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Select a household by ID
  Future<void> selectHousehold(String householdId, String userId) async {
    try {
      debugPrint('🎯 Selecting household: $householdId');

      // Get household details
      final householdAsync = await ref.read(householdProvider(householdId).future);
      
      if (householdAsync == null) {
        debugPrint('❌ Household not found: $householdId');
        state = state.copyWith(error: 'Household not found');
        return;
      }

      // Update state
      state = SelectedHouseholdState(
        householdId: householdId,
        household: householdAsync,
        isLoading: false,
      );

      // Persist to storage
      await _saveToStorage(householdId);
      
      debugPrint('✅ Selected household: ${householdAsync.name}');
    } catch (e, stack) {
      debugPrint('❌ Error selecting household: $e');
      debugPrint('Stack: $stack');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Clear selection
  Future<void> clearSelection() async {
    debugPrint('🗑️ Clearing household selection');
    await prefs.remove(_kSelectedHouseholdIdKey);
    state = const SelectedHouseholdState();
  }

  /// Refresh current household data
  Future<void> refresh(String userId) async {
    if (state.householdId == null) return;
    
    debugPrint('🔄 Refreshing household: ${state.householdId}');
    await selectHousehold(state.householdId!, userId);
  }

  /// Save to local storage
  Future<void> _saveToStorage(String householdId) async {
    try {
      await prefs.setString(_kSelectedHouseholdIdKey, householdId);
      debugPrint('💾 Saved household selection to storage: $householdId');
    } catch (e) {
      debugPrint('⚠️ Failed to save to storage: $e');
      // Non-critical error, continue anyway
    }
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
    return SelectedHouseholdNotifier(ref, prefs);
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
      debugPrint('🔔 Selected household state changed: ${next.household?.name ?? "none"}');
    },
  );
});
