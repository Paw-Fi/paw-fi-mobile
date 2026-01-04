import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/widgets/multi_transaction_review_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({this.households = const []});

  final List<Household> households;

  @override
  Future<List<Household>> getUserHouseholds(String userId) async => households;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OpenSheetOnStart extends ConsumerStatefulWidget {
  const _OpenSheetOnStart({required this.transactions});

  final List<ParsedExpense> transactions;

  @override
  ConsumerState<_OpenSheetOnStart> createState() => _OpenSheetOnStartState();
}

class _OpenSheetOnStartState extends ConsumerState<_OpenSheetOnStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMultiTransactionReviewSheet(
        context,
        transactions: widget.transactions,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

Future<void> _pumpWithOverrides(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required AppUser user,
  required HouseholdRepository householdRepository,
  required List<ParsedExpense> transactions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => _TestAuth(user)),
        householdRepositoryProvider.overrideWithValue(householdRepository),
      ],
      child: MaterialApp(
        home: _OpenSheetOnStart(transactions: transactions),
      ),
    ),
  );

  await tester.pump();
  await tester.pumpAndSettle();
}

ParsedExpense _expense({
  required double amount,
  required DateTime date,
  String currency = 'EUR',
  String currencySymbol = '€',
  String category = 'other',
  String? description,
}) {
  return ParsedExpense(
    amount: amount,
    category: category,
    currency: currency,
    currencySymbol: currencySymbol,
    date: date,
    description: description,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Clear All deselects transactions', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const user = AppUser(uid: 'u1', email: 'u1@example.com');

    await _pumpWithOverrides(
      tester,
      prefs: prefs,
      user: user,
      householdRepository: _FakeHouseholdRepository(households: const []),
      transactions: [
        _expense(amount: 2, date: DateTime(2025, 1, 1), description: 'Taxi'),
        _expense(amount: 3, date: DateTime(2025, 1, 2), description: 'Bus'),
      ],
    );

    expect(find.textContaining('2 / 2'), findsOneWidget);

    await tester.tap(find.text('Clear All'));
    await tester.pump();

    expect(find.textContaining('0 / 2'), findsOneWidget);
  });

  testWidgets('Future date is blocked and highlighted', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:u1', 'h1');

    const user = AppUser(uid: 'u1', email: 'u1@example.com');
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    await _pumpWithOverrides(
      tester,
      prefs: prefs,
      user: user,
      householdRepository: _FakeHouseholdRepository(households: const []),
      transactions: [
        _expense(amount: 2, date: tomorrow, description: 'Taxi'),
      ],
    );

    await tester.tap(find.textContaining('Save 1'));
    await tester.pump();

    expect(find.text('Date cannot be in the future'), findsOneWidget);

    // Allow AppToast's auto-dismiss timer to complete to avoid pending timers.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Edit amount parses comma decimals', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const user = AppUser(uid: 'u1', email: 'u1@example.com');

    await _pumpWithOverrides(
      tester,
      prefs: prefs,
      user: user,
      householdRepository: _FakeHouseholdRepository(households: const []),
      transactions: [
        _expense(amount: 2, date: DateTime(2025, 1, 1), description: 'Taxi'),
      ],
    );

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1,23');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('€1.23'), findsOneWidget);
  });
}
