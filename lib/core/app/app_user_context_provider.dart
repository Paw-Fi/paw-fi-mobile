import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';

final appUserContactProvider = Provider<UserContact?>((ref) {
  final preview = ref.watch(previewModeProvider);
  if (preview.isActive) {
    return PreviewMockData.contact;
  }

  final analyticsContact =
      ref.watch(analyticsProvider.select((state) => state.contact));
  if (analyticsContact != null) {
    return analyticsContact;
  }

  return ref
      .watch(appInitializationV2Provider.select((state) => state.data?.user));
});

final appPreferredTimezoneProvider = Provider<String?>((ref) {
  final preferredTimezone =
      ref.watch(appUserContactProvider)?.preferredTimezone;
  final normalized = preferredTimezone?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
});

final appPreferredCurrencyProvider = Provider<String?>((ref) {
  final preferredCurrency =
      ref.watch(appUserContactProvider)?.preferredCurrency;
  final normalized = preferredCurrency?.trim().toUpperCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
});
