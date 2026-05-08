import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart'
    as household_split;
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _TestRecurringSaveNotifier extends RecurringTransactionSaveNotifier {
  _TestRecurringSaveNotifier(Ref ref) : super(ref);

  bool updateCalled = false;
  Map<String, dynamic>? lastUpdateArgs;

  @override
  Future<RecurringTransaction?> updateRecurringExpense({
    required String userId,
    required String expenseId,
    required double amount,
    required String category,
    required String currency,
    required DateTime startDate,
    required String frequency,
    DateTime? endDate,
    int? interval,
    String? description,
    String? merchant,
    bool? hasReminder,
    int? reminderValue,
    String? reminderUnit,
    String ownerType = 'me',
    String privacyScope = 'full',
    String? householdId,
    String? previousHouseholdId,
    SplitType? customSplitType,
    List<MemberSplit>? customSplits,
    String? payerUserId,
    String? accountId,
  }) async {
    updateCalled = true;
    lastUpdateArgs = {
      'userId': userId,
      'expenseId': expenseId,
      'amount': amount,
      'category': category,
      'currency': currency,
      'startDate': startDate,
      'frequency': frequency,
      'endDate': endDate,
      'interval': interval,
      'description': description,
      'merchant': merchant,
      'hasReminder': hasReminder,
      'reminderValue': reminderValue,
      'reminderUnit': reminderUnit,
      'ownerType': ownerType,
      'privacyScope': privacyScope,
      'householdId': householdId,
      'previousHouseholdId': previousHouseholdId,
      'customSplitType': customSplitType,
      'customSplits': customSplits,
      'payerUserId': payerUserId,
      'accountId': accountId,
    };
    return RecurringTransaction(
      id: expenseId,
      date: startDate,
      category: category,
      description: description,
      source: null,
      amount: amount,
      currency: currency,
      ownerType: ownerType,
      privacyScope: privacyScope,
      householdId: householdId,
      payerUserId: payerUserId,
      recurrenceRule: RecurrenceRule(
        frequency: frequency,
        anchorDate: startDate,
        interval: interval,
        endDate: endDate,
      ),
      type: 'expense',
      attachments: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );
  }
}

class _MockAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user_1', email: 'test@example.com');
}

class _TestRecurringTransactionsNotifier extends RecurringTransactionsNotifier {
  _TestRecurringTransactionsNotifier(
    super.ref,
    super.householdId,
    RecurringTransaction transaction,
  ) {
    state = state.copyWith(
      data: AsyncValue.data([transaction]),
      hasLoadedOnce: true,
    );
  }

  bool deleteCalled = false;
  bool skipCalled = false;
  String? deletedTransactionId;
  String? skippedTransactionId;
  DateTime? skippedDate;

  @override
  Future<DeleteRecurringResult> deleteRecurring(
    String userId,
    String transactionId,
  ) async {
    deleteCalled = true;
    deletedTransactionId = transactionId;
    return const DeleteRecurringResult.success();
  }

  @override
  Future<DeleteRecurringResult> skipOccurrence(
    String userId,
    String transactionId,
    DateTime dateToSkip,
  ) async {
    skipCalled = true;
    skippedTransactionId = transactionId;
    skippedDate = dateToSkip;
    return const DeleteRecurringResult.success();
  }
}

