import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/profile/domain/email_import_settings.dart';

void main() {
  test('email import inbound address stays fixed', () {
    expect(emailImportInboundAddress, 'files@inbound.moneko.io');
  });

  test('EmailImportSettings.fromJson parses settings payload', () {
    final settings = EmailImportSettings.fromJson({
      'enabled': true,
      'scopeId': 'personal',
      'scopeName': 'Personal',
      'isPortfolio': false,
      'accountId': 'wallet-1',
      'accountName': 'Main Wallet',
      'defaultEmail': 'owner@example.com',
      'whitelistEmails': [
        {
          'id': 'row-1',
          'email': 'reports@example.com',
          'normalizedEmail': 'reports@example.com',
        },
      ],
    });

    expect(settings.enabled, isTrue);
    expect(settings.defaultEmail, 'owner@example.com');
    expect(settings.whitelistEmails, hasLength(1));
    expect(settings.whitelistEmails.first.email, 'reports@example.com');
  });

  test('EmailImportSettings.copyWith updates only provided fields', () {
    final original =
        EmailImportSettings.disabled(defaultEmail: 'owner@example.com');

    final updated = original.copyWith(
      enabled: true,
      scopeId: 'household-1',
      scopeName: 'Shared Home',
    );

    expect(updated.enabled, isTrue);
    expect(updated.scopeId, 'household-1');
    expect(updated.scopeName, 'Shared Home');
    expect(updated.defaultEmail, 'owner@example.com');
  });

  test('isValidWhitelistEmail normalizes and validates email addresses', () {
    expect(normalizeWhitelistEmail(' Reports@Example.com '),
        'reports@example.com');
    expect(normalizeWhitelistEmail('not-an-email'), isNull);
  });
}
