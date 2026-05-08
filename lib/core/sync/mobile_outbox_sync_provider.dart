import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';

final mobileOutboxSyncCoordinatorProvider =
    FutureProvider<SyncCoordinator>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  return SyncCoordinator(
    database: database,
    dispatchMutation: _dispatchMobileMutation,
  );
});

Future<int> drainMobileOutbox(Ref ref, {int maxMutations = 20}) async {
  final coordinator =
      await ref.read(mobileOutboxSyncCoordinatorProvider.future);
  return coordinator.drainOutbox(maxMutations: maxMutations);
}

Future<void> _dispatchMobileMutation(LocalMutationOutboxData mutation) async {
  final payload = _decodePayload(mutation.payloadJson);

  switch (mutation.operation) {
    case 'create':
      await _invokeMutationFunction(
        payload['functionName']?.toString(),
        _mapValue(payload['requestBody']),
      );
      return;
    case 'update_transaction':
      await _invokeMutationFunction('update-expense', {
        ..._metadataFromPayload(payload),
        'userId': payload['userId'],
        'expenseId': payload['expenseId'] ?? mutation.entityId,
        'updates': _mapValue(payload['updates']) ?? const <String, dynamic>{},
        'clientTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        ...?_mapValue(payload['extraBody']),
      });
      return;
    case 'delete_transaction':
      await _invokeMutationFunction('delete-expense', {
        ..._metadataFromPayload(payload),
        'userId': payload['userId'],
        'expenseIds': payload['expenseIds'] ?? mutation.entityId,
      });
      return;
    default:
      throw UnsupportedError(
          'Unsupported local mutation: ${mutation.operation}');
  }
}

Future<void> _invokeMutationFunction(
  String? functionName,
  Map<String, dynamic>? body,
) async {
  if (functionName == null || functionName.isEmpty) {
    throw ArgumentError('Missing mutation function name');
  }
  if (body == null || body.isEmpty) {
    throw ArgumentError('Missing mutation payload for $functionName');
  }

  final response = await supabase.functions.invoke(functionName, body: body);
  final responseBody = _mapValue(response.data);
  if (responseBody == null || responseBody['success'] != true) {
    throw Exception(
      responseBody?['error']?.toString() ?? '$functionName failed',
    );
  }
}

Map<String, dynamic> _decodePayload(String payloadJson) {
  final decoded = jsonDecode(payloadJson);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('Mutation payload is not a JSON object');
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

Map<String, dynamic> _metadataFromPayload(Map<String, dynamic> payload) {
  return {
    if (payload['clientRecordId'] != null)
      'clientRecordId': payload['clientRecordId'],
    if (payload['clientMutationId'] != null)
      'clientMutationId': payload['clientMutationId'],
    if (payload['idempotencyKey'] != null)
      'idempotencyKey': payload['idempotencyKey'],
  };
}
