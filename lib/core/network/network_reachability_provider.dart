import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:moneko/core/util/constants.dart';

const Duration networkReachabilityCheckInterval = Duration(seconds: 15);
const Duration networkReachabilityTimeout = Duration(seconds: 3);

final networkReachabilityProvider =
    StreamProvider.autoDispose<bool>((ref) async* {
  while (true) {
    yield await hasNetworkAccess();
    await Future<void>.delayed(networkReachabilityCheckInterval);
  }
});

Future<bool> hasNetworkAccess() async {
  final supabaseUrl = Constants.supabaseUrl.trim();
  if (supabaseUrl.isEmpty) return true;

  try {
    await http.head(Uri.parse(supabaseUrl)).timeout(networkReachabilityTimeout);
    return true;
  } catch (_) {
    return false;
  }
}
