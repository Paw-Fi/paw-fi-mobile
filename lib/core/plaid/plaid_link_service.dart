import 'dart:async';

import 'package:plaid_flutter/plaid_flutter.dart';

class PlaidLinkResult {
  PlaidLinkResult({
    this.publicToken,
    this.institutionId,
    this.institutionName,
    this.linkRequestId,
    this.linkSessionId,
    this.selectedAccounts = const <PlaidLinkSelectedAccount>[],
  });

  final String? publicToken;
  final String? institutionId;
  final String? institutionName;
  final String? linkRequestId;
  final String? linkSessionId;
  final List<PlaidLinkSelectedAccount> selectedAccounts;
}

class PlaidLinkSelectedAccount {
  const PlaidLinkSelectedAccount({
    required this.id,
    this.mask,
    this.name,
    this.subtype,
    this.type,
  });

  final String id;
  final String? mask;
  final String? name;
  final String? subtype;
  final String? type;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mask': mask,
        'name': name,
        'subtype': subtype,
        'type': type,
      };
}

Future<PlaidLinkResult?> openPlaidLink(String linkToken) async {
  final completer = Completer<PlaidLinkResult?>();
  String? latestLinkRequestId;
  String? latestLinkSessionId;

  late final StreamSubscription<LinkSuccess> successSub;
  late final StreamSubscription<LinkExit> exitSub;
  late final StreamSubscription<LinkEvent> eventSub;

  void completeOnce(PlaidLinkResult? result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  void closeLink() => unawaited(PlaidLink.close());

  successSub = PlaidLink.onSuccess.listen((success) {
    final publicToken = success.publicToken;
    final institution = success.metadata.institution;
    completeOnce(
      PlaidLinkResult(
        publicToken: publicToken,
        institutionId: institution?.id,
        institutionName: institution?.name,
        linkRequestId: latestLinkRequestId,
        linkSessionId: success.metadata.linkSessionId.isNotEmpty
            ? success.metadata.linkSessionId
            : latestLinkSessionId,
        selectedAccounts: success.metadata.accounts
            .map(
              (account) => PlaidLinkSelectedAccount(
                id: account.id,
                mask: account.mask,
                name: account.name,
                subtype: account.subtype,
                type: account.type,
              ),
            )
            .toList(growable: false),
      ),
    );
    closeLink();
  });

  exitSub = PlaidLink.onExit.listen((exit) {
    // User closed/cancelled Link.
    completeOnce(null);
    closeLink();
  });

  eventSub = PlaidLink.onEvent.listen((event) {
    latestLinkRequestId = event.metadata.requestId ?? latestLinkRequestId;
    latestLinkSessionId = event.metadata.linkSessionId.isNotEmpty
        ? event.metadata.linkSessionId
        : latestLinkSessionId;
    final name = event.name.toLowerCase();
    if (name.contains('exit')) {
      completeOnce(null);
      closeLink();
    }
  });

  try {
    final configuration = LinkTokenConfiguration(token: linkToken);
    await PlaidLink.create(configuration: configuration);
    await PlaidLink.open();
    return await completer.future;
  } finally {
    await successSub.cancel();
    await exitSub.cancel();
    await eventSub.cancel();

    // Ensure the Plaid UI is closed before returning to app UI.
    closeLink();
  }
}
