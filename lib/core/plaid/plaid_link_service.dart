import 'dart:async';

import 'package:plaid_flutter/plaid_flutter.dart';

class PlaidLinkResult {
  PlaidLinkResult({
    required this.publicToken,
    this.institutionId,
    this.institutionName,
  });

  final String publicToken;
  final String? institutionId;
  final String? institutionName;
}

Future<PlaidLinkResult?> openPlaidLink(String linkToken) async {
  final completer = Completer<PlaidLinkResult?>();

  late final StreamSubscription<LinkSuccess> successSub;
  late final StreamSubscription<LinkExit> exitSub;
  late final StreamSubscription<LinkEvent> eventSub;

  void completeOnce(PlaidLinkResult? result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  successSub = PlaidLink.onSuccess.listen((success) {
    final publicToken = success.publicToken;
    final institution = success.metadata.institution;
    completeOnce(
      PlaidLinkResult(
        publicToken: publicToken,
        institutionId: institution?.id,
        institutionName: institution?.name,
      ),
    );
  });

  exitSub = PlaidLink.onExit.listen((exit) {
    // User closed/cancelled Link.
    completeOnce(null);
  });

  eventSub = PlaidLink.onEvent.listen((event) {
    // Optional: log events or analytics if desired.
  });

  final configuration = LinkTokenConfiguration(token: linkToken);

  await PlaidLink.create(configuration: configuration);
  await PlaidLink.open();

  final result = await completer.future;

  await successSub.cancel();
  await exitSub.cancel();
  await eventSub.cancel();

  return result;
}
