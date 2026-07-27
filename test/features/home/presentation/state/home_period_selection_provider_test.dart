import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';

class _FakeHomePeriodSelectionStore extends HomePeriodSelectionStore {
  _FakeHomePeriodSelectionStore(this.stored);

  HomePeriodSelectionState? stored;
  HomePeriodSelectionState? saved;

  @override
  Future<HomePeriodSelectionState?> load(String userId) async => stored;

  @override
  Future<void> save(String userId, HomePeriodSelectionState state) async {
    saved = state;
    stored = state;
  }
}

void main() {
  final now = DateTime(2026, 7, 26, 12);

  test('defaults to the current financial cycle in monthly mode', () {
    final store = _FakeHomePeriodSelectionStore(null);
    final container = ProviderContainer(
      overrides: [
        homePeriodSelectionStoreProvider.overrideWithValue(store),
        homePeriodClockProvider.overrideWithValue(() => now),
        homePeriodFinancialMonthStartDayProvider.overrideWithValue(15),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(homePeriodSelectionProvider('user'));
    expect(state.mode, HomePeriodMode.monthly);
    expect(state.selectedDate, DateTime(2026, 7, 15));
  });

  test('selecting a day persists one normalized state transition', () async {
    final store = _FakeHomePeriodSelectionStore(null);
    final container = ProviderContainer(
      overrides: [
        homePeriodSelectionStoreProvider.overrideWithValue(store),
        homePeriodClockProvider.overrideWithValue(() => now),
        homePeriodFinancialMonthStartDayProvider.overrideWithValue(15),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(homePeriodSelectionProvider('user').notifier)
        .select(DateTime(2026, 7, 20, 14));

    final state = container.read(homePeriodSelectionProvider('user'));
    expect(state.mode, HomePeriodMode.monthly);
    expect(state.selectedDate, DateTime(2026, 7, 15));
    expect(store.saved, state);
  });

  test('changing mode converts and persists atomically', () async {
    final store = _FakeHomePeriodSelectionStore(
      HomePeriodSelectionState(
        mode: HomePeriodMode.monthly,
        selectedDate: DateTime(2026, 5, 15),
        isHydrated: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        homePeriodSelectionStoreProvider.overrideWithValue(store),
        homePeriodClockProvider.overrideWithValue(() => now),
        homePeriodFinancialMonthStartDayProvider.overrideWithValue(15),
      ],
    );
    addTearDown(container.dispose);

    container.read(homePeriodSelectionProvider('user'));
    await Future<void>.delayed(Duration.zero);

    await container
        .read(homePeriodSelectionProvider('user').notifier)
        .setMode(HomePeriodMode.daily);

    final state = container.read(homePeriodSelectionProvider('user'));
    expect(state.mode, HomePeriodMode.daily);
    expect(state.selectedDate, DateTime(2026, 5, 26));
    expect(store.saved, state);
  });
}
