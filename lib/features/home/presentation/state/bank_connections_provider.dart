import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_debug_tracing.dart';

final bankConnectionsProvider =
    FutureProvider.autoDispose<List<BankConnection>>((ref) async {
  final trace = WalletsDebugTrace(
    label: 'BankConnections',
    enabled: ref.read(walletsDebugLoggingEnabledProvider),
    logSink: ref.read(walletsDebugLogSinkProvider),
  );
  final user = ref.watch(authProvider);
  if (user.uid.isEmpty) {
    trace.mark('bank-connections-skipped', const {'reason': 'empty-user'});
    return const [];
  }

  try {
    trace.mark('bank-connections-start', {'user': user.uid});
    final response = await supabase
        .from('bank_connections')
        .select(
            'id, household_id, provider, status, metadata, item_status, item_health_state, relink_state, last_successful_sync_at, next_manual_refresh_eligible_at, scheduled_removal_at')
        .eq('user_id', user.uid)
        .isFilter('removed_at', null);

    final rows = (response as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final connections =
        rows.map(BankConnection.fromJson).toList(growable: false);
    connections.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    trace.mark('bank-connections-success', {'count': connections.length});
    return connections;
  } catch (error) {
    trace.mark('bank-connections-error', {'error': error, 'user': user.uid});
    rethrow;
  }
});
