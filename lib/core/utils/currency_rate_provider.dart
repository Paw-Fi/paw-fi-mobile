import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/utils/currency_rate_repository.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

final currencyRateRepositoryProvider =
    FutureProvider<CurrencyRateRepository>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  final client = ref.watch(supabaseClientProvider);
  return CurrencyRateRepository(database: database, client: client);
});

final currencyRateTableProvider =
    FutureProvider<CurrencyRateTable>((ref) async {
  final repository = await ref.watch(currencyRateRepositoryProvider.future);
  return repository.getRates();
});

Future<void> syncCurrencyRates(WidgetRef ref,
    {bool forceRefresh = false}) async {
  final repository = await ref.read(currencyRateRepositoryProvider.future);
  await repository.getRates(forceRefresh: forceRefresh);
  ref.invalidate(currencyRateTableProvider);
}
