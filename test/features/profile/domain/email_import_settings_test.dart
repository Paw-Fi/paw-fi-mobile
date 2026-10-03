import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/profile/domain/email_import_settings.dart';

void main() {
  test('new pending senders are not treated as verified authorizations', () {
    final pending = EmailImportWhitelistEntry.fromJson({
      'id': 'sender-1',
      'email': 'sender@example.com',
      'normalizedEmail': 'sender@example.com',
      'verified': false,
    });
    expect(pending.isVerified, isFalse);
    expect(EmailImportWhitelistEntry.fromJson(pending.toJson()).isVerified,
        isFalse);
  });

  test('shipped whitelist entries retain their existing authorization', () {
    final legacy = EmailImportWhitelistEntry.fromJson({
      'id': 'sender-1',
      'email': 'sender@example.com',
    });
    expect(legacy.isVerified, isTrue);
  });

  test('settings serialization preserves pending verification state', () {
    final settings =
        EmailImportSettings.disabled(defaultEmail: 'relay@example.com')
            .copyWith(whitelistEmails: const [
      EmailImportWhitelistEntry(
          id: 'sender-1',
          email: 'sender@example.com',
          normalizedEmail: 'sender@example.com',
          isVerified: false),
    ]);
    expect(
        EmailImportSettings.fromJson(settings.toJson())
            .whitelistEmails
            .single
            .isVerified,
        isFalse);
  });
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

  test('account sender conflict normalizes both email addresses', () {
    final settings =
        EmailImportSettings.disabled(defaultEmail: ' Owner@Example.com ');

    expect(settings.senderConflictFor(' OWNER@example.COM '),
        EmailImportSenderConflict.accountEmail);
  });

  test('account sender conflict also checks the current auth email', () {
    final settings =
        EmailImportSettings.disabled(defaultEmail: 'old@example.com');

    expect(
      settings.senderConflictFor(' NEW@example.com ',
          accountEmail: ' new@EXAMPLE.com '),
      EmailImportSenderConflict.accountEmail,
    );
  });

  test('added sender conflict normalizes stored and entered addresses', () {
    final settings =
        EmailImportSettings.disabled(defaultEmail: 'owner@example.com')
            .copyWith(whitelistEmails: const [
      EmailImportWhitelistEntry(
        id: 'sender-1',
        email: 'reports@example.com',
        normalizedEmail: ' Reports@Example.com ',
      ),
    ]);

    expect(settings.senderConflictFor(' REPORTS@example.com '),
        EmailImportSenderConflict.alreadyAdded);
    expect(settings.senderConflictFor('new@example.com'), isNull);
    expect(settings.senderConflictFor('not-an-email'), isNull);
  });

  test('sender comparison supports non-English email scripts', () {
    final settings = EmailImportSettings.disabled(defaultEmail: '用户@例子.中国');
    expect(settings.senderConflictFor(' 用户@例子.中国 '),
        EmailImportSenderConflict.accountEmail);
    expect(settings.senderConflictFor('別人@例子.中国'), isNull);
  });
}
