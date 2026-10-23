import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/household_invitation_sheet.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/data/models/subscription_details.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

const _joinedId = '00000000-0000-0000-0000-000000000001';
final _actorProvider = StateProvider<String?>((ref) => 'actor');
final _english = lookupAppLocalizations(const Locale('en'));

Household _household(String id) => Household(
      id: id,
      name: '家族',
      ownerId: 'owner',
      currency: 'EUR',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Map<String, dynamic> _validation({bool alreadyMember = false}) => {
      'valid': !alreadyMember,
      if (alreadyMember) 'error_code': 'ALREADY_MEMBER',
      'household': {'id': _joinedId, 'name': '家族'},
      'invite': {'is_reusable': true, 'invited_role': 'member'},
    };

class _Repository extends Mock implements HouseholdRepository {}

class _Households extends UserHouseholdsNotifier {
  _Households(super.repository, super.userId, super.ref, this.events,
      this.refresh, this.includesJoinedHousehold)
      : super(initialHouseholds: [_household('cached')]);

  final List<String> events;
  final Future<void> Function() refresh;
  final bool Function() includesJoinedHousehold;

  @override
  Future<void> load() async {
    events.add('refresh');
    await refresh();
    if (!mounted) return;
    state = AsyncData([
      _household('cached'),
      if (includesJoinedHousehold()) _household(_joinedId),
    ]);
    events.add('refreshed');
  }
}

class _Selection extends SelectedHouseholdNotifier {
  _Selection(super.ref, super.prefs, super.userId, this.events, this.select,
      this.resolveSelection);

  final List<String> events;
  final Future<void> Function() select;
  final bool Function() resolveSelection;

  @override
  Future<void> selectHousehold(String householdId) async {
    events.add('select');
    await select();
    if (!mounted) return;
    state = resolveSelection()
        ? SelectedHouseholdState(
            householdId: householdId, household: _household(householdId))
        : const SelectedHouseholdState(error: 'Selection unavailable');
    events.add('selected');
  }
}

class _Subscription extends SubscriptionNotifier {
  _Subscription(this.events);
  final List<String> events;
  @override
  Future<Subscription?> build() async {
    events.add('subscription');
    return null;
  }
}

class _Management extends SubscriptionManagementNotifier {
  _Management(this.events);
  final List<String> events;
  @override
  Future<SubscriptionDetails?> build() async {
    events.add('management');
    return null;
  }
}

class _Harness {
  _Harness(this.repository);
  final _Repository repository;
  final events = <String>[];
  late ProviderContainer container;
  late GoRouter router;
  Future<void> Function() refresh = () async {};
  Future<void> Function() select = () async {};
  bool resolveSelection = true;
  bool includesJoinedHousehold = true;

  Future<void> mount(
    WidgetTester tester, {
    bool confirmJoin = true,
  }) async {
    SharedPreferences.setMockInitialValues({'moneko_view_mode': 'personal'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_actorProvider)),
      householdRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(prefs),
      userHouseholdsProvider.overrideWith((ref, userId) => _Households(
          repository,
          userId,
          ref,
          events,
          () => refresh(),
          () => includesJoinedHousehold)),
      selectedHouseholdProvider.overrideWith((ref) => _Selection(
          ref, prefs, 'actor', events, () => select(), () => resolveSelection)),
      subscriptionNotifierProvider.overrideWith(() => _Subscription(events)),
      subscriptionManagementProvider.overrideWith(() => _Management(events)),
      householdProvider.overrideWith((ref, id) async {
        events.add('info:$id');
        return _household(id);
      }),
    ]);
    addTearDown(container.dispose);
    when(() => repository.getHouseholdMembers(any()))
        .thenAnswer((_) async => []);
    container.listen(subscriptionNotifierProvider, (_, __) {});
    container.listen(subscriptionManagementProvider, (_, __) {});
    container.listen(householdProvider(_joinedId), (_, __) {});
    container.listen(householdMembersProvider(_joinedId), (_, __) {});
    container.read(userHouseholdsProvider('actor'));
    router = GoRouter(initialLocation: '/invite', routes: [
      GoRoute(
        path: '/invite',
        builder: (_, __) =>
            const Scaffold(body: HouseholdInvitationSheet(token: 'token')),
      ),
      GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('Dashboard'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    ));
    await tester.pump();
    if (confirmJoin) await confirmJoinFromPreview(tester);
  }

  /// The sheet only accepts after the user confirms from the preview.
  Future<void> confirmJoinFromPreview(WidgetTester tester) async {
    await tester.pump();
    final join = find.text(_english.joinHouseholdName('家族'));
    if (join.evaluate().isEmpty) return;
    await tester.tap(join);
    await tester.pump();
  }
}

