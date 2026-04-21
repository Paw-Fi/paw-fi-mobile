import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/plaid/models/bank_sync_review_session.dart';

void main() {
  group('BankSyncReviewSession', () {
    test('parses linked wallet metadata from backend response', () {
      final session = BankSyncReviewSession.fromResponse(
        data: {
          'connectionId': 'connection-1',
          'accounts': [
            {
              'id': 'bank-account-1',
              'provider_account_id': 'provider-account-1',
              'name': 'Checking',
              'currency': 'usd',
              'mask': '1234',
              'type': 'depository',
              'subtype': 'checking',
              'linkedWallet': {
                'id': 'wallet-1',
                'name': 'Main Checking',
                'icon': 'checking',
                'color': '#3B82F6',
                'goal_amount_cents': 150000,
                'opening_balance_cents': 2500,
                'is_default': true,
              },
            },
          ],
        },
        provider: 'plaid',
        targetHouseholdId: null,
      );

      expect(session.connectionId, 'connection-1');
      expect(session.provider, 'plaid');
      expect(session.accounts, hasLength(1));

      final account = session.accounts.first;
      expect(account.bankAccountId, 'bank-account-1');
      expect(account.currency, 'USD');
      expect(account.displayName, 'Checking ••••1234');
      expect(account.hasLinkedWallet, isTrue);
      expect(account.walletId, 'wallet-1');
      expect(account.walletName, 'Main Checking');
      expect(account.walletIcon, 'checking');
      expect(account.walletColor, '#3B82F6');
      expect(account.goalAmountCents, 150000);
      expect(account.openingBalanceCents, 2500);
      expect(account.isDefault, isTrue);
    });

    test('falls back to derived wallet defaults when no linked wallet exists',
        () {
      final session = BankSyncReviewSession.fromResponse(
        data: {
          'connectionId': 'connection-2',
          'accounts': [
            {
              'id': 'bank-account-2',
              'name': 'Savings',
              'currency': 'eur',
              'type': 'depository',
              'subtype': 'savings',
            },
          ],
        },
        provider: 'tink',
        targetHouseholdId: 'household-1',
      );

      final account = session.accounts.first;
      expect(account.hasLinkedWallet, isFalse);
      expect(account.walletName, 'Savings');
      expect(account.walletIcon, 'savings');
      expect(account.walletColor, startsWith('#'));
      expect(account.currency, 'EUR');
      expect(session.targetHouseholdId, 'household-1');
    });
  });
}
