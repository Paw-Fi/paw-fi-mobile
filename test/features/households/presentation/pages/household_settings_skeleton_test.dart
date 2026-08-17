import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _testHouseholdId = 'household_123';

void main() {
  testWidgets('household settings page displays skeleton when loading',
      (tester) async {
    final householdCompleter = Completer<Household?>();
    final fakeRepo = _FakeHouseholdRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user_1'),
          householdRepositoryProvider.overrideWithValue(fakeRepo),
          householdProvider(_testHouseholdId).overrideWith(
            (ref) => householdCompleter.future,
          ),
          householdMembersProvider(_testHouseholdId).overrideWith(
            (ref) => HouseholdMembersNotifier(fakeRepo, _testHouseholdId),
          ),
          householdInvitesProvider(_testHouseholdId).overrideWith(
            (ref) => HouseholdInvitesNotifier(fakeRepo, _testHouseholdId),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HouseholdSettingsPage(householdId: _testHouseholdId),
        ),
      ),
    );

    await tester.pump();

    // Verify skeleton is displayed
    expect(find.byKey(const ValueKey('household-settings-skeleton')),
        findsOneWidget);

    // Complete the household load
    householdCompleter.complete(
      Household(
        id: _testHouseholdId,
        name: 'Family Space',
        ownerId: 'user_1',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    await tester.pumpAndSettle();

    // Verify skeletonizer is no longer present
    expect(find.byType(Skeletonizer), findsNothing);
    expect(find.text('Family Space'), findsOneWidget);
  });
}

class _FakeHouseholdRepository implements HouseholdRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId) async =>
      [];

  @override
  Future<List<HouseholdInvite>> getHouseholdInvites(String householdId) async =>
      [];
}