void main() {
  group('sheet preview', () {
    Map<String, dynamic> richValidation() => {
          ..._validation(),
          'household': {
            'id': _joinedId,
            'name': '家族',
            'cover_image_url': null,
          },
          'inviter': {'id': 'owner', 'email': 'a@b.c', 'full_name': 'Aiko'},
          'invite': {
            'is_reusable': false,
            'invited_role': 'admin',
            'personal_message': 'Welcome to our shared budget!',
          },
          'expires_at':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        };

    testWidgets('shows the Space before joining and waits for Join',
        (tester) async {
      final repository = _Repository();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => richValidation());
      when(() => repository.acceptInvite('token')).thenAnswer(
          (_) async => {'success': true, 'household_id': _joinedId});
      final harness = _Harness(repository);
      await harness.mount(tester, confirmJoin: false);
      await tester.pumpAndSettle();

      expect(find.text('家族'), findsOneWidget);
      expect(find.text(_english.invitedBy('Aiko')), findsOneWidget);
      expect(
          find.textContaining('Welcome to our shared budget!'), findsOneWidget);
      expect(find.text("You'll join as ${_english.admin}"), findsOneWidget);
      expect(find.text(_english.invitationValidUntilLabel), findsOneWidget);
      verifyNever(() => repository.acceptInvite(any()));
      expect(harness.events, isNot(contains('refresh')));

      final join = find.text(_english.joinHouseholdName('家族'));
      await tester.ensureVisible(join);
      await tester.pumpAndSettle();
      await tester.tap(join);
      await tester.pumpAndSettle();
      verify(() => repository.acceptInvite('token')).called(1);
      expect(find.text(_english.viewHousehold), findsOneWidget);
    });

    testWidgets('Not now closes without joining', (tester) async {
      final repository = _Repository();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => richValidation());
      final harness = _Harness(repository);
      await harness.mount(tester, confirmJoin: false);
      harness.router.go('/dashboard');
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Dashboard'));
      unawaited(showHouseholdInvitationSheet(context, token: 'token'));
      await tester.pumpAndSettle();
      expect(find.text(_english.joinHouseholdName('家族')), findsOneWidget);

      await tester.ensureVisible(find.text(_english.notNow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_english.notNow));
      await tester.pumpAndSettle();
      expect(find.text(_english.joinHouseholdName('家族')), findsNothing);
      verifyNever(() => repository.acceptInvite(any()));
      expect(harness.events, isNot(contains('refresh')));
    });

    testWidgets('cannot be swiped away while the join is in flight',
        (tester) async {
      // A tall screen so the preview fits and the sheet itself owns the drag.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository();
      final accepted = Completer<Map<String, dynamic>>();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => _validation());
      when(() => repository.acceptInvite('token'))
          .thenAnswer((_) => accepted.future);
      final harness = _Harness(repository);
      await harness.mount(tester, confirmJoin: false);
      harness.router.go('/dashboard');
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Dashboard'));
      unawaited(showHouseholdInvitationSheet(context, token: 'token'));
      await tester.pumpAndSettle();

      final join = find.text(_english.joinHouseholdName('家族'));
      await tester.ensureVisible(join);
      await tester.pumpAndSettle();
      await tester.tap(join);
      await tester.pump();
      await tester.fling(
          find.byType(CircularProgressIndicator), const Offset(0, 500), 2000);
      // The join spinner never settles; advance past the dismiss animation.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(_english.joiningHousehold), findsOneWidget);

      accepted.complete({'success': true, 'household_id': _joinedId});
      await tester.pumpAndSettle();
      expect(find.text(_english.viewHousehold), findsOneWidget);
      expect(harness.events, contains('refreshed'));
    });

    testWidgets('validation failure shows the error without a preview',
        (tester) async {
      final repository = _Repository();
      when(() => repository.validateInvite('token')).thenAnswer((_) async => {
            'valid': false,
            'error_code': 'EXPIRED',
            'error': 'This invitation has expired',
            'household': {'id': _joinedId, 'name': '家族'},
          });
      final harness = _Harness(repository);
      await harness.mount(tester, confirmJoin: false);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text(_english.joinHouseholdName('家族')), findsNothing);
      verifyNever(() => repository.acceptInvite(any()));
    });
  });

  group('sheet', () {
    testWidgets('reconciles before success and retains cached list',
        (tester) async {
      final repository = _Repository();
      final accepted = Completer<Map<String, dynamic>>();
      final refreshed = Completer<void>();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => _validation());
      when(() => repository.acceptInvite('token'))
          .thenAnswer((_) => accepted.future);
      final harness = _Harness(repository)..refresh = () => refreshed.future;
      await harness.mount(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(harness.events, isNot(contains('refresh')));
      accepted.complete({'success': true, 'household_id': _joinedId});
      await tester.pump();
      expect(harness.events, contains('refresh'));
      expect(
          harness.container
              .read(userHouseholdsProvider('actor'))
              .value!
              .map((h) => h.id),
          ['cached']);
      expect(find.text(_english.youreIn), findsNothing);
      expect(find.text('Dashboard'), findsNothing);
      refreshed.complete();
      await tester.pumpAndSettle();
      expect(
          harness.container
              .read(userHouseholdsProvider('actor'))
              .value!
              .map((h) => h.id),
          ['cached', _joinedId]);
      expect(harness.events.where((e) => e == 'subscription').length, 2);
      expect(harness.events.where((e) => e == 'management').length, 2);
      expect(harness.events.where((e) => e == 'info:$_joinedId').length, 2);
      verify(() => repository.getHouseholdMembers(_joinedId)).called(2);
      expect(find.text(_english.viewHousehold), findsOneWidget);
      expect(harness.events, isNot(contains('select')));
    });

    testWidgets('reconciles ALREADY_MEMBER without accepting again',
        (tester) async {
      final repository = _Repository();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => _validation(alreadyMember: true));
      final harness = _Harness(repository);
      await harness.mount(tester);
      await tester.pumpAndSettle();
      verifyNever(() => repository.acceptInvite(any()));
      expect(harness.events, contains('refreshed'));
      expect(find.text(_english.viewHousehold), findsOneWidget);
    });

    testWidgets('reconciles a pre-join in-flight list read', (tester) async {
      final repository = _Repository();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => _validation());
      when(() => repository.acceptInvite('token')).thenAnswer(
          (_) async => {'success': true, 'household_id': _joinedId});
      final harness = _Harness(repository);
      var reads = 0;
      harness.refresh = () async {
        reads++;
        harness.includesJoinedHousehold = reads > 1;
      };
      await harness.mount(tester);
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(
          harness.container
              .read(userHouseholdsProvider('actor'))
              .value!
              .map((household) => household.id),
          ['cached', _joinedId]);
      expect(find.text(_english.viewHousehold), findsOneWidget);
    });

    for (final error in [
      const FunctionException(status: 409, details: {
        'error_code': 'ACCEPTED',
        'error': 'This invitation has already been accepted',
      }),
      const FunctionException(status: 410, details: {
        'error_code': 'REVOKED',
        'error': 'This invitation has been revoked',
      }),
      Exception('409 already consumed'),
      TimeoutException('offline'),
    ]) {
      testWidgets('rejects acceptance failure $error', (tester) async {
        final repository = _Repository();
        when(() => repository.validateInvite('token'))
            .thenAnswer((_) async => _validation());
        when(() => repository.acceptInvite('token')).thenThrow(error);
        final harness = _Harness(repository);
        await harness.mount(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Dashboard'), findsNothing);
        expect(harness.events, isNot(contains('refresh')));
        expect(harness.events, isNot(contains('select')));
      });
    }

    for (final response in [
      {'success': false, 'household_id': _joinedId, 'error': 'Rejected'},
      {'household_id': _joinedId},
      {'success': true},
    ]) {
      testWidgets('rejects unconfirmed response $response', (tester) async {
        final repository = _Repository();
        when(() => repository.validateInvite('token'))
            .thenAnswer((_) async => _validation());
        when(() => repository.acceptInvite('token'))
            .thenAnswer((_) async => response);
        final harness = _Harness(repository);
        await harness.mount(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(harness.events, isNot(contains('refresh')));
      });
    }

    for (final stage in ['validate', 'accept', 'refresh']) {
      for (final dispose in [false, true]) {
        testWidgets(
            'ignores $stage after '
            '${dispose ? 'disposal' : 'actor change'}', (tester) async {
          final repository = _Repository();
          final validated = Completer<Map<String, dynamic>>();
          final accepted = Completer<Map<String, dynamic>>();
          final refreshed = Completer<void>();
          when(() => repository.validateInvite('token')).thenAnswer((_) =>
              stage == 'validate'
                  ? validated.future
                  : Future.value(_validation()));
          when(() => repository.acceptInvite('token')).thenAnswer((_) =>
              stage == 'accept'
                  ? accepted.future
                  : Future.value({'success': true, 'household_id': _joinedId}));
          final harness = _Harness(repository)
            ..refresh =
                () => stage == 'refresh' ? refreshed.future : Future.value();
          await harness.mount(tester);
          await tester.pump();
          if (dispose) {
            await tester.pumpWidget(const SizedBox.shrink());
          } else {
            harness.container.read(_actorProvider.notifier).state = 'other';
            expect(harness.container.read(currentUserIdProvider), 'other');
            await tester.pump();
            harness.container.read(_actorProvider.notifier).state = 'actor';
            expect(harness.container.read(currentUserIdProvider), 'actor');
            await tester.pump();
          }
          if (stage == 'validate') validated.complete(_validation());
          if (stage == 'accept') {
            accepted.complete({'success': true, 'household_id': _joinedId});
          }
          if (stage == 'refresh') refreshed.complete();
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          expect(find.text(_english.viewHousehold), findsNothing);
          expect(find.text('Dashboard'), findsNothing);
          expect(harness.events, isNot(contains('select')));
          if (stage == 'validate') {
            verifyNever(() => repository.acceptInvite(any()));
          }
          if (stage != 'refresh') {
            expect(harness.events, isNot(contains('refresh')));
          }
        });
      }
    }
  });

  group('sheet View', () {
    testWidgets('selects the joined Space after refresh and switches mode',
        (tester) async {
      final repository = _Repository();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => _validation());
      when(() => repository.acceptInvite('token')).thenAnswer(
          (_) async => {'success': true, 'household_id': _joinedId});
      final harness = _Harness(repository);
      await harness.mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_english.viewHousehold));
      await tester.pumpAndSettle();
      expect(harness.events.where((e) => e == 'select').length, 1);
      expect(harness.events.lastIndexOf('refreshed'),
          lessThan(harness.events.indexOf('select')));
      expect(harness.container.read(selectedHouseholdProvider).householdId,
          _joinedId);
      expect(harness.container.read(viewModeProvider).mode, ViewMode.household);
    });

    testWidgets('rejects failed selection', (tester) async {
      final repository = _Repository();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => _validation(alreadyMember: true));
      final harness = _Harness(repository)..resolveSelection = false;
      await harness.mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_english.viewHousehold));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selection unavailable'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      expect(harness.container.read(viewModeProvider).mode, ViewMode.personal);
    });

    for (final dispose in [false, true]) {
      testWidgets(
          'ignores selection after '
          '${dispose ? 'disposal' : 'actor change'}', (tester) async {
        final repository = _Repository();
        final selected = Completer<void>();
        when(() => repository.validateInvite('token'))
            .thenAnswer((_) async => _validation(alreadyMember: true));
        final harness = _Harness(repository)..select = () => selected.future;
        await harness.mount(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text(_english.viewHousehold));
        await tester.pump();
        expect(harness.events, contains('select'));
        expect(
            harness.container.read(viewModeProvider).mode, ViewMode.personal);
        if (dispose) {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          harness.container.read(_actorProvider.notifier).state = 'other';
          await tester.pump();
        }
        selected.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        expect(find.text('Dashboard'), findsNothing);
        expect(
            harness.container.read(viewModeProvider).mode, ViewMode.personal);
      });
    }
  });

  for (final dispose in [false, true]) {
    testWidgets(
        'sheet View guards delayed refresh after '
        '${dispose ? 'disposal' : 'actor change'}', (tester) async {
      final repository = _Repository();
      final refreshed = Completer<void>();
      when(() => repository.validateInvite('token'))
          .thenAnswer((_) async => _validation(alreadyMember: true));
      final harness = _Harness(repository);
      await harness.mount(tester);
      await tester.pumpAndSettle();
      harness.refresh = () => refreshed.future;
      await tester.tap(find.text(_english.viewHousehold));
      await tester.pump();
      await tester.tap(find.text(_english.viewHousehold));
      await tester.pump();
      expect(harness.events.where((e) => e == 'refresh').length, 2);
      if (dispose) {
        await tester.pumpWidget(const SizedBox.shrink());
      } else {
        harness.container.read(_actorProvider.notifier).state = 'other';
        await tester.pump();
      }
      refreshed.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(harness.events, isNot(contains('select')));
      expect(harness.container.read(viewModeProvider).mode, ViewMode.personal);
    });
  }
}
