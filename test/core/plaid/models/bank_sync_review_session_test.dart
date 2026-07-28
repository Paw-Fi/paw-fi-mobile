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
              'providerBalanceCurrentCents': 125050,
              'providerBalanceAvailableCents': 120000,
              'linkedWallet': {
                'id': 'wallet-1',
                'name': 'Main Checking',
                'icon': 'checking',
                'color': '#3B82F6',
                'logo_url': 'https://example.supabase.co/storage/logo.png',
                'goal_amount_cents': 150000,
                'opening_balance_cents': 2500,
                'is_default': true,
                'exclude_from_analytics': true,
              },
            },
          ],
        },
        flowReason: null,
        provider: 'plaid',
        targetHouseholdId: null,
        defaultAccountName: 'Bank account',
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
      expect(
        account.walletLogoUrl,
        'https://example.supabase.co/storage/logo.png',
      );
      expect(account.goalAmountCents, 150000);
      expect(account.openingBalanceCents, 2500);
      expect(account.providerCurrentBalanceCents, 125050);
      expect(account.providerAvailableBalanceCents, 120000);
      expect(account.providerDisplayBalanceCents, 125050);
      expect(account.isDefault, isTrue);
      expect(account.excludeFromAnalytics, isTrue);
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
        flowReason: null,
        provider: 'tink',
        targetHouseholdId: 'household-1',
        defaultAccountName: 'Bank account',
      );

      final account = session.accounts.first;
      expect(account.hasLinkedWallet, isFalse);
      expect(account.walletName, 'Savings');
      expect(account.walletIcon, 'savings');
      expect(account.walletColor, startsWith('#'));
      expect(account.currency, 'EUR');
      expect(account.excludeFromAnalytics, isFalse);
      expect(session.targetHouseholdId, 'household-1');
    });

    test('uses institution logo URL for new linked-wallet defaults', () {
      final session = BankSyncReviewSession.fromResponse(
        data: {
          'connectionId': 'connection-3',
          'accounts': [
            {
              'id': 'bank-account-3',
              'name': 'Card',
              'currency': 'usd',
              'type': 'credit',
              'institutionLogoUrl':
                  'https://example.supabase.co/storage/bank-logo.png',
            },
          ],
        },
        flowReason: null,
        provider: 'plaid',
        targetHouseholdId: null,
        defaultAccountName: 'Bank account',
      );

      expect(
        session.accounts.first.walletLogoUrl,
        'https://example.supabase.co/storage/bank-logo.png',
      );
    });

    test('does not reapply institution logo to an existing linked wallet', () {
      final session = BankSyncReviewSession.fromResponse(
        data: {
          'connectionId': 'connection-4',
          'accounts': [
            {
              'id': 'bank-account-4',
              'name': 'Checking',
              'currency': 'usd',
              'institutionLogoUrl':
                  'https://example.supabase.co/storage/bank-logo.png',
              'linkedWallet': {
                'id': 'wallet-4',
                'name': 'Checking',
                'icon': 'checking',
                'color': '#3B82F6',
                'logo_url': null,
              },
            },
          ],
        },
        flowReason: null,
        provider: 'plaid',
        targetHouseholdId: null,
        defaultAccountName: 'Bank account',
      );

      expect(session.accounts.first.hasLinkedWallet, isTrue);
      expect(session.accounts.first.walletLogoUrl, isNull);
    });

    test('shows credit balances as liabilities', () {
      final session = BankSyncReviewSession.fromResponse(
        data: {
          'connectionId': 'connection-5',
          'accounts': [
            {
              'id': 'bank-account-5',
              'name': 'Credit card',
              'currency': 'usd',
              'type': 'credit',
              'providerBalanceCurrentCents': 42000,
            },
          ],
        },
        flowReason: null,
        provider: 'plaid',
        targetHouseholdId: null,
        defaultAccountName: 'Bank account',
      );

      expect(session.accounts.first.providerDisplayBalanceCents, -42000);
    });

    test('does not fabricate a provider balance when Plaid omits it', () {
      final session = BankSyncReviewSession.fromResponse(
        data: {
          'connectionId': 'connection-6',
          'accounts': [
            {
              'id': 'bank-account-6',
              'name': 'Checking',
              'currency': 'usd',
              'type': 'depository',
            },
          ],
        },
        flowReason: null,
        provider: 'plaid',
        targetHouseholdId: null,
        defaultAccountName: 'Bank account',
      );

      expect(session.accounts.first.providerDisplayBalanceCents, isNull);
    });
  });
}
