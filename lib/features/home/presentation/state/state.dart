export 'analytics_data.dart';
export 'analytics_notifier.dart';
export 'analytics_provider.dart';
export 'processing_state.dart';
export 'expense_processing_notifier.dart';
export 'expense_processing_provider.dart';
export 'home_filter_provider.dart';
export 'transaction_edit_state.dart';
export 'transaction_edit_notifier.dart';
export 'view_mode_provider.dart';

// Data services
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/data/services/currency_preference_service.dart';

/// Provider for currency preference service
final currencyPreferenceServiceProvider = Provider<CurrencyPreferenceService>(
  (ref) => CurrencyPreferenceService(),
);
