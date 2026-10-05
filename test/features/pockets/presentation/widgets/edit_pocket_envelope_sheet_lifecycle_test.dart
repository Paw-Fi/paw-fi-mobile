import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/data/pocket_month_mutation_service.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user', email: 'user@example.com');
}

class _PendingPockets extends StateNotifier<PocketsState>
    implements PocketsNotifier {
  _PendingPockets() : super(PocketsState.initial());

  final pending = Completer<PocketMonthWriteResult>();
  bool dispatched = false;
  bool synced = false;
  bool cancelled = false;
  bool restored = false;
  bool reloaded = false;

  @override
  void applyOptimisticPockets({
    required List<PocketEnvelope> pockets,
    double? totalBudget,
    String? budgetId,
    Map<String, List<String>>? envelopeCategories,
  }) {
    state = state.copyWith(saved: pockets, editing: pockets);
  }

  @override
  Future<PocketsMutationHandle> queueCurrentPocketsSnapshotForSync({
    List<String> deletedPocketIds = const [],
    PocketsState? rollbackState,
    bool replaceCategories = true,
  }) async =>
      const PocketsMutationHandle(
          clientMutationId: 'mutation', revision: 'revision');

  @override
  Future<PocketMonthWriteResult> persistQueuedPocketsSnapshotNow(
      PocketsMutationHandle mutation) {
    dispatched = true;
    return pending.future;
  }

  @override
  Future<void> markQueuedPocketsSnapshotSynced(
      PocketsMutationHandle mutation) async {
    synced = true;
  }

  @override
  Future<void> load({bool bypassCache = false}) async {
    reloaded = true;
  }

  @override
  Future<void> cancelQueuedPocketsSnapshot(
      PocketsMutationHandle mutation, Object error) async {
    cancelled = true;
  }

  @override
  Future<void> restoreOptimisticPockets(PocketsState previousState,
      {PocketsMutationHandle? mutation}) async {
    restored = true;
    state = previousState;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final outcome in ['success', 'terminal failure', 'offline']) {
    testWidgets('Pocket $outcome reconciles after the sheet is disposed',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scope = PocketsScopeParams(
        scope: PocketsScopeType.household,
        householdId: 'household',
        currency: 'USD',
        periodMonth: DateTime(2026, 10),
      );
      final notifier = _PendingPockets();
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_TestAuth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        userCategoryListsProvider.overrideWith((ref) async =>
            const UserCategoryLists(
                expenseCategories: ['groceries'], incomeCategories: [])),
        pocketsProvider(scope).overrideWith((ref) => notifier),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditPocketEnvelopeSheet(
              scopeParams: scope,
              totalBudget: 100,
              unallocatedBudget: 100,
              budgetId: 'budget',
              initialCategories: const ['groceries'],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Groceries');
      await tester.ensureVisible(find.byType(Slider));
      await tester.tap(find.byType(Slider));
      await tester.pump();
      await tester.ensureVisible(find.byType(MonekoSheetConfirmButton));
      await tester.tap(find.byType(MonekoSheetConfirmButton));
      await tester.pump();
      expect(notifier.dispatched, isTrue);
      expect(notifier.state.saved, hasLength(1));

      // Keep the app's provider container alive while removing the route.
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const SizedBox.shrink()));
      if (outcome == 'success') {
        notifier.pending.complete(PocketMonthWriteResult(
          budgetId: 'budget',
          revision: 1,
          canonicalPocketIds: {notifier.state.saved.single.id: 'saved-pocket'},
        ));
      } else {
        notifier.pending.completeError(outcome == 'offline'
            ? TimeoutException('offline')
            : const PostgrestException(message: 'duplicate', code: '23505'));
      }
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(notifier.synced, outcome == 'success');
      expect(notifier.reloaded, outcome == 'success');
      expect(notifier.cancelled, outcome == 'terminal failure');
      expect(notifier.restored, outcome == 'terminal failure');
      expect(notifier.state.saved,
          outcome == 'terminal failure' ? isEmpty : hasLength(1));
    });
  }
}
