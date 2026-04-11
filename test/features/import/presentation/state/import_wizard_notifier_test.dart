import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';

class FakeAnalyticsNotifier extends AnalyticsNotifier {
  FakeAnalyticsNotifier(super.ref) {
    state = AnalyticsData(allExpenses: const []);
  }

  void setExpenses(List<dynamic> expenses) {
    state = state.copyWith(allExpenses: expenses.cast());
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
        description: 'Dinner',
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
      const ImportParsedRow(
        index: 0,
        date: null,
        amountCents: 1200,
        category: 'food',
        description: 'Lunch',
        currency: 'USD',
        type: 'expense',
        errors: [],
      ),
    );

    final updated = container.read(importWizardProvider).parsedRows.first;
    expect(updated.errors, contains('invalid_date'));
  });

  test('deleteParsedRow is safe when row is missing', () async {
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
    notifier.state = notifier.state.copyWith(parsedRows: const []);

    expect(() => notifier.deleteParsedRow(999), returnsNormally);
  });

  test('setTargetFinancialWallet recalculates duplicates for selected account',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsProvider.overrideWith((ref) => FakeAnalyticsNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);

    final analyticsNotifier =
        container.read(analyticsProvider.notifier) as FakeAnalyticsNotifier;
    analyticsNotifier.setExpenses([
      ExpenseEntry(
        id: 'existing-1',
        date: DateTime(2024, 1, 1),
        amountCents: 1200,
        currency: 'USD',
        category: 'food',
        createdAt: DateTime(2024, 1, 1),
        type: 'expense',
        rawText: 'Lunch',
        walletId: 'wallet-a',
      ),
    ]);

    final notifier = container.read(importWizardProvider.notifier);
    notifier.state = notifier.state.copyWith(
      parsedRows: [
        const ImportParsedRow(
          index: 0,
          date: null,
          amountCents: null,
          category: null,
          description: null,
          currency: null,
          type: null,
          errors: [],
        ).copyWith(
          date: DateTime(2024, 1, 1),
          amountCents: 1200,
          category: 'food',
          description: 'Lunch',
          currency: 'USD',
          type: 'expense',
          errors: const [],
        ),
      ],
    );

    notifier.setTargetFinancialWallet('wallet-a');

    final updated = container.read(importWizardProvider).parsedRows.single;
    expect(updated.isDuplicate, isTrue);
    expect(updated.duplicateReason, DuplicateReason.inDb);
  });

  test('deleted rows stay removed after reparse', () async {
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
    const table = ImportTable(
      headers: ['date', 'amount', 'description'],
      rows: [
        ['2024-01-01', '-12.00', 'Lunch'],
        ['2024-01-02', '-5.50', 'Coffee'],
      ],
    );
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.description: 2,
      },
    );

    notifier.state = notifier.state.copyWith(
      table: table,
      mapping: mapping,
      parsedRows: [
        const ImportParsedRow(
          index: 0,
          date: null,
          amountCents: null,
          category: null,
          description: 'Lunch',
          currency: 'USD',
          type: 'expense',
          errors: [],
        ),
        const ImportParsedRow(
          index: 1,
          date: null,
          amountCents: null,
          category: null,
          description: 'Coffee',
          currency: 'USD',
          type: 'expense',
          errors: [],
        ),
      ],
    );

    notifier.deleteParsedRow(0);
    notifier.updateMapping(ImportField.description, 2);

    final rows = container.read(importWizardProvider).parsedRows;
    expect(rows.any((row) => row.index == 0), isFalse);
    expect(rows.any((row) => row.index == 1), isTrue);
  });

  test('reparse falls back to selected home currency when file has none',
      () async {
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
    container.read(homeFilterProvider.notifier).setSelectedCurrency('PKR');

    const table = ImportTable(
      headers: ['date', 'amount', 'description'],
      rows: [
        ['2024-01-01', '12.00', 'Lunch'],
      ],
    );
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.description: 2,
      },
    );

    notifier.state = notifier.state.copyWith(
      table: table,
      mapping: mapping,
    );

    notifier.updateMapping(ImportField.amount, 1);

    final row = container.read(importWizardProvider).parsedRows.single;
    expect(row.currency, 'PKR');
    expect(row.issues, isNot(contains(RowIssue.missingCurrency)));
  });

  test('reset clears wizard state back to initial step', () async {
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
    notifier.state = notifier.state.copyWith(
      step: ImportStep.preview,
      fileName: 'sample.csv',
      parsedRows: const [
        ImportParsedRow(
          index: 0,
          date: null,
          amountCents: null,
          category: null,
          description: null,
          currency: null,
          type: null,
          errors: [],
        ),
      ],
      errorMessage: 'bad file',
    );

    notifier.reset();

    final state = container.read(importWizardProvider);
    expect(state.step, ImportStep.selectFile);
    expect(state.fileName, isNull);
    expect(state.parsedRows, isEmpty);
    expect(state.errorMessage, isNull);
  });
}
