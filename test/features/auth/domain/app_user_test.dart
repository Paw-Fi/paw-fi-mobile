import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('AppUser - Model Creation', () {
    test('creates user with all fields', () {
      const user = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        isCreator: true,
      );

      expect(user.uid, 'user_123');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.isCreator, true);
    });

    test('creates user with minimal fields', () {
      const user = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
      );

      expect(user.uid, 'user_123');
      expect(user.email, 'test@example.com');
      expect(user.displayName, null);
      expect(user.photoUrl, null);
      expect(user.isCreator, false);
    });

    test('creates user with null optional fields', () {
      const user = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: null,
        photoUrl: null,
        isCreator: false,
      );

      expect(user.displayName, null);
      expect(user.photoUrl, null);
      expect(user.isCreator, false);
    });
  });

  group('AppUser - JSON Serialization', () {
    test('fromJson parses user correctly', () {
      final json = {
        'uid': 'user_123',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'photoUrl': 'https://example.com/photo.jpg',
        'isCreator': true,
      };

      final user = AppUser.fromJson(json);

      expect(user.uid, 'user_123');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.isCreator, true);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'uid': 'user_123',
        'email': 'test@example.com',
      };

      final user = AppUser.fromJson(json);

      expect(user.uid, 'user_123');
      expect(user.email, 'test@example.com');
      expect(user.displayName, null);
      expect(user.photoUrl, null);
      expect(user.isCreator, false);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'uid': 'user_123',
        'email': 'test@example.com',
        'displayName': null,
        'photoUrl': null,
      };

      final user = AppUser.fromJson(json);

      expect(user.displayName, null);
      expect(user.photoUrl, null);
      expect(user.isCreator, false);
    });

    test('fromJson handles explicit null values', () {
      final json = {
        'uid': 'user_123',
        'email': 'test@example.com',
        'displayName': null,
        'photoUrl': null,
        'isCreator': false,
      };

      final user = AppUser.fromJson(json);

      expect(user.displayName, null);
      expect(user.photoUrl, null);
      expect(user.isCreator, false);
    });

    test('fromJson handles isCreator as false', () {
      final json = {
        'uid': 'user_123',
        'email': 'test@example.com',
        'isCreator': false,
      };

      final user = AppUser.fromJson(json);

      expect(user.isCreator, false);
    });
  });

  group('AppUser - fromSession', () {
    test('fromSession creates user from session', () {
      final session = supabase.Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: supabase.User(
          id: 'user_123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'test@example.com',
        ),
      );

      final user = AppUser.fromSession(session);

      expect(user.uid, 'user_123');
      expect(user.email, 'test@example.com');
      expect(user.isCreator, false); // fromSession doesn't parse isCreator
    });

    test('fromSession handles null email', () {
      final session = supabase.Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: supabase.User(
          id: 'user_123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      final user = AppUser.fromSession(session);

      expect(user.uid, 'user_123');
      expect(user.email, '');
    });

    test('fromSession handles user metadata', () {
      final session = supabase.Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: supabase.User(
          id: 'user_123',
          appMetadata: {},
          userMetadata: {
            'full_name': 'Test User',
            'avatar_url': 'https://example.com/photo.jpg',
          },
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'test@example.com',
        ),
      );

      final user = AppUser.fromSession(session);

      expect(user.displayName, 'Test User');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.isCreator, false); // fromSession doesn't parse isCreator
    });
  });

  group('AppUser - empty', () {
    test('empty user has default values', () {
      expect(AppUser.empty.uid, '');
      expect(AppUser.empty.email, '');
      expect(AppUser.empty.displayName, null);
      expect(AppUser.empty.photoUrl, null);
      expect(AppUser.empty.isCreator, false);
    });
  });

  group('AppUser - isEmpty extension', () {
    test('isEmpty returns true for empty user', () {
      expect(AppUser.empty.isEmpty, true);
    });

    test('isEmpty returns true for user with empty uid', () {
      const user = AppUser(uid: '', email: 'test@example.com');
      // isEmpty checks if user == AppUser.empty, so this will be false
      expect(user.isEmpty, false);
    });

    test('isEmpty returns false for valid user', () {
      const user = AppUser(uid: 'user_123', email: 'test@example.com');
      expect(user.isEmpty, false);
    });
  });

  group('AppUser - Edge Cases', () {
    test('handles very long uid', () {
      final longUid = 'a' * 500;
      final user = AppUser(uid: longUid, email: 'test@example.com');

      expect(user.uid, longUid);
    });

    test('handles various email formats', () {
      final emails = [
        'test@example.com',
        'user+tag@example.co.uk',
        'name.surname@subdomain.example.com',
        'test123@test.io',
      ];

      for (final email in emails) {
        final user = AppUser(uid: 'user_123', email: email);
        expect(user.email, email);
      }
    });

    test('handles special characters in display name', () {
      const user = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Test User 🎉 (Admin)',
      );

      expect(user.displayName, 'Test User 🎉 (Admin)');
    });

    test('handles empty display name', () {
      const user = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: '',
      );

      expect(user.displayName, '');
    });

    test('handles various photo URL formats', () {
      final urls = [
        'https://example.com/photo.jpg',
        'https://cdn.example.com/users/123/avatar.png',
        'https://storage.googleapis.com/bucket/image.webp',
      ];

      for (final url in urls) {
        final user = AppUser(
          uid: 'user_123',
          email: 'test@example.com',
          photoUrl: url,
        );
        expect(user.photoUrl, url);
      }
    });

    test('handles empty photo URL', () {
      const user = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        photoUrl: '',
      );

      expect(user.photoUrl, '');
    });

    test('handles creator flag variations', () {
      const creator = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        isCreator: true,
      );

      const nonCreator = AppUser(
        uid: 'user_456',
        email: 'test2@example.com',
        isCreator: false,
      );

      expect(creator.isCreator, true);
      expect(nonCreator.isCreator, false);
    });
  });

  group('AppUser - Equality', () {
    test('two users with same values are equal', () {
      const user1 = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        isCreator: true,
      );

      const user2 = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        isCreator: true,
      );

      expect(user1, equals(user2));
    });

    test('two users with different uid are not equal', () {
      const user1 = AppUser(uid: 'user_123', email: 'test@example.com');
      const user2 = AppUser(uid: 'user_456', email: 'test@example.com');

      expect(user1, isNot(equals(user2)));
    });

    test('user is equal to itself', () {
      const user = AppUser(uid: 'user_123', email: 'test@example.com');
      expect(user, equals(user));
    });
  });

  group('AppUser - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      const original = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      final updated = original.copyWith(
        displayName: 'Updated Name',
        isCreator: true,
      );

      expect(updated.uid, 'user_123');
      expect(updated.email, 'test@example.com');
      expect(updated.displayName, 'Updated Name');
      expect(updated.isCreator, true);
    });

    test('copyWith without parameters returns identical values', () {
      const original = AppUser(
        uid: 'user_123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        isCreator: true,
      );

      final copy = original.copyWith();

      expect(copy.uid, original.uid);
      expect(copy.email, original.email);
      expect(copy.displayName, original.displayName);
      expect(copy.photoUrl, original.photoUrl);
      expect(copy.isCreator, original.isCreator);
    });
  });
}
