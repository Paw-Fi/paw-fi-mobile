import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/home_header_sliver.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/pages/create_space_page.dart';
import 'package:moneko/features/households/presentation/pages/invite_members_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';

class _Repository extends Mock implements HouseholdRepository {}

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'u1', email: 'user@example.com');
}

class _Subscription extends SubscriptionNotifier {
  @override
  Future<Subscription?> build() async => null;
}

Household _space(String id, {bool private = false}) => Household(
      id: id,
      name: 'Space $id',
      ownerId: id == 'old' ? 'someone-else' : 'u1',
      currency: 'USD',
      isPortfolio: private,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUpAll(() => registerFallbackValue(HouseholdRole.admin));
  for (final scenario in const [
    (private: false, closeDuringSave: false),
    (private: true, closeDuringSave: false),
    (private: false, closeDuringSave: true),
  ]) {
    final private = scenario.private;
    final closeDuringSave = scenario.closeDuringSave;
    testWidgets(
        'new ${private ? 'private' : 'shared'} space is selected in mounted header after closing${closeDuringSave ? ' during save' : ''}',
        (tester) async {
      SharedPreferences.setMockInitialValues({'moneko_view_mode': 'household'});
      final prefs = await SharedPreferences.getInstance();
      final repository = _Repository();
      final client = SupabaseClient('https://example.test', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async => http.Response('[]', 200,
              headers: {'content-type': 'application/json'},
              request: request)));
      final original = _space('old');
      final created = _space('new', private: private);
      final saveResponse = Completer<Household>();
      when(() => repository.createHousehold(
          name: 'Space new',
          currency: 'USD',
          coverImageUrl: null,
          isPortfolio: private,
          autoSplitEnabled: private ? null : true)).thenAnswer((_) async {
        if (closeDuringSave) return await saveResponse.future;
        return created;
      });
      when(() => repository.getHouseholdMembers(any()))
          .thenAnswer((_) async => []);
      when(() => repository.getHouseholdInvites(any()))
          .thenAnswer((_) async => []);
      final readStarted = Completer<void>();
      final staleRead = Completer<List<Household>>();
      when(() => repository.getUserHouseholds('u1')).thenAnswer((_) {
        readStarted.complete();
        return staleRead.future;
      });
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_Auth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        householdRepositoryProvider.overrideWithValue(repository),
        supabaseClientProvider.overrideWithValue(client),
        preloadedUserHouseholdsProvider('u1').overrideWith((ref) => [original]),
        userProfileProvider('u1').overrideWith((ref) async => null),
        subscriptionNotifierProvider.overrideWith(_Subscription.new),
        coverImagesProvider.overrideWith((ref) async => []),
        networkReachabilityProvider.overrideWith((ref) => Stream.value(true)),
        selectedHomeCurrencyCodeProvider.overrideWithValue('USD'),
        homePeriodFinancialMonthStartDayProvider.overrideWithValue(1),
        mainShellTabIndexProvider.overrideWith((ref) => 1),
      ]);
      addTearDown(container.dispose);
      container.read(homeFilterProvider.notifier).setSelectedCurrency('USD');
      await container
          .read(selectedHouseholdProvider.notifier)
          .selectHousehold(original.id);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                        body: Column(children: [
                      const HomeHeaderSliver(),
                      if (private)
                        TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const CreateSpacePage(
                                        initialIsSharedSpace: false))),
                            child: const Text('New private space')),
                    ]))),
          )));
      await tester.pumpAndSettle();
      final catalog = container.read(userHouseholdsProvider('u1').notifier);
      final loading = catalog.load();
      await tester.pump();
      await tester.runAsync(() => readStarted.future);
      if (private) {
        await tester.tap(find.text('New private space'));
      } else {
        await tester.tap(find.text(original.name));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create Space').last);
      }
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, created.name);
      final submit = find.text(private ? 'Create Private Space' : 'Continue');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      if (closeDuringSave) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pageBack();
        await tester.pumpAndSettle();
        saveResponse.complete(created);
      }
      await tester.pumpAndSettle();
      if (!private && !closeDuringSave) {
        expect(find.byType(InviteMembersPage), findsOneWidget);
        // Skip invitation using Back, then close the creation page normally.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      staleRead.complete([original]);
      await tester.runAsync(() => loading);
      await tester.pumpAndSettle();
      expect(container.read(selectedHouseholdProvider).householdId, created.id);
      expect(container.read(viewModeProvider).mode, ViewMode.household);
      expect(find.text(created.name), findsOneWidget);
      await tester.tap(find.text(created.name));
      await tester.pumpAndSettle();
      expect(find.text(created.name), findsNWidgets(2));
      expect(find.text(original.name), findsOneWidget);
      verifyNever(() => repository.createInvite(
          householdId: any(named: 'householdId'),
          isReusable: any(named: 'isReusable'),
          invitedRole: any(named: 'invitedRole'),
          expiresInDays: any(named: 'expiresInDays')));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
