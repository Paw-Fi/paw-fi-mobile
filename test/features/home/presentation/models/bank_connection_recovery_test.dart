import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/bank_sync/bank_provider_routing.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';

void main() {
  test('unassigned revoked connection remains reachable and reconnectable', () {
    final connection = BankConnection.fromJson(const {
      'id': 'connection-1',
      'status': 'needs_reauth',
      'item_status': 'pending_relink',
      'relink_state': 'required',
      'linked_wallet_count': 0,
      'can_reconnect': true,
    });

    expect(connection.needsReconnect, isTrue);
    expect(connection.linkedWalletCount, 0);
    expect(connection.canReconnect, isTrue);
    expect(connection.needsFinishSetup, isFalse);
  });

  test('removed and pending removal connections are not recoverable', () {
    final pending = BankConnection.fromJson(const {
      'id': 'connection-2',
      'item_status': 'pending_removal',
    });
    final removed = BankConnection.fromJson(const {
      'id': 'connection-3',
      'item_status': 'removed',
      'status': 'disabled',
    });

    expect(pending.isPendingRemoval, isTrue);
    expect(removed.isRemoved, isTrue);
  });

  test('parses wallet-independent recovery fields', () {
    final connection = BankConnection.fromJson(const {
      'id': 'connection-4',
      'household_id': 'household-1',
      'metadata': {'institution_name': 'Recovery Bank'},
      'status': 'needs_reauth',
      'item_status': 'pending_relink',
      'linked_bank_account_count': 2,
      'linked_wallet_count': 0,
      'can_reconnect': true,
      'can_disconnect': true,
      'role_guidance':
          'A household owner or admin must manage this bank connection.',
      'latest_error_code': 'USER_PERMISSION_REVOKED',
    });

    expect(connection.displayName, 'Recovery Bank');
    expect(connection.householdId, 'household-1');
    expect(connection.linkedBankAccountCount, 2);
    expect(connection.linkedWalletCount, 0);
    expect(connection.canReconnect, isTrue);
    expect(connection.canDisconnect, isTrue);
    expect(connection.latestErrorCode, 'USER_PERMISSION_REVOKED');
  });

  test('reviewed and terminal connections never need finish setup', () {
    final reviewed = BankConnection.fromJson(const {
      'id': 'reviewed',
      'review_completed_at': '2026-07-31T12:00:00Z',
    });
    final pendingRemoval = BankConnection.fromJson(const {
      'id': 'pending',
      'item_status': 'pending_removal',
    });

    expect(reviewed.needsFinishSetup, isFalse);
    expect(pendingRemoval.needsFinishSetup, isFalse);
    expect(pendingRemoval.requiresUserAction, isFalse);
  });

  test(
      'existing connections use Plaid and unsupported countries are unavailable',
      () {
    expect(
      resolveBankProviderForConnection(
        connectionId: 'connection-1',
        countryCode: 'DE',
      ),
      BankProvider.plaid,
    );
    expect(
      resolveBankProviderForConnection(connectionId: null, countryCode: 'DE'),
      BankProvider.comingSoon,
    );
  });

  test('server-resolved connection id upgrades a new flow to update mode', () {
    expect(
      resolveBankConnectionId(
        requestedConnectionId: null,
        responseConnectionId: 'connection-1',
      ),
      'connection-1',
    );
    expect(
      resolveBankConnectionId(
        requestedConnectionId: 'requested',
        responseConnectionId: null,
      ),
      'requested',
    );
  });
}
