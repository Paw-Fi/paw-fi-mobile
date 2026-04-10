import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';

final bankConnectionsProvider =
    FutureProvider.autoDispose<List<BankConnection>>((ref) async {
  final user = ref.watch(authProvider);
  if (user.uid.isEmpty) return const [];

  final response = await supabase
      .from('bank_connections')
      .select('id, household_id, provider, status, metadata')
      .eq('user_id', user.uid);

  final rows = (response as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final connections = rows.map(BankConnection.fromJson).toList(growable: false);
  connections.sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  return connections;
});
