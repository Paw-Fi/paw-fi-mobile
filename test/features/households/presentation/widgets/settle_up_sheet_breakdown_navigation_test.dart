import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/domain/entities/settlement_v2.dart';
import 'package:moneko/features/households/presentation/pages/settlement_calculation_breakdown_page.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

const _householdId = '00000000-0000-0000-0000-000000000001';
const _memberId = '00000000-0000-0000-0000-000000000002';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'me', email: 'me@example.com');
}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets(
      'opens calculation page immediately while sheet balance is unresolved',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MockHouseholdRepository();
    when(() => repository.getHouseholdMembers(_householdId)).thenAnswer(
      (_) async => [
        HouseholdMember(
          id: 'member-row',
          householdId: _householdId,
          userId: _memberId,
          role: HouseholdRole.member,
          userName: 'Alex',
          joinedAt: DateTime.utc(2026, 7, 16),
          createdAt: DateTime.utc(2026, 7, 16),
          updatedAt: DateTime.utc(2026, 7, 16),
        ),
      ],
    );

    final unresolvedBalance = Completer<List<SettlementPairwiseBalance>>();
    final unresolvedCalculation = Completer<SettlementCalculationV3>();
    final navigatorObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuth.new),
          householdRepositoryProvider.overrideWithValue(repository),
          cachedHouseholdExpensesProvider.overrideWith(
            (ref, params) async => const [],
          ),
          cachedHouseholdSplitsProvider.overrideWith(
            (ref, params) async => const [],
          ),
          householdPairwiseSettlementBalancesV2Provider.overrideWith(
            (ref, params) => unresolvedBalance.future,
          ),
          householdSettlementCalculationV3Provider.overrideWith(
            (ref, params) => unresolvedCalculation.future,
          ),
        ],
        child: MaterialApp(
          navigatorObservers: [navigatorObserver],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SettleUpSheet(
              householdId: _householdId,
              specificMemberId: _memberId,
              currency: 'CAD',
              isExpressNetting: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final helpButton = find.byIcon(Icons.help_outline_rounded);
    expect(helpButton, findsOneWidget);
    await tester.ensureVisible(helpButton);
    await tester.pump();
    expect(helpButton.hitTestable(), findsOneWidget);

    await tester.tap(helpButton.hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(navigatorObserver.pushCount, 2);
    expect(find.byType(SettlementCalculationBreakdownPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settlement-breakdown-skeleton')),
      findsOneWidget,
    );
  });
}
