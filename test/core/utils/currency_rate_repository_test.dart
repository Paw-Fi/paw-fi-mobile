import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/utils/currency_rate_repository.dart';

void main() {
  test('returns cached rates when cache is fresh', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    var fetchCount = 0;
    final repository = CurrencyRateRepository(
      database: database,
      fetchRemotePayload: () async {
        fetchCount += 1;
        return {
          'baseCurrency': 'USD',
          'rates': {'USD': 1, 'EUR': 0.8},
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        };
      },
    );

    final first = await repository.getRates();
    final second = await repository.getRates();

    expect(first.rates['EUR'], 0.8);
    expect(second.rates['EUR'], 0.8);
    expect(fetchCount, 1);
  });

  test('falls back to stale cache when remote refresh fails', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    var shouldFail = false;
    final repository = CurrencyRateRepository(
      database: database,
      localTtl: Duration.zero,
      fetchRemotePayload: () async {
        if (shouldFail) throw Exception('offline');
        return {
          'baseCurrency': 'USD',
          'rates': {'USD': 1, 'EUR': 0.8},
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        };
      },
    );

    await repository.getRates();
    shouldFail = true;

    final stale = await repository.getRates();

    expect(stale.rates['EUR'], 0.8);
    expect(stale.isStale, isTrue);
  });
}
