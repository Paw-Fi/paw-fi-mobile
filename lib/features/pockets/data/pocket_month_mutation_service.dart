import 'dart:convert';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef PocketMonthRpcInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> params,
);

class PocketMonthWriteResult {
  const PocketMonthWriteResult({
    required this.budgetId,
    required this.revision,
    required this.canonicalPocketIds,
  });

  final String? budgetId;
  final int revision;
  final Map<String, String> canonicalPocketIds;
}

class PocketMonthRevisionConflict implements Exception {
  const PocketMonthRevisionConflict({
    required this.expectedRevision,
    required this.currentRevision,
  });

  final int expectedRevision;
  final int? currentRevision;

  @override
  String toString() => currentRevision == null
      ? 'Pocket plan changed on another device; refresh before saving again.'
      : 'Pocket plan changed on another device '
          '(expected revision $expectedRevision, current $currentRevision).';
}

class PocketMonthRevisionResponseError implements Exception {
  const PocketMonthRevisionResponseError(this.message);

  final String message;

  @override
  String toString() => message;
}

class PocketMonthRevisionUnavailable implements Exception {
  const PocketMonthRevisionUnavailable();

  @override
  String toString() =>
      'Pocket plan revision is unavailable; refresh before saving.';
}

bool isTerminalPocketDatabaseError(Object error) =>
    error is PostgrestException &&
    const {
      '22023',
      '22P02',
      '23502',
      '23503',
      '23505',
      '23514',
      '42501',
      'P0001'
    }.contains(error.code);

class PocketMonthWriteRejected implements Exception {
  const PocketMonthWriteRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

String pocketMonthReviewError(Object error) => jsonEncode({
      'code': error is PocketMonthRevisionConflict
          ? 'REVISION_CONFLICT'
          : error is PocketMonthRevisionUnavailable
              ? 'REVISION_UNAVAILABLE'
              : 'ACK_UNKNOWN',
      'message': error.toString(),
    });

bool pocketMonthReviewAllowsRollback(String? storedError) {
  try {
    final decoded = jsonDecode(storedError ?? '');
    return decoded is Map &&
        const {'REVISION_CONFLICT', 'REVISION_UNAVAILABLE'}
            .contains(decoded['code']);
  } catch (_) {
    return false;
  }
}

bool pocketMonthReviewNeedsAcknowledgement(String? storedError) {
  try {
    final decoded = jsonDecode(storedError ?? '');
    return decoded is Map && decoded['code'] == 'ACK_UNKNOWN';
  } catch (_) {
    return false;
  }
}

/// Reuse the exact original request and idempotency key after the user chooses
/// recovery. A conflict proves it was not committed; a receipt supplies the
/// canonical IDs even when a later writer has already changed the plan.
Future<PocketMonthWriteResult?> recoverPocketMonthAcknowledgement({
  required String clientMutationId,
  required Map<String, dynamic> payload,
  PocketMonthRpcInvoker? invokeRpc,
}) async {
  try {
    return await savePocketMonthSnapshot(
      userId: payload['userId'] as String,
      scope: payload['scope'] as String,
      householdId: payload['householdId'] as String?,
      periodMonth: payload['periodMonth'] as String,
      currency: payload['currency'] as String,
      expectedRevision: (payload['expectedServerRevision'] as num?)?.toInt(),
      mutationId: '$clientMutationId:${payload['mutationRevision']}',
      snapshot: payload,
      invokeRpc: invokeRpc,
    );
  } on PocketMonthRevisionConflict {
    return null;
  }
}

Future<PocketMonthWriteResult> savePocketMonthSnapshot({
  required String userId,
  required String scope,
  required String? householdId,
  required String periodMonth,
  required String currency,
  required int? expectedRevision,
  required String mutationId,
  required Map<String, dynamic> snapshot,
  PocketMonthRpcInvoker? invokeRpc,
}) async {
  if (expectedRevision == null) {
    throw const PocketMonthRevisionUnavailable();
  }

  final params = <String, dynamic>{
    'p_user_id': userId,
    'p_scope': scope,
    'p_household_id': householdId,
    'p_period_month': periodMonth,
    'p_currency': currency.trim().toUpperCase(),
    'p_expected_revision': expectedRevision,
    'p_mutation_id': mutationId,
    'p_snapshot': snapshot,
  };
  Object? response;
  try {
    response = invokeRpc == null
        ? await supabase.rpc('save_pockets_month_v1', params: params)
        : await invokeRpc('save_pockets_month_v1', params);
  } on PostgrestException catch (error) {
    if (error.code == 'PGRST202' || error.code == '42883') {
      throw const PocketMonthRevisionUnavailable();
    }
    if (isTerminalPocketDatabaseError(error)) {
      throw PocketMonthWriteRejected(error.message);
    }
    rethrow;
  }
  if (response is! Map) {
    throw const PocketMonthRevisionResponseError(
        'Pocket save RPC returned an invalid response.');
  }

  final result = Map<String, dynamic>.from(response);
  if (result['success'] != true && result['code'] == 'REVISION_CONFLICT') {
    final rawCurrentRevision = result['currentRevision'];
    final currentRevision = rawCurrentRevision is num &&
            rawCurrentRevision.isFinite &&
            rawCurrentRevision == rawCurrentRevision.toInt() &&
            rawCurrentRevision >= 0
        ? rawCurrentRevision.toInt()
        : null;
    throw PocketMonthRevisionConflict(
      expectedRevision: expectedRevision,
      currentRevision: currentRevision,
    );
  }
  if (result['success'] != true) {
    throw StateError(
      result['error']?.toString() ?? 'Pocket save was rejected by the server.',
    );
  }

  final rawRevision = result['revision'];
  final revision = rawRevision is num &&
          rawRevision.isFinite &&
          rawRevision == rawRevision.toInt() &&
          rawRevision > expectedRevision
      ? rawRevision.toInt()
      : null;
  final rawBudgetId = result['budgetId'];
  final budgetId = rawBudgetId is String ? rawBudgetId.trim() : '';
  final rawIds = result['canonicalPocketIds'];
  if (revision == null || budgetId.isEmpty || rawIds is! Map) {
    throw const PocketMonthRevisionResponseError(
      'Pocket save returned an incomplete revision acknowledgement; refresh before saving again.',
    );
  }

  final canonicalPocketIds = rawIds
      .map((key, value) => MapEntry(key.toString(), value.toString().trim()));
  final rawPockets = snapshot['pockets'];
  final missingCanonicalIds = rawPockets is List &&
      rawPockets.whereType<Map>().any((pocket) {
        final id = pocket['id']?.toString() ?? '';
        return id.startsWith('optimistic-') &&
            (canonicalPocketIds[id]?.isNotEmpty != true);
      });
  if (missingCanonicalIds ||
      canonicalPocketIds.values.any((id) => id.isEmpty)) {
    throw const PocketMonthRevisionResponseError(
      'Pocket save did not return canonical Pocket identifiers; refresh before saving again.',
    );
  }

  return PocketMonthWriteResult(
    budgetId: budgetId,
    revision: revision,
    canonicalPocketIds: canonicalPocketIds,
  );
}
