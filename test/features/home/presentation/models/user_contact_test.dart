import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';

void main() {
  group('UserContact - Model Creation', () {
    test('creates user contact with all fields', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      expect(contact.id, 'contact_123');
      expect(contact.userId, 'user_1');
      expect(contact.phoneE164, '+1234567890');
      expect(contact.verified, true);
      expect(contact.preferredCurrency, 'USD');
      expect(contact.preferredTimezone, 'America/New_York');
    });

    test('creates user contact with null optional fields', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: null,
        phoneE164: null,
        verified: false,
        preferredCurrency: null,
        preferredTimezone: null,
      );

      expect(contact.userId, null);
      expect(contact.phoneE164, null);
      expect(contact.preferredCurrency, null);
      expect(contact.preferredTimezone, null);
    });

    test('creates unverified contact', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: false,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      expect(contact.verified, false);
    });
  });

  group('UserContact - JSON Serialization', () {
    test('fromJson parses user contact correctly', () {
      final json = {
        'id': 'contact_123',
        'user_id': 'user_1',
        'phone_e164': '+1234567890',
        'verified': true,
        'preferred_currency': 'USD',
        'preferred_timezone': 'America/New_York',
      };

      final contact = UserContact.fromJson(json);

      expect(contact.id, 'contact_123');
      expect(contact.userId, 'user_1');
      expect(contact.phoneE164, '+1234567890');
      expect(contact.verified, true);
      expect(contact.preferredCurrency, 'USD');
      expect(contact.preferredTimezone, 'America/New_York');
    });

    test('fromJson handles null user_id', () {
      final json = {
        'id': 'contact_123',
        'user_id': null,
        'phone_e164': '+1234567890',
        'verified': true,
        'preferred_currency': 'USD',
        'preferred_timezone': 'America/New_York',
      };

      final contact = UserContact.fromJson(json);

      expect(contact.userId, null);
    });

    test('fromJson handles null phone_e164', () {
      final json = {
        'id': 'contact_123',
        'user_id': 'user_1',
        'phone_e164': null,
        'verified': false,
        'preferred_currency': 'USD',
        'preferred_timezone': 'America/New_York',
      };

      final contact = UserContact.fromJson(json);

      expect(contact.phoneE164, null);
    });

    test('fromJson defaults verified to false when null', () {
      final json = {
        'id': 'contact_123',
        'user_id': 'user_1',
        'phone_e164': '+1234567890',
        'verified': null,
        'preferred_currency': 'USD',
        'preferred_timezone': 'America/New_York',
      };

      final contact = UserContact.fromJson(json);

      expect(contact.verified, false);
    });

    test('fromJson handles null preferred_currency', () {
      final json = {
        'id': 'contact_123',
        'user_id': 'user_1',
        'phone_e164': '+1234567890',
        'verified': true,
        'preferred_currency': null,
        'preferred_timezone': 'America/New_York',
      };

      final contact = UserContact.fromJson(json);

      expect(contact.preferredCurrency, null);
    });

    test('fromJson handles null preferred_timezone', () {
      final json = {
        'id': 'contact_123',
        'user_id': 'user_1',
        'phone_e164': '+1234567890',
        'verified': true,
        'preferred_currency': 'USD',
        'preferred_timezone': null,
      };

      final contact = UserContact.fromJson(json);

      expect(contact.preferredTimezone, null);
    });

    test('toJson serializes user contact correctly', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      final json = contact.toJson();

      expect(json['id'], 'contact_123');
      expect(json['user_id'], 'user_1');
      expect(json['phone_e164'], '+1234567890');
      expect(json['verified'], true);
      expect(json['preferred_currency'], 'USD');
      expect(json['preferred_timezone'], 'America/New_York');
    });

    test('toJson includes null values', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: null,
        phoneE164: null,
        verified: false,
        preferredCurrency: null,
        preferredTimezone: null,
      );

      final json = contact.toJson();

      expect(json['user_id'], null);
      expect(json['phone_e164'], null);
      expect(json['preferred_currency'], null);
      expect(json['preferred_timezone'], null);
    });
  });

  group('UserContact - CopyWith', () {
    test('copyWith updates preferred currency', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      final updated = contact.copyWith(preferredCurrency: 'EUR');

      expect(updated.preferredCurrency, 'EUR');
      expect(updated.id, 'contact_123');
      expect(updated.userId, 'user_1');
      expect(updated.phoneE164, '+1234567890');
      expect(updated.verified, true);
    });

    test('copyWith updates preferred timezone', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      final updated = contact.copyWith(preferredTimezone: 'Europe/London');

      expect(updated.preferredTimezone, 'Europe/London');
      expect(updated.id, 'contact_123');
    });

    test('copyWith updates both currency and timezone', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      final updated = contact.copyWith(
        preferredCurrency: 'GBP',
        preferredTimezone: 'Europe/London',
      );

      expect(updated.preferredCurrency, 'GBP');
      expect(updated.preferredTimezone, 'Europe/London');
    });

    test('copyWith with no parameters returns same values', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      final updated = contact.copyWith();

      expect(updated.id, contact.id);
      expect(updated.userId, contact.userId);
      expect(updated.phoneE164, contact.phoneE164);
      expect(updated.verified, contact.verified);
      expect(updated.preferredCurrency, contact.preferredCurrency);
      expect(updated.preferredTimezone, contact.preferredTimezone);
    });

    test('copyWith preserves immutable fields', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      final updated = contact.copyWith(preferredCurrency: 'EUR');

      // Immutable fields should remain unchanged
      expect(updated.id, 'contact_123');
      expect(updated.userId, 'user_1');
      expect(updated.phoneE164, '+1234567890');
      expect(updated.verified, true);
    });
  });

  group('UserContact - Edge Cases', () {
    test('handles various phone number formats', () {
      final formats = [
        '+1234567890',
        '+44123456789',
        '+861234567890',
        '+33123456789',
      ];

      for (final phone in formats) {
        final contact = UserContact(
          id: 'contact_123',
          userId: 'user_1',
          phoneE164: phone,
          verified: true,
          preferredCurrency: 'USD',
          preferredTimezone: 'America/New_York',
        );

        expect(contact.phoneE164, phone);
      }
    });

    test('handles various currency codes', () {
      final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'INR'];

      for (final currency in currencies) {
        final contact = UserContact(
          id: 'contact_123',
          userId: 'user_1',
          phoneE164: '+1234567890',
          verified: true,
          preferredCurrency: currency,
          preferredTimezone: 'America/New_York',
        );

        expect(contact.preferredCurrency, currency);
      }
    });

    test('handles various timezones', () {
      final timezones = [
        'America/New_York',
        'Europe/London',
        'Asia/Tokyo',
        'Australia/Sydney',
        'UTC',
      ];

      for (final timezone in timezones) {
        final contact = UserContact(
          id: 'contact_123',
          userId: 'user_1',
          phoneE164: '+1234567890',
          verified: true,
          preferredCurrency: 'USD',
          preferredTimezone: timezone,
        );

        expect(contact.preferredTimezone, timezone);
      }
    });

    test('handles empty string id', () {
      final contact = UserContact(
        id: '',
        userId: 'user_1',
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      expect(contact.id, '');
    });

    test('handles mobile-only users without phone', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: null,
        verified: false,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      expect(contact.phoneE164, null);
      expect(contact.verified, false);
    });

    test('handles contact without user binding', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: null,
        phoneE164: '+1234567890',
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      expect(contact.userId, null);
    });

    test('handles verified contact without phone', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: 'user_1',
        phoneE164: null,
        verified: true,
        preferredCurrency: 'USD',
        preferredTimezone: 'America/New_York',
      );

      expect(contact.phoneE164, null);
      expect(contact.verified, true);
    });

    test('handles contact with all null optional fields', () {
      final contact = UserContact(
        id: 'contact_123',
        userId: null,
        phoneE164: null,
        verified: false,
        preferredCurrency: null,
        preferredTimezone: null,
      );

      expect(contact.userId, null);
      expect(contact.phoneE164, null);
      expect(contact.preferredCurrency, null);
      expect(contact.preferredTimezone, null);
    });
  });
}