class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({required this.members, required this.splits});

  final List<HouseholdMember> members;
  final List<household_split.ExpenseSplitGroup> splits;

  @override
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId) async {
    return members;
  }

  @override
  Future<List<household_split.ExpenseSplitGroup>> getHouseholdSplits({
    required String householdId,
    String? startDate,
    String? endDate,
  }) async {
    return splits;
  }

  @override
  Future<List<Household>> getUserHouseholds(String userId) async => [
        Household(
          id: 'h1',
          name: 'Test Household',
          ownerId: userId,
          currency: 'USD',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

  @override
  Future<Household?> getHousehold(String householdId) async => null;

  @override
  Future<Household> createHousehold({
    required String name,
    required String currency,
    String? coverImageUrl,
    String? themeColor,
    bool isPortfolio = false,
    bool? autoSplitEnabled,
  }) =>
      throw UnimplementedError();

  @override
  Future<Household> updateHousehold({
    required String householdId,
    String? name,
    String? coverImageUrl,
    String? themeColor,
    bool? isPortfolio,
    bool? autoSplitEnabled,
    Map<String, dynamic>? autoSplitConfig,
    bool updateAutoSplitConfig = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteHousehold(String householdId) =>
      throw UnimplementedError();

  @override
  Future<void> removeMember(String memberId) => throw UnimplementedError();

  @override
  Future<void> updateMemberRole(String memberId, HouseholdRole role) =>
      throw UnimplementedError();

  @override
  Future<void> leaveHousehold(String householdId) => throw UnimplementedError();

  @override
  Future<List<HouseholdInvite>> getHouseholdInvites(String householdId) async =>
      const [];

  @override
  Future<String> createInvite({
    required String householdId,
    String? invitedEmail,
    String? personalMessage,
    String? inviterName,
    String? householdName,
    int expiresInDays = 7,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> validateInvite(String token) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> acceptInvite(String token) =>
      throw UnimplementedError();

  @override
  Future<void> revokeInvite({String? inviteId, String? token}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> computeSplit(
          household_split.SplitRequest request) =>
      throw UnimplementedError();

  @override
  Future<List<SharedBudget>> getHouseholdBudgets(String householdId) async =>
      const [];

  @override
  Future<SharedBudget> createBudget({
    required String householdId,
    required String name,
    required String period,
    required String currency,
    required int amountCents,
    double? warnThreshold,
    double? alertThreshold,
    String? budgetType,
    bool? countSplitPortionOnly,
  }) =>
      throw UnimplementedError();

  @override
  Future<SharedBudget> updateBudget({
    required String budgetId,
    String? name,
    int? amountCents,
    double? warnThreshold,
    double? alertThreshold,
    bool? isActive,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteBudget(String budgetId) => throw UnimplementedError();

  @override
  Future<SharingPreferences?> getSharingPreferences({
    required String userId,
    required String householdId,
  }) =>
      throw UnimplementedError();

  @override
  Future<SharingPreferences> updateSharingPreferences({
    required String userId,
    required String householdId,
    ShareScope? defaultTransactionShareScope,
    ShareScope? defaultAccountShareScope,
    Map<String, String>? perCategoryOverrides,
    bool? enableNudges,
    String? nudgeQuietHoursStart,
    String? nudgeQuietHoursEnd,
  }) =>
      throw UnimplementedError();

  @override
  Future<HouseholdSummary> getHouseholdSummary({
    required String householdId,
    required String currency,
    String? startDate,
    String? endDate,
  }) =>
      throw UnimplementedError();

  @override
  Stream<List<HouseholdMember>>? watchHouseholdMembers(String householdId) =>
      null;

  @override
  Stream<List<HouseholdInvite>>? watchHouseholdInvites(String householdId) =>
      null;

  @override
  Stream<List<SharedBudget>>? watchHouseholdBudgets(String householdId) => null;
}

HouseholdMember _member(String userId, String name) {
  final now = DateTime(2025, 1, 1);
  return HouseholdMember(
    id: 'm_$userId',
    householdId: 'h1',
    userId: userId,
    role: HouseholdRole.member,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    userEmail: '$name@example.com',
    userName: name,
    avatarUrl: null,
  );
}

WalletEntity _wallet({
  required String id,
  required String name,
  String? householdId,
  bool isDefault = false,
}) {
  return WalletEntity(
    id: id,
    userId: 'user_1',
    householdId: householdId,
    name: name,
    icon: 'wallet',
    color: '#000000',
    openingBalanceCents: 0,
    goalAmountCents: null,
    isDefault: isDefault,
    isSystem: false,
    isArchived: false,
    currentBalanceCents: 0,
  );
}

List<Override> _defaultWalletOverrides() => [
      walletAuthHeadersProvider.overrideWith(
        (ref) => const {'Authorization': 'Bearer test'},
      ),
      walletsByHouseholdIdProvider(null).overrideWith(
        (ref) async => [
          _wallet(id: 'w_personal', name: 'Personal Wallet', isDefault: true),
        ],
      ),
      walletsByHouseholdIdProvider('h1').overrideWith(
        (ref) async => [
          _wallet(
            id: 'w_household',
            name: 'Household Wallet',
            householdId: 'h1',
            isDefault: true,
          ),
        ],
      ),
    ];

RecurringTransaction _recurringExpense({
  required String id,
  String? householdId,
  String? accountId,
  String description = 'Test',
  String category = 'rent',
  double amount = 50.0,
  String currency = 'USD',
  RecurrenceRule? recurrenceRule,
}) {
  return RecurringTransaction(
    id: id,
    date: DateTime(2026, 1, 1),
    category: category,
    description: description,
    source: null,
    amount: amount,
    currency: currency,
    ownerType: 'me',
    privacyScope: 'full',
    householdId: householdId,
    payerUserId: 'user_1',
    accountId: accountId,
    recurrenceRule: recurrenceRule ??
        RecurrenceRule(
          frequency: 'monthly',
          anchorDate: DateTime(2026, 1, 1),
        ),
    type: 'expense',
    attachments: const [],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'anon',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}
  });

  testWidgets('Edit save blocks when split totals do not match amount',
      (tester) async {
    final members = <HouseholdMember>[
      _member('user_1', 'Alice'),
      _member('user_2', 'Bob'),
    ];

    final splitGroup = household_split.ExpenseSplitGroup(
      id: 'sg1',
      expenseId: 'exp_1',
      householdId: 'h1',
      payerUserId: 'user_1',
      splitType: household_split.SplitType.amount,
      totalAmountCents: 4000,
      currency: 'USD',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      splitLines: [
        household_split.ExpenseSplitLine(
          id: 'l1',
          splitGroupId: 'sg1',
          userId: 'user_1',
          amountCents: 3000,
          percentage: null,
          shares: null,
          isSettled: false,
          settledAt: null,
          settledByUserId: null,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        household_split.ExpenseSplitLine(
          id: 'l2',
          splitGroupId: 'sg1',
          userId: 'user_2',
          amountCents: 1000,
          percentage: null,
          shares: null,
          isSettled: false,
          settledAt: null,
          settledByUserId: null,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    _TestRecurringSaveNotifier? saveNotifier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:user_1', 'h1');

    final householdRepository = _FakeHouseholdRepository(
      members: members,
      splits: [splitGroup],
    );

    final container = ProviderContainer(
      overrides: [
        recurringTransactionSaveProvider.overrideWith((ref) {
          saveNotifier = _TestRecurringSaveNotifier(ref);
          return saveNotifier!;
        }),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => _MockAuth()),
        ..._defaultWalletOverrides(),
        householdRepositoryProvider.overrideWithValue(householdRepository),
        userHouseholdsProvider('user_1').overrideWith(
          (ref) => UserHouseholdsNotifier(householdRepository, 'user_1', ref)
            ..state = AsyncValue.data(
              [
                Household(
                  id: 'h1',
                  name: 'Test Household',
                  ownerId: 'user_1',
                  currency: 'USD',
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
        ),
        householdMembersProvider('h1').overrideWith(
          (ref) => HouseholdMembersNotifier(householdRepository, 'h1'),
        ),
        householdSplitsProvider(const HouseholdSplitsParams(householdId: 'h1'))
            .overrideWith(
          (ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            return [splitGroup];
          },
        ),
        householdScopeProvider.overrideWith((ref) {
          final viewMode = ref.watch(viewModeProvider).mode;
          final selected = ref.watch(selectedHouseholdProvider);
          return HouseholdScope(
            viewMode: viewMode,
            selected: selected,
            portfolioHouseholdIds: const {},
          );
        }),
        selectedHouseholdProvider.overrideWith(
          (ref) => SelectedHouseholdNotifier(ref, prefs, 'user_1'),
        ),
        viewModeProvider.overrideWith(
          (ref) => ViewModeNotifier()..setMode(ViewMode.household),
        ),
        homeFilterProvider.overrideWith(
          (ref) => HomeFilterNotifier()..setSelectedCurrency('USD'),
        ),
      ],
    );

    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: AddRecurringSheet(
                type: 'expense',
                existingTransaction: _recurringExpense(
                  id: 'exp_1',
                  householdId: 'h1',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Ensure provider is constructed.
    container.read(recurringTransactionSaveProvider);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    final splitEditor = find.byType(CustomSplitEditor);
    expect(splitEditor, findsOneWidget);
    final splitInputs = find.descendant(
      of: splitEditor,
      matching: find.byType(TextField),
    );
    expect(splitInputs, findsNWidgets(2));

    await tester.enterText(splitInputs.first, '60');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(saveNotifier, isNotNull);
    expect(saveNotifier!.updateCalled, isFalse);
  });

  testWidgets('Edit save triggers update when splits are valid',
      (tester) async {
    final members = <HouseholdMember>[
      _member('user_1', 'Alice'),
      _member('user_2', 'Bob'),
    ];

    final splitGroup = household_split.ExpenseSplitGroup(
      id: 'sg2',
      expenseId: 'exp_2',
      householdId: 'h1',
      payerUserId: 'user_1',
      splitType: household_split.SplitType.amount,
      totalAmountCents: 5000,
      currency: 'USD',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      splitLines: [
        household_split.ExpenseSplitLine(
          id: 'l3',
          splitGroupId: 'sg2',
          userId: 'user_1',
          amountCents: 3000,
          percentage: null,
          shares: null,
          isSettled: false,
          settledAt: null,
          settledByUserId: null,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        household_split.ExpenseSplitLine(
          id: 'l4',
          splitGroupId: 'sg2',
          userId: 'user_2',
          amountCents: 2000,
          percentage: null,
          shares: null,
          isSettled: false,
          settledAt: null,
          settledByUserId: null,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_household_id:user_1', 'h1');

    final householdRepository = _FakeHouseholdRepository(
      members: members,
      splits: [splitGroup],
    );

    _TestRecurringSaveNotifier? saveNotifier;

    final container = ProviderContainer(
      overrides: [
        recurringTransactionSaveProvider.overrideWith((ref) {
          saveNotifier = _TestRecurringSaveNotifier(ref);
          return saveNotifier!;
        }),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => _MockAuth()),
        ..._defaultWalletOverrides(),
        householdRepositoryProvider.overrideWithValue(householdRepository),
        userHouseholdsProvider('user_1').overrideWith(
          (ref) => UserHouseholdsNotifier(householdRepository, 'user_1', ref)
            ..state = AsyncValue.data(
              [
                Household(
                  id: 'h1',
                  name: 'Test Household',
                  ownerId: 'user_1',
                  currency: 'USD',
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
        ),
        householdMembersProvider('h1').overrideWith(
          (ref) => HouseholdMembersNotifier(householdRepository, 'h1'),
        ),
        householdSplitsProvider(const HouseholdSplitsParams(householdId: 'h1'))
            .overrideWith(
          (ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            return [splitGroup];
          },
        ),
        householdScopeProvider.overrideWith((ref) {
          final viewMode = ref.watch(viewModeProvider).mode;
          final selected = ref.watch(selectedHouseholdProvider);
          return HouseholdScope(
            viewMode: viewMode,
            selected: selected,
            portfolioHouseholdIds: const {},
          );
        }),
        selectedHouseholdProvider.overrideWith(
          (ref) => SelectedHouseholdNotifier(ref, prefs, 'user_1'),
        ),
        viewModeProvider.overrideWith(
          (ref) => ViewModeNotifier()..setMode(ViewMode.household),
        ),
        homeFilterProvider.overrideWith(
          (ref) => HomeFilterNotifier()..setSelectedCurrency('USD'),
        ),
      ],
    );

    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: AddRecurringSheet(
                type: 'expense',
                existingTransaction: _recurringExpense(
                  id: 'exp_2',
                  householdId: 'h1',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Ensure provider is constructed.
    container.read(recurringTransactionSaveProvider);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    expect(saveNotifier, isNotNull);
    expect(saveNotifier!.updateCalled, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Delete button opens choice dialog and deletes entire series',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final householdRepository = _FakeHouseholdRepository(
      members: const [],
      splits: const [],
    );

    _TestRecurringTransactionsNotifier? recurringNotifier;
    final transaction = _recurringExpense(id: 'exp_delete', householdId: 'h1');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _MockAuth()),
        ..._defaultWalletOverrides(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        householdRepositoryProvider.overrideWithValue(householdRepository),
        userHouseholdsProvider('user_1').overrideWith(
          (ref) => UserHouseholdsNotifier(householdRepository, 'user_1', ref)
            ..state = AsyncValue.data(
              [
                Household(
                  id: 'h1',
                  name: 'Test Household',
                  ownerId: 'user_1',
                  currency: 'USD',
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
        ),
        recurringTransactionsProvider('h1').overrideWith((ref) {
          recurringNotifier = _TestRecurringTransactionsNotifier(
            ref,
            'h1',
            transaction,
          );
          return recurringNotifier!;
        }),
        householdScopeProvider.overrideWith((ref) {
          final viewMode = ref.watch(viewModeProvider).mode;
          final selected = ref.watch(selectedHouseholdProvider);
          return HouseholdScope(
            viewMode: viewMode,
            selected: selected,
            portfolioHouseholdIds: const {},
          );
        }),
        selectedHouseholdProvider.overrideWith(
          (ref) => SelectedHouseholdNotifier(ref, prefs, 'user_1'),
        ),
        viewModeProvider.overrideWith(
          (ref) => ViewModeNotifier()..setMode(ViewMode.personal),
        ),
        homeFilterProvider.overrideWith(
          (ref) => HomeFilterNotifier()..setSelectedCurrency('USD'),
        ),
      ],
    );

    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddRecurringSheet(
              type: 'expense',
              existingTransaction: transaction,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AddRecurringSheet));
    final l10n = AppLocalizations.of(context)!;
    final deleteButton = find.text(l10n.deleteRecurringTransaction);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text(l10n.deleteEntireSeries), findsOneWidget);
    expect(find.text(l10n.skipNextOccurrence), findsOneWidget);

    await tester.tap(find.text(l10n.deleteEntireSeries));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(recurringNotifier, isNotNull);
    expect(recurringNotifier!.deleteCalled, isTrue);
    expect(recurringNotifier!.deletedTransactionId, transaction.id);
    expect(recurringNotifier!.skipCalled, isFalse);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Delete dialog can skip the next occurrence', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final householdRepository = _FakeHouseholdRepository(
      members: const [],
      splits: const [],
    );

    _TestRecurringTransactionsNotifier? recurringNotifier;
    final transaction = _recurringExpense(id: 'exp_skip', householdId: 'h1');
    final expectedSkippedDate = transaction.getNextSkippableOccurrence();

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _MockAuth()),
        ..._defaultWalletOverrides(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        householdRepositoryProvider.overrideWithValue(householdRepository),
        userHouseholdsProvider('user_1').overrideWith(
          (ref) => UserHouseholdsNotifier(householdRepository, 'user_1', ref)
            ..state = AsyncValue.data(
              [
                Household(
                  id: 'h1',
                  name: 'Test Household',
                  ownerId: 'user_1',
                  currency: 'USD',
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
        ),
        recurringTransactionsProvider('h1').overrideWith((ref) {
          recurringNotifier = _TestRecurringTransactionsNotifier(
            ref,
            'h1',
            transaction,
          );
          return recurringNotifier!;
        }),
        householdScopeProvider.overrideWith((ref) {
          final viewMode = ref.watch(viewModeProvider).mode;
          final selected = ref.watch(selectedHouseholdProvider);
          return HouseholdScope(
            viewMode: viewMode,
            selected: selected,
            portfolioHouseholdIds: const {},
          );
        }),
        selectedHouseholdProvider.overrideWith(
          (ref) => SelectedHouseholdNotifier(ref, prefs, 'user_1'),
        ),
        viewModeProvider.overrideWith(
          (ref) => ViewModeNotifier()..setMode(ViewMode.personal),
        ),
        homeFilterProvider.overrideWith(
          (ref) => HomeFilterNotifier()..setSelectedCurrency('USD'),
        ),
      ],
    );

    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddRecurringSheet(
              type: 'expense',
              existingTransaction: transaction,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AddRecurringSheet));
    final l10n = AppLocalizations.of(context)!;
    final deleteButton = find.text(l10n.deleteRecurringTransaction);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.skipNextOccurrence));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(recurringNotifier, isNotNull);
    expect(recurringNotifier!.skipCalled, isTrue);
    expect(recurringNotifier!.skippedTransactionId, transaction.id);
    expect(recurringNotifier!.skippedDate, expectedSkippedDate);
    expect(recurringNotifier!.deleteCalled, isFalse);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'Edit in personal view exposes space selection and saves moved scope with the chosen wallet',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final householdRepository = _FakeHouseholdRepository(
      members: <HouseholdMember>[
        _member('user_1', 'Alice'),
        _member('user_2', 'Bob'),
      ],
      splits: const [],
    );

    final households = <Household>[
      Household(
        id: 'h1',
        name: 'Test Household',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Household(
        id: 'p1',
        name: 'Private Space',
        ownerId: 'user_1',
        currency: 'USD',
        isPortfolio: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];
    final personalWallets = <WalletEntity>[
      _wallet(id: 'w_personal_default', name: 'Cash', isDefault: true),
      _wallet(id: 'w_personal_alt', name: 'Main Card'),
    ];
    final householdWallets = <WalletEntity>[
      _wallet(
        id: 'w_household_default',
        name: 'Shared Wallet',
        householdId: 'h1',
        isDefault: true,
      ),
      _wallet(
        id: 'w_household_alt',
        name: 'Family Card',
        householdId: 'h1',
      ),
    ];

    _TestRecurringSaveNotifier? saveNotifier;

    final container = ProviderContainer(
      overrides: [
        recurringTransactionSaveProvider.overrideWith((ref) {
          saveNotifier = _TestRecurringSaveNotifier(ref);
          return saveNotifier!;
        }),
        authProvider.overrideWith(() => _MockAuth()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        householdRepositoryProvider.overrideWithValue(householdRepository),
        userHouseholdsProvider('user_1').overrideWith(
          (ref) => UserHouseholdsNotifier(householdRepository, 'user_1', ref)
            ..state = AsyncValue.data(households),
        ),
        walletsByHouseholdIdProvider(null).overrideWith(
          (ref) async => personalWallets,
        ),
        walletsByHouseholdIdProvider('h1').overrideWith(
          (ref) async => householdWallets,
        ),
        householdMembersProvider('h1').overrideWith(
          (ref) => HouseholdMembersNotifier(householdRepository, 'h1'),
        ),
        householdScopeProvider.overrideWith((ref) {
          final viewMode = ref.watch(viewModeProvider).mode;
          final selected = ref.watch(selectedHouseholdProvider);
          return HouseholdScope(
            viewMode: viewMode,
            selected: selected,
            portfolioHouseholdIds: const {'p1'},
          );
        }),
        selectedHouseholdProvider.overrideWith(
          (ref) => SelectedHouseholdNotifier(ref, prefs, 'user_1'),
        ),
        viewModeProvider.overrideWith(
          (ref) => ViewModeNotifier()..setMode(ViewMode.personal),
        ),
        homeFilterProvider.overrideWith(
          (ref) => HomeFilterNotifier()..setSelectedCurrency('USD'),
        ),
      ],
    );

    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddRecurringSheet(
              type: 'expense',
              existingTransaction: _recurringExpense(
                id: 'exp_move_scope',
                accountId: 'w_personal_default',
                recurrenceRule: RecurrenceRule(
                  frequency: 'monthly',
                  anchorDate: DateTime(2026, 1, 1),
                  endDate: DateTime(2026, 12, 31),
                  interval: 2,
                  reminderEnabled: true,
                  reminderValue: 3,
                  reminderUnit: 'days',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AddRecurringSheet));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.space), findsOneWidget);

    await tester.tap(find.text(l10n.space));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Test Household').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.wallet));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family Card').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(saveNotifier, isNotNull);
    expect(saveNotifier!.updateCalled, isTrue);
    expect(saveNotifier!.lastUpdateArgs?['householdId'], 'h1');
    expect(saveNotifier!.lastUpdateArgs?['previousHouseholdId'], isNull);
    expect(saveNotifier!.lastUpdateArgs?['accountId'], 'w_household_alt');
    expect(saveNotifier!.lastUpdateArgs?['frequency'], 'monthly');
    expect(saveNotifier!.lastUpdateArgs?['interval'], 2);
    expect(
      saveNotifier!.lastUpdateArgs?['endDate'],
      DateTime(2026, 12, 31),
    );
    expect(saveNotifier!.lastUpdateArgs?['hasReminder'], isTrue);
    expect(saveNotifier!.lastUpdateArgs?['reminderValue'], 3);
    expect(saveNotifier!.lastUpdateArgs?['reminderUnit'], 'days');
    await tester.pump(const Duration(seconds: 3));
  });
}
