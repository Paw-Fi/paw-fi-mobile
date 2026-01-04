import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/profile/domain/entities/whatsapp_binding.dart';

void main() {
  group('WhatsAppBinding - Model Creation', () {
    test('creates binding with all required fields', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
      );

      expect(binding.userId, 'user_1');
      expect(binding.isBound, true);
      expect(binding.phoneE164, null);
      expect(binding.verified, null);
    });

    test('creates binding with all optional fields', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
        verified: true,
      );

      expect(binding.userId, 'user_1');
      expect(binding.isBound, true);
      expect(binding.phoneE164, '+1234567890');
      expect(binding.verified, true);
    });

    test('creates unbound binding', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: false,
      );

      expect(binding.userId, 'user_1');
      expect(binding.isBound, false);
      expect(binding.phoneE164, null);
      expect(binding.verified, null);
    });
  });

  group('WhatsAppBinding - JSON Serialization', () {
    test('fromJson parses binding correctly', () {
      final json = {
        'user_id': 'user_1',
        'is_bound': true,
        'phone_e164': '+1234567890',
        'verified': true,
      };

      final binding = WhatsAppBinding.fromJson(json);

      expect(binding.userId, 'user_1');
      expect(binding.isBound, true);
      expect(binding.phoneE164, '+1234567890');
      expect(binding.verified, true);
    });

    test('fromJson handles default values', () {
      final json = <String, dynamic>{};

      final binding = WhatsAppBinding.fromJson(json);

      expect(binding.userId, '');
      expect(binding.isBound, false);
      expect(binding.phoneE164, null);
      expect(binding.verified, null);
    });

    test('fromJson handles null user_id', () {
      final json = {
        'user_id': null,
        'is_bound': true,
      };

      final binding = WhatsAppBinding.fromJson(json);

      expect(binding.userId, '');
      expect(binding.isBound, true);
    });

    test('fromJson handles null is_bound', () {
      final json = {
        'user_id': 'user_1',
        'is_bound': null,
      };

      final binding = WhatsAppBinding.fromJson(json);

      expect(binding.userId, 'user_1');
      expect(binding.isBound, false);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'user_id': 'user_1',
        'is_bound': true,
        'phone_e164': null,
        'verified': null,
      };

      final binding = WhatsAppBinding.fromJson(json);

      expect(binding.phoneE164, null);
      expect(binding.verified, null);
    });

    test('toJson serializes binding correctly', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
        verified: true,
      );

      final json = binding.toJson();

      expect(json['user_id'], 'user_1');
      expect(json['is_bound'], true);
      expect(json['phone_e164'], '+1234567890');
      expect(json['verified'], true);
    });

    test('toJson handles null optional fields', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: false,
      );

      final json = binding.toJson();

      expect(json['user_id'], 'user_1');
      expect(json['is_bound'], false);
      expect(json['phone_e164'], null);
      expect(json['verified'], null);
    });
  });

  group('WhatsAppBinding - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      const original = WhatsAppBinding(
        userId: 'user_1',
        isBound: false,
      );

      final updated = original.copyWith(
        isBound: true,
        phoneE164: '+1234567890',
        verified: true,
      );

      expect(updated.userId, 'user_1');
      expect(updated.isBound, true);
      expect(updated.phoneE164, '+1234567890');
      expect(updated.verified, true);
    });

    test('copyWith without parameters returns identical values', () {
      const original = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
        verified: true,
      );

      final copy = original.copyWith();

      expect(copy.userId, original.userId);
      expect(copy.isBound, original.isBound);
      expect(copy.phoneE164, original.phoneE164);
      expect(copy.verified, original.verified);
    });

    test('copyWith can update individual fields', () {
      const original = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
        verified: false,
      );

      final updated = original.copyWith(verified: true);

      expect(updated.userId, 'user_1');
      expect(updated.isBound, true);
      expect(updated.phoneE164, '+1234567890');
      expect(updated.verified, true);
    });
  });

  group('WhatsAppBinding - Equality', () {
    test('two bindings with same values are equal', () {
      const binding1 = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
      );

      const binding2 = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
      );

      expect(binding1, equals(binding2));
      expect(binding1.hashCode, equals(binding2.hashCode));
    });

    test('two bindings with different userId are not equal', () {
      const binding1 = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
      );

      const binding2 = WhatsAppBinding(
        userId: 'user_2',
        isBound: true,
      );

      expect(binding1, isNot(equals(binding2)));
    });

    test('two bindings with different isBound are not equal', () {
      const binding1 = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
      );

      const binding2 = WhatsAppBinding(
        userId: 'user_1',
        isBound: false,
      );

      expect(binding1, isNot(equals(binding2)));
    });

    test('two bindings with different phoneE164 are not equal', () {
      const binding1 = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
      );

      const binding2 = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+0987654321',
      );

      expect(binding1, isNot(equals(binding2)));
    });

    test('binding is equal to itself', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
      );

      expect(binding, equals(binding));
    });
  });

  group('WhatsAppBinding - Edge Cases', () {
    test('handles empty userId', () {
      const binding = WhatsAppBinding(
        userId: '',
        isBound: false,
      );

      expect(binding.userId, '');
      expect(binding.isBound, false);
    });

    test('handles various phone number formats', () {
      const binding1 = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
      );

      const binding2 = WhatsAppBinding(
        userId: 'user_2',
        isBound: true,
        phoneE164: '+44123456789',
      );

      const binding3 = WhatsAppBinding(
        userId: 'user_3',
        isBound: true,
        phoneE164: '+861234567890',
      );

      expect(binding1.phoneE164, '+1234567890');
      expect(binding2.phoneE164, '+44123456789');
      expect(binding3.phoneE164, '+861234567890');
    });

    test('handles verified false', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
        verified: false,
      );

      expect(binding.verified, false);
    });

    test('handles bound but not verified', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
        phoneE164: '+1234567890',
        verified: false,
      );

      expect(binding.isBound, true);
      expect(binding.verified, false);
    });

    test('handles bound without phone number', () {
      const binding = WhatsAppBinding(
        userId: 'user_1',
        isBound: true,
      );

      expect(binding.isBound, true);
      expect(binding.phoneE164, null);
    });
  });
}
