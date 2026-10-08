import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/utils/async_value_extensions.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_user_context_provider.dart';

/// Reuse contact metadata before the slower full Analytics load completes.
/// An unknown preference is distinct from a confirmed first-day cycle.
final financialMonthStartDayStateProvider = Provider<AsyncValue<int>>((ref) {
  if (ref.watch(previewModeProvider.select((state) => state.isActive))) {
    return AsyncData(normalizeFinancialMonthStartDay(
        PreviewMockData.contact.financialMonthStartDay));
  }
  final userId = ref.watch(authProvider.select((user) => user.uid));
  if (userId.isEmpty) return const AsyncData(1);

  final analyticsContact =
      ref.watch(analyticsProvider.select((state) => state.contact));
  final initializedContact = ref.watch(
    appInitializationV2Provider.select((state) => state.data?.user),
  );
  for (final contact in [
    analyticsContact,
    initializedContact,
  ]) {
    if (contact != null && contact.userId == userId) {
      return AsyncData(
          normalizeFinancialMonthStartDay(contact.financialMonthStartDay));
    }
  }

  // The existing dashboard contact read also covers users with no contact row.
  final contact = ref.watch(dashboardUserContactProvider);

  return contact.whenDataWithPrevious((value) {
    if (value != null && value.userId != userId) {
      throw StateError('Financial month contact belongs to another user');
    }
    return normalizeFinancialMonthStartDay(value?.financialMonthStartDay);
  });
});

final financialMonthStartDayProvider = Provider<int>(
    (ref) => ref.watch(financialMonthStartDayStateProvider).valueOrNull ?? 1);
