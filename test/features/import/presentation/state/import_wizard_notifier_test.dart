import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';

class FakeAnalyticsNotifier extends AnalyticsNotifier {
  FakeAnalyticsNotifier(super.ref) {
    state = AnalyticsData(allExpenses: const []);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'test-anon-key',
    );
  });

  test('updateParsedRow revalidates and marks duplicates', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsProvider.overrideWith((ref) => FakeAnalyticsNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(importWizardProvider.notifier);
    final row0 = ImportParsedRow(
      index: 0,
      date: DateTime(2024, 1, 1),
      amountCents: 1200,
      category: 'food',
      description: 'Lunch',
      currency: 'USD',
      type: 'expense',
      errors: const [],
    );
    final row1 = ImportParsedRow(
      index: 1,
      date: DateTime(2024, 1, 2),
      amountCents: 2200,
      category: 'food',
      description: 'Dinner',
      currency: 'USD',
      type: 'expense',
      errors: const [],
    );

    notifier.state = notifier.state.copyWith(parsedRows: [row0, row1]);

    notifier.updateParsedRow(
      row0.copyWith(
        date: DateTime(2024, 1, 2),
        amountCents: 2200,
        category: 'food',
        currency: 'USD',
        type: 'expense',
      ),
    );

    final updated = container.read(importWizardProvider).parsedRows;
    expect(updated[1].isDuplicate, isTrue);
  });

  test('updateParsedRow applies validation errors', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsProvider.overrideWith((ref) => FakeAnalyticsNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(importWizardProvider.notifier);
    final row = ImportParsedRow(
      index: 0,
      date: DateTime(2024, 1, 1),
      amountCents: 1200,
      category: 'food',
      description: 'Lunch',
      currency: 'USD',
      type: 'expense',
      errors: const [],
    );

    notifier.state = notifier.state.copyWith(parsedRows: [row]);
    notifier.updateParsedRow(
      ImportParsedRow(
        index: 0,
        date: null,
        amountCents: 1200,
        category: 'food',
        description: 'Lunch',
        currency: 'USD',
        type: 'expense',
        errors: const [],
      ),
    );

    final updated = container.read(importWizardProvider).parsedRows.first;
    expect(updated.errors, contains('invalid_date'));
  });
}
