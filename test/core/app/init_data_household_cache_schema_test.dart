import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';

void main() {
  test('rejects pre-metadata init cache before publishing household layout',
      () {
    final cached = <String, dynamic>{
      'households': [
        {
          'id': 'ce1aabf8-90b1-41d1-9fe6-a4188b36a27f',
          'name': 'Private Space',
          'owner_id': 'ca27d818-fafe-40ea-9e68-92794c6d9cab',
          'currency': 'EUR',
          'created_at': '2026-07-11T18:41:34.257392Z',
          'updated_at': '2026-07-11T18:41:34.257392Z',
        },
      ],
      'timestamp': '2026-07-12T00:00:00.000Z',
    };

    expect(() => InitData.fromJson(cached), throwsFormatException);
  });

  test('accepts current init cache with explicit portfolio metadata', () {
    final cached = <String, dynamic>{
      'household_cache_schema_version': 1,
      'households': [
        {
          'id': 'ce1aabf8-90b1-41d1-9fe6-a4188b36a27f',
          'name': 'Private Space',
          'owner_id': 'ca27d818-fafe-40ea-9e68-92794c6d9cab',
          'currency': 'EUR',
          'is_portfolio': true,
          'created_at': '2026-07-11T18:41:34.257392Z',
          'updated_at': '2026-07-11T18:41:34.257392Z',
        },
      ],
      'timestamp': '2026-07-12T00:00:00.000Z',
    };

    final data = InitData.fromJson(cached);

    expect(data.households.single.isPortfolio, isTrue);
  });
}
