import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_user_context_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/connect_social_banner.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

class _FakeAnalyticsNotifier extends AnalyticsNotifier {
  _FakeAnalyticsNotifier(super.ref, this.initialExpenses) {
    state = AnalyticsData(allExpenses: initialExpenses);
  }

  final List<ExpenseEntry> initialExpenses;

  @override
  Future<void> loadData(
    String userId, {
    int retryCount = 0,
    bool forceReload = false,
  }) async {}
}

class _FakeWhatsAppBinding extends WhatsAppBinding {
  _FakeWhatsAppBinding(this.value);

  final bool value;

  @override
  Future<bool> build() async => value;
}

class _FakeTelegramBinding extends TelegramBinding {
  _FakeTelegramBinding(this.value);

  final bool value;

  @override
  Future<bool> build() async => value;
}

class _FakeHouseholdRepository implements HouseholdRepository {
  @override
  Future<List<Household>> getUserHouseholds(String userId) async {
    return <Household>[_householdFixture(userId)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Household _householdFixture(String ownerId) {
  final now = DateTime(2026, 1, 2);
  return Household(
    id: 'household-1',
    name: 'Shared space',
    ownerId: ownerId,
    currency: 'USD',
    createdAt: now,
    updatedAt: now,
  );
}

class _LoadedRecurringTransactionsNotifier
    extends RecurringTransactionsNotifier {
  _LoadedRecurringTransactionsNotifier(
    Ref ref,
    this.transactions,
  ) : super(ref, null) {
    state = RecurringTransactionsState(
      data: AsyncValue.data(transactions),
      hasLoadedOnce: true,
    );
  }

  final List<RecurringTransaction> transactions;

  @override
  Future<void> loadRecurringTransactions(
    String userId, {
    int limit = 250,
    bool forceRefresh = false,
  }) async {
    state = RecurringTransactionsState(
      data: AsyncValue.data(transactions),
      hasLoadedOnce: true,
    );
  }
}

RecurringTransaction _recurringExpenseFixture() {
  final now = DateTime(2026, 1, 2);
  return RecurringTransaction(
    id: 'recurring-1',
    userId: 'user-1',
    date: now,
    category: 'subscriptions',
    amount: 12,
    currency: 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    type: 'expense',
    attachments: const [],
    createdAt: now,
  );
}

final _walletCaptureCompleterProvider =
    StateProvider<Completer<bool>>((ref) => Completer<bool>());

void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    required AppUser user,
    required List<ExpenseEntry> expenses,
    required bool whatsappConnected,
    required bool telegramConnected,
    required bool walletCaptureEnabled,
    bool emailImportEnabled = false,
    bool hasLoggedTransactions = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final recurringTransactions = expenses.any((expense) => expense.isRecurring)
        ? <RecurringTransaction>[_recurringExpenseFixture()]
        : const <RecurringTransaction>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(() => _TestAuth(user)),
          householdRepositoryProvider.overrideWithValue(
            _FakeHouseholdRepository(),
          ),
          preloadedUserHouseholdsProvider(user.uid).overrideWith(
            (ref) => <Household>[_householdFixture(user.uid)],
          ),
          householdScopeProvider.overrideWith(
            (ref) => const HouseholdScope(
              viewMode: ViewMode.personal,
              selected: SelectedHouseholdState(),
              portfolioHouseholdIds: <String>{},
            ),
          ),
          analyticsProvider.overrideWith((ref) {
            final notifier = _FakeAnalyticsNotifier(ref, expenses);
            return notifier;
          }),
          dashboardHasLoggedTransactionsProvider.overrideWith(
            (ref) async => hasLoggedTransactions,
          ),
          whatsAppBindingProvider.overrideWith(
            () => _FakeWhatsAppBinding(whatsappConnected),
          ),
          telegramBindingProvider.overrideWith(
            () => _FakeTelegramBinding(telegramConnected),
          ),
          walletCaptureEnabledProvider.overrideWith(
            (ref) async => walletCaptureEnabled,
          ),
          emailImportEnabledProvider
              .overrideWith((ref) async => emailImportEnabled),
          recurringTransactionsProvider(null).overrideWith(
            (ref) => _LoadedRecurringTransactionsNotifier(
              ref,
              recurringTransactions,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConnectSocialBanner(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('sorts incomplete steps before completed steps', (
    tester,
  ) async {
    final expenses = [
      ExpenseEntry(
        id: 'expense-2',
        userId: 'user-1',
        householdId: null,
        amountCents: 1200,
        currency: 'USD',
        category: 'subscriptions',
        date: DateTime(2026, 1, 2),
        type: 'expense',
        isRecurring: true,
        createdAt: DateTime(2026, 1, 2),
        rawText: 'Monthly plan',
      ),
    ];

    await pumpBanner(
      tester,
      user: const AppUser(uid: 'user-1', email: 'user@test.com'),
      expenses: expenses,
      whatsappConnected: false,
      telegramConnected: false,
      walletCaptureEnabled: true,
    );

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;
    final captureTitle = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? l10n.applePayIntegration
        : l10n.autoCapture;

    expect(find.text(l10n.setupChecklist), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(l10n.connectChat)).dx,
      lessThan(tester.getTopLeft(find.text(l10n.createSpace)).dx),
    );
    expect(
      tester.getTopLeft(find.text(l10n.emailFileImportEnableSwitchTitle)).dx,
      lessThan(tester.getTopLeft(find.text(l10n.createSpace)).dx),
    );
    expect(
      tester.getTopLeft(find.text(l10n.createSpace)).dx,
      lessThan(tester.getTopLeft(find.text(l10n.logExpense)).dx),
    );
    expect(
      tester.getTopLeft(find.text(l10n.logExpense)).dx,
      lessThan(tester.getTopLeft(find.text(l10n.setRecurring)).dx),
    );
    expect(
      tester.getTopLeft(find.text(l10n.setRecurring)).dx,
      lessThan(tester.getTopLeft(find.text(captureTitle)).dx),
    );

    final firstCardSize = tester.getSize(
      find.byKey(const ValueKey('connect-social-card-create_space')),
    );
    final secondCardSize = tester.getSize(
      find.byKey(const ValueKey('connect-social-card-connect_chat')),
    );
    expect(firstCardSize, secondCardSize);
  });

  testWidgets(
      'hides when all checklist items are complete and treats either app as connected',
      (
    tester,
  ) async {
    final expenses = [
      ExpenseEntry(
        id: 'expense-1',
        userId: 'user-1',
        householdId: null,
        amountCents: 2500,
        currency: 'USD',
        category: 'food',
        date: DateTime(2026, 1, 1),
        type: 'expense',
        isRecurring: false,
        createdAt: DateTime(2026, 1, 1),
        rawText: 'Lunch',
      ),
      ExpenseEntry(
        id: 'expense-2',
        userId: 'user-1',
        householdId: null,
        amountCents: 1200,
        currency: 'USD',
        category: 'subscriptions',
        date: DateTime(2026, 1, 2),
        type: 'expense',
        isRecurring: true,
        createdAt: DateTime(2026, 1, 2),
        rawText: 'Monthly plan',
      ),
    ];

    await pumpBanner(
      tester,
      user: const AppUser(uid: 'user-1', email: 'user@test.com'),
      expenses: expenses,
      whatsappConnected: false,
      telegramConnected: true,
      walletCaptureEnabled: true,
      emailImportEnabled: true,
    );

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.setupChecklist), findsNothing);
    expect(find.byType(ConnectSocialBanner), findsOneWidget);
  });

  testWidgets(
      'keeps the resolved checklist visible while wallet check refreshes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const user = AppUser(uid: 'user-1', email: 'user@test.com');
    late WidgetRef bannerRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(() => _TestAuth(user)),
          householdRepositoryProvider.overrideWithValue(
            _FakeHouseholdRepository(),
          ),
          preloadedUserHouseholdsProvider(user.uid).overrideWith(
            (ref) => <Household>[_householdFixture(user.uid)],
          ),
          householdScopeProvider.overrideWith(
            (ref) => const HouseholdScope(
              viewMode: ViewMode.personal,
              selected: SelectedHouseholdState(),
              portfolioHouseholdIds: <String>{},
            ),
          ),
          analyticsProvider.overrideWith((ref) {
            return _FakeAnalyticsNotifier(ref, const <ExpenseEntry>[]);
          }),
          dashboardHasLoggedTransactionsProvider.overrideWith(
            (ref) async => false,
          ),
          whatsAppBindingProvider.overrideWith(
            () => _FakeWhatsAppBinding(false),
          ),
          telegramBindingProvider.overrideWith(
            () => _FakeTelegramBinding(false),
          ),
          walletCaptureEnabledProvider.overrideWith(
            (ref) => ref.watch(_walletCaptureCompleterProvider).future,
          ),
          emailImportEnabledProvider.overrideWith((ref) async => false),
          recurringTransactionsProvider(null).overrideWith(
            (ref) => _LoadedRecurringTransactionsNotifier(
              ref,
              const <RecurringTransaction>[],
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            bannerRef = ref;
            return const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ConnectSocialBanner(),
              ),
            );
          },
        ),
      ),
    );

    bannerRef.read(_walletCaptureCompleterProvider).complete(true);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.setupChecklist), findsOneWidget);

    bannerRef.read(_walletCaptureCompleterProvider.notifier).state =
        Completer<bool>();
    await tester.pump();

    expect(find.text(l10n.setupChecklist), findsOneWidget);
  });
}
