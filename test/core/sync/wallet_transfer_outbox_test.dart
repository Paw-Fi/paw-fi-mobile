import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/ui/notifications/app_mutation_error_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transfer_feed_entries.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user', email: 'user@example.com');
}

Map<String, dynamic> _transfer(String id, int fee, {String? feeId}) => {
      'id': id,
      'from_account_id': 'source',
      'to_account_id': 'target',
      'amount_cents': 10000,
      'currency': 'EUR',
      'to_amount_cents': 11000,
      'to_currency': 'USD',
      'exchange_rate': '1.1',
      'fee_amount_cents': fee,
      'fee_expense_id': feeId,
      'transfer_contract_version': 2,
      'date': '2026-10-15',
      'created_by_user_id': 'user',
    };

void main() {
  late MonekoDatabase database;
  late ProviderContainer container;
  late Future<http.Response> Function(http.Request) handle;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'test',
        httpClient: MockClient((request) => handle(request)));
    database = MonekoDatabase.inMemory();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
      localDatabaseProvider.overrideWith((ref) async => database),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    await Supabase.instance.dispose();
  });

  Future<void> queue({bool delete = false}) async {
    final original = buildWalletTransferFeedEntries(
        transferJson: _transfer('optimistic-transfer-test', 125),
        fallbackUserId: 'user');
    await database.writeOptimisticWalletTransfer(
        entries: original,
        clientMutationId: 'create',
        entityId: 'optimistic-transfer-test',
        payload: {
          'functionName': 'create-wallet-transfer',
          'requestBody': {
            'clientRecordId': 'stable-create-id',
            'amountCents': 10000,
            'currency': 'EUR',
            'toAmountCents': 11000,
            'toCurrency': 'USD',
            'exchangeRate': '1.1',
            'feeAmountCents': 125,
            'transferContractVersion': 2,
          }
        });
    final payload = {
      'functionName':
          delete ? 'delete-wallet-transfer' : 'update-wallet-transfer',
      'requestBody': {
        'transferId': 'optimistic-transfer-test',
        'feeAmountCents': 200,
        'toAmountCents': 11000,
        'toCurrency': 'USD',
        'exchangeRate': '1.1',
        'transferContractVersion': 2
      }
    };
    if (delete) {
      await database.writeOptimisticWalletTransferDelete(
          entries: original,
          clientMutationId: 'later',
          transferId: 'optimistic-transfer-test',
          payload: payload);
    } else {
      await database.writeOptimisticWalletTransferUpdate(
          originalEntries: original,
          updatedEntries: buildWalletTransferFeedEntries(
              transferJson: _transfer('optimistic-transfer-test', 200),
              fallbackUserId: 'user'),
          clientMutationId: 'later',
          transferId: 'optimistic-transfer-test',
          payload: payload);
    }
  }

  test(
      'retry reuses create ID then replays retargeted edit and canonical fee once',
      () async {
    var attempts = 0;
    final requests = <Map<String, dynamic>>[];
    handle = (request) async {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      requests.add(body);
      if (request.url.path.endsWith('/create-wallet-transfer')) {
        attempts++;
        if (attempts == 1) return http.Response('{"error":"offline"}', 503);
        return http.Response(
            jsonEncode({
              'success': true,
              'data': _transfer('canonical', 125, feeId: 'canonical-fee')
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      expect(body['transferId'], 'canonical');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': _transfer('canonical', 200, feeId: 'canonical-fee')
          }),
          200,
          headers: {'content-type': 'application/json'});
    };
    await queue();
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    await coordinator.drainOutbox(maxMutations: 1);
    expect((await database.getOutboxMutations()).first.status,
        localMutationStatusFailed);
    expect(
        (await database.getWalletTransferFeeEntry('optimistic-transfer-test'))
            ?.amountCents,
        200);
    await database.markMutationFailed(
        clientMutationId: 'create',
        error: 'offline',
        retryAfter: DateTime(2020));
    await coordinator.drainOutbox();
    expect(requests.take(2).map((r) => r['clientRecordId']),
        ['stable-create-id', 'stable-create-id']);
    expect(
        (await database.getOutboxMutations())
            .every((m) => m.status == localMutationStatusSynced),
        isTrue);
    final entries = await database.getWalletTransferEntries('canonical');
    expect(entries, hasLength(3));
    expect(entries.map((e) => e.amountCents), [10000, 11000, 200]);
    expect(entries.last.id, 'canonical-fee');
    expect(entries.last.transferFeeTransferId, 'canonical');
    expect(await database.getWalletTransferFeeEntry('optimistic-transfer-test'),
        isNull);
    expect(container.read(appMutationErrorProvider), isNull);
  });

  test(
      'authoritative create rejection cancels fee and dependent delete immediately',
      () async {
    handle = (_) async => http.Response(
        '{"error":"rejected","code":"VALIDATION_ERROR"}', 400,
        headers: {'content-type': 'application/json'});
    await queue(delete: true);
    final coordinator =
        await container.read(mobileOutboxSyncCoordinatorProvider.future);
    await coordinator.drainOutbox();
    expect(
        (await database.getOutboxMutations())
            .every((m) => m.status == localMutationStatusCancelled),
        isTrue);
    expect(await database.getWalletTransferEntries('optimistic-transfer-test'),
        isEmpty);
    expect(container.read(appMutationErrorProvider)?.id, 'create');
    expect(
        await database.getActiveTransactionTombstoneIds(
            userId: 'user', householdId: null),
        isEmpty);
  });
}
