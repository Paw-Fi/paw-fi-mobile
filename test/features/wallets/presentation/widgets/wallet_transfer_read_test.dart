import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const transferId = '00000000-0000-4000-8000-000000000001';

void main() {
  var offline = false;
  String? serverTime = '14:45:00';
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://transfer.test',
      anonKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          autoRefreshToken: false,
          detectSessionInUri: false),
      httpClient: MockClient((request) async {
        if (offline) throw http.ClientException('Offline');
        return http.Response(
            jsonEncode({
              'id': transferId,
              'from_account_id': 'from',
              'to_account_id': 'to',
              'amount_cents': 1000,
              'currency': 'USD',
              'date': '2026-10-01',
              'time': serverTime,
              'created_by_user_id': 'user-1',
              'household_id': null,
              'created_at': '2026-10-01T01:00:00Z',
              'updated_at': '2026-10-01T03:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request);
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  for (final time in ['14:45:00', null]) {
    testWidgets('canonical read caches $time for identical offline reopening',
        (tester) async {
      final database = MonekoDatabase.inMemory();
      addTearDown(database.close);
      offline = false;
      serverTime = time;
      WalletTransfer? loaded;
      Future<void>? readOperation;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWith((ref) async => database)
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
          builder: (context) => TextButton(
              onPressed: () {
                readOperation = () async {
                  loaded = await loadWalletTransferForExpense(
                      context, 'transfer:$transferId:in');
                }();
              },
              child: const Text('Read')),
        ))),
      ));
      await tester.runAsync(() async {
        await tester.tap(find.text('Read'));
        await readOperation;
      });
      await tester.pumpAndSettle();
      expect(loaded?.time, time);
      expect(loaded?.date, DateTime(2026, 10, 1));
      for (final direction in ['in', 'out']) {
        final saved = await database.getTransactionByIdOrClientRecordId(
            'transfer:$transferId:$direction');
        expect(saved, isNotNull);
        expect(saved?.transferTime, time);
      }
      offline = true;
      loaded = null;
      await tester.runAsync(() async {
        await tester.tap(find.text('Read'));
        await readOperation;
      });
      await tester.pumpAndSettle();
      expect(loaded, isNotNull);
      expect(loaded?.time, time);
      expect(loaded?.date, DateTime(2026, 10, 1));
    });
  }
}
