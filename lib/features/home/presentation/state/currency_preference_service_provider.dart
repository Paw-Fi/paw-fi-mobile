import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/data/services/currency_preference_service.dart';

final currencyPreferenceServiceProvider = Provider<CurrencyPreferenceService>(
  (ref) => CurrencyPreferenceService(),
);
