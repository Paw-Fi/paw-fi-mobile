export 'analytics_data.dart';
export 'analytics_notifier.dart';
export 'analytics_provider.dart';
export 'processing_state.dart';
export 'expense_processing_notifier.dart';
export 'expense_processing_provider.dart';
export 'home_filter_provider.dart';
export 'bank_sync_result_provider.dart';
export 'home_card_filter_provider.dart';
export 'derived_selectors.dart';
export 'currency_transaction_counts_provider.dart';
export 'transaction_edit_state.dart';
export 'transaction_edit_notifier.dart';
export 'view_mode_provider.dart';

// Data services
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/data/services/currency_preference_service.dart';
import 'package:moneko/features/home/data/services/date_range_preference_service.dart';

/// Provider for currency preference service
final currencyPreferenceServiceProvider = Provider<CurrencyPreferenceService>(
  (ref) => CurrencyPreferenceService(),
);

/// Provider for date range preference service
final dateRangePreferenceServiceProvider = Provider<DateRangePreferenceService>(
  (ref) => DateRangePreferenceService(),
);

/// Simple counter used to force widget sync when pockets configuration
/// changes (e.g. budgets or envelope category mappings). Incrementing this
/// will cause [WidgetSyncManager] to recompute widget data.
final widgetSyncVersionProvider = StateProvider<int>((ref) => 0);
