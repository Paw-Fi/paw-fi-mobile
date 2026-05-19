import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CurrencyRatePayloadFetcher = Future<Map<String, dynamic>> Function();

const String currencyRatesCacheNamespace = 'currency_rates';
const String currencyRatesCacheKey = 'latest_usd';
const Duration defaultCurrencyRatesLocalTtl = Duration(hours: 2);

class CurrencyRateRepository {
  CurrencyRateRepository({
    required MonekoDatabase database,
    SupabaseClient? client,
    CurrencyRatePayloadFetcher? fetchRemotePayload,
    this.localTtl = defaultCurrencyRatesLocalTtl,
  })  : _database = database,
        _client = client,
        _fetchRemotePayload = fetchRemotePayload;

  final MonekoDatabase _database;
  final SupabaseClient? _client;
  final CurrencyRatePayloadFetcher? _fetchRemotePayload;
  final Duration localTtl;

  Future<CurrencyRateTable> getRates({bool forceRefresh = false}) async {
    final cached = await _readCachedRates();
    if (!forceRefresh && cached != null && !_isLocalCacheStale(cached)) {
      return cached.table;
    }

    try {
      final payload = await _fetchRemoteRates();
      final table = CurrencyRateTable.fromJson(payload);
      await _database.upsertJsonCache(
        namespace: currencyRatesCacheNamespace,
        cacheKey: currencyRatesCacheKey,
        payload: table.toJson(),
        cachedAt: DateTime.now().toUtc(),
      );
      return table;
    } catch (_) {
      if (cached != null) {
        return CurrencyRateTable(
          baseCurrency: cached.table.baseCurrency,
          rates: cached.table.rates,
          fetchedAt: cached.table.fetchedAt,
          source: cached.table.source,
          isStale: true,
        );
      }
      return const CurrencyRateTable(
        baseCurrency: 'USD',
        rates: CurrencyRates.rates,
        fetchedAt: null,
        source: 'bundled-fallback',
        isStale: true,
      );
    }
  }

  Future<_CachedCurrencyRateTable?> _readCachedRates() async {
    final entry = await _database.getJsonCache(
      namespace: currencyRatesCacheNamespace,
      cacheKey: currencyRatesCacheKey,
    );
    if (entry == null) return null;
    return _CachedCurrencyRateTable(
      table: CurrencyRateTable.fromJson(entry.payload),
      cachedAt: entry.cachedAt,
    );
  }

  bool _isLocalCacheStale(_CachedCurrencyRateTable cached) {
    return DateTime.now().toUtc().difference(cached.cachedAt.toUtc()) >=
        localTtl;
  }

  Future<Map<String, dynamic>> _fetchRemoteRates() async {
    final fetcher = _fetchRemotePayload;
    if (fetcher != null) return fetcher();

    final client = _client ?? Supabase.instance.client;
    final response = await client.functions.invoke('currency-rates');
    if (response.status >= 400) {
      throw Exception('Currency rates request failed (${response.status})');
    }
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid currency rates response');
  }
}

class _CachedCurrencyRateTable {
  const _CachedCurrencyRateTable({
    required this.table,
    required this.cachedAt,
  });

  final CurrencyRateTable table;
  final DateTime cachedAt;
}
