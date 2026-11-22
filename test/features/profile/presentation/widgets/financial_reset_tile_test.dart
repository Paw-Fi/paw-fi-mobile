import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/profile/data/financial_reset.dart';
import 'package:moneko/features/profile/presentation/providers/financial_reset_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/financial_reset_gate.dart';
import 'package:moneko/features/profile/presentation/widgets/financial_reset_tile.dart';
import 'package:moneko/l10n/app_localizations_en.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final strings = AppLocalizationsEn();
  testWidgets(
      'confirmed reset unmounts Settings, polls and completes long cleanup',
      (tester) async {
    final db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    var requests = 0;
    final purge = Completer<void>();
    final service = FinancialReset(
        database: () async => db,
        rpc: (name, args) async {
          if (name == 'request_financial_data_reset') {
            requests++;
            return {'id': args['p_request_id'], 'status': 'pending'};
          }
          return requests == 0
              ? null
              : {'id': args['p_request_id'], 'status': 'completed'};
        });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          financialResetProvider.overrideWithValue(service),
          resetActorGuardProvider.overrideWithValue((_) => true),
          resetCleanupProvider.overrideWithValue((_, guard) async {
            await purge.future;
            guard();
          }),
        ],
        child: MaterialApp(
            home: FinancialResetGate(
                userId: 'A',
                child: FinancialResetTile(
                    userId: 'A',
                    isPreview: () => false,
                    ownsActor: () => true)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.resetData));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'RESET');
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.resetData).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FinancialResetTile), findsNothing);
    expect(requests, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(minutes: 1));
    expect(db.activeResetOwner, 'A');
    expect(db.resetJob('A')?['status'], 'completed');
    expect(find.text(strings.restartNow), findsNothing);
    purge.complete();
    await tester.pumpAndSettle();
    expect(db.activeResetOwner, isNull);
    expect(find.text(strings.restartNow), findsOneWidget);
    expect(requests, 1);
  });

  test(
      'interrupted local cleanup resumes automatically after SQLite reopen, offline',
      () async {
    final directory = await Directory.systemTemp.createTemp('reset-purge-');
    MonekoDatabase open() => MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite3.open('${directory.path}/db'));
    var db = open();
    var requests = 0;
    final service = FinancialReset(
        database: () async => db,
        rpc: (name, args) async {
          requests++;
          if (name == 'get_financial_data_reset') return null;
          return {'id': args['p_request_id'], 'status': 'completed'};
        });
    try {
      await service.prepare('A', () => true);
      await expectLater(
          service.run(
              userId: 'A',
              isCurrent: () => true,
              cleanup: (_) async {
                await db.clearAllLocalData();
                throw StateError('interrupted before cache refresh');
              }),
          throwsStateError);
      await db.close();
      db = open();
      final container = ProviderContainer(overrides: [
        financialResetProvider.overrideWithValue(FinancialReset(
            database: () async => db, rpc: (_, __) => fail('unexpected RPC'))),
        resetActorGuardProvider.overrideWithValue((_) => true),
        resetCleanupProvider.overrideWithValue((_, guard) async {
          guard();
          await db.clearAllLocalData();
        }),
      ]);
      final done = Completer<void>();
      final phases = <ResetRecovery>[];
      container.listen(resetRecoveryProvider('A'), (_, state) {
        state.whenData((phase) {
          phases.add(phase);
          if (phase == ResetRecovery.completed) done.complete();
        });
      });
      try {
        await done.future.timeout(const Duration(seconds: 3));
      } finally {
        container.dispose();
      }
      expect(phases, [ResetRecovery.cleaning, ResetRecovery.completed]);
      expect(db.activeResetOwner, isNull);
      expect(requests, 2);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
