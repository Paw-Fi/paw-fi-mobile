import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_repository.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('dashboard repository is available synchronously from injected services',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(dashboardRepositoryProvider),
      isA<DashboardRepository>(),
    );
    expect(
      () => container.read(personalDashboardProvider('user-1')),
      returnsNormally,
    );
  });
}
