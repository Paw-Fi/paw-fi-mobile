import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

final mobileOutboxSyncCoordinatorProvider =
    FutureProvider<SyncCoordinator>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  return SyncCoordinator(
    database: database,
    dispatchMutation: (mutation) => _dispatchMobileMutation(database, mutation),
  );
});

Future<int> drainMobileOutbox(Ref ref, {int maxMutations = 20}) async {
  final coordinator =
      await ref.read(mobileOutboxSyncCoordinatorProvider.future);
  return coordinator.drainOutbox(maxMutations: maxMutations);
}

Future<void> _dispatchMobileMutation(
  MonekoDatabase database,
  LocalMutationOutboxData mutation,
) async {
  final payload = _decodePayload(mutation.payloadJson);

  switch (mutation.operation) {
    case 'create':
      final responseBody = await _invokeMutationFunction(
        payload['functionName']?.toString(),
        _mapValue(payload['requestBody']),
      );
      if (mutation.entityType == 'transaction') {
        final savedPayload = _extractSavedEntryPayload(responseBody);
        if (savedPayload == null) {
          throw StateError(
            'Transaction create sync succeeded without a saved transaction payload',
          );
        }
        await database.replaceOptimisticTransaction(
          optimisticId: mutation.entityId,
          savedEntry: ExpenseEntry.fromJson(savedPayload),
          clientMutationId: mutation.clientMutationId,
        );
      }
      return;
    case 'invoke_function':
      await _invokeMutationFunction(
        payload['functionName']?.toString(),
        _mapValue(payload['requestBody']),
      );
      return;
    case 'save_pockets_month':
      await _savePocketsMonth(payload);
      return;
    case 'assign_pocket_category':
      await _assignPocketCategory(payload);
      return;
    case 'save_shared_budget':
      await _saveSharedBudget(payload);
      return;
    case 'update_transaction':
      final responseBody = await _invokeMutationFunction('update-expense', {
        ..._metadataFromPayload(payload),
        'userId': payload['userId'],
        'expenseId': payload['expenseId'] ?? mutation.entityId,
        'updates': _mapValue(payload['updates']) ?? const <String, dynamic>{},
        'clientTimezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        ...?_mapValue(payload['extraBody']),
      });
      final savedPayload = _extractSavedEntryPayload(responseBody);
      if (savedPayload == null) {
        throw StateError(
          'Transaction update sync succeeded without a saved transaction payload',
        );
      }
      await database.markOptimisticTransactionUpdateSynced(
        entry: ExpenseEntry.fromJson(savedPayload),
        clientMutationId: mutation.clientMutationId,
      );
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

Future<Map<String, dynamic>> _invokeMutationFunction(
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
  return responseBody;
}

Map<String, dynamic>? _extractSavedEntryPayload(Map<String, dynamic> data) {
  final saved = data['data'] ?? data['expense'] ?? data['income'];
  if (saved is Map<String, dynamic>) return saved;
  if (saved is Map) return Map<String, dynamic>.from(saved);
  return null;
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

Future<void> _savePocketsMonth(Map<String, dynamic> payload) async {
  final userId = payload['userId']?.toString();
  final scope = payload['scope']?.toString() ?? 'personal';
  final householdId = payload['householdId']?.toString();
  final periodMonth = payload['periodMonth']?.toString();
  final currency = payload['currency']?.toString();
  final totalBudgetCents = (payload['totalBudgetCents'] as num?)?.toInt() ?? 0;
  if (userId == null || userId.isEmpty) {
    throw ArgumentError('Missing userId for pockets sync');
  }
  if (periodMonth == null || periodMonth.isEmpty) {
    throw ArgumentError('Missing periodMonth for pockets sync');
  }
  if (currency == null || currency.isEmpty) {
    throw ArgumentError('Missing currency for pockets sync');
  }

  String? budgetId = payload['budgetId']?.toString();
  if (budgetId == null || budgetId.isEmpty) {
    dynamic query = supabase
        .from('budgets')
        .select('id')
        .eq('period_month', periodMonth)
        .eq('currency', currency);
    if (scope == 'personal') {
      query = query.eq('user_id', userId).isFilter('household_id', null);
    } else {
      if (householdId == null || householdId.isEmpty) {
        throw ArgumentError('Missing householdId for scoped pockets sync');
      }
      query = query.eq('household_id', householdId);
      if (scope == 'portfolio') {
        query = query.eq('user_id', userId);
      }
    }
    final row = await query.limit(1).maybeSingle();
    budgetId = row?['id']?.toString();
  }

  final nowIso = DateTime.now().toUtc().toIso8601String();
  final budgetPayload = <String, dynamic>{
    'user_id': userId,
    'household_id': scope == 'personal' ? null : householdId,
    'currency': currency,
    'period_month': periodMonth,
    'total_budget_cents': totalBudgetCents,
    'updated_at': nowIso,
  };

  if (budgetId == null || budgetId.isEmpty) {
    final inserted = await supabase
        .from('budgets')
        .insert(budgetPayload)
        .select('id')
        .maybeSingle();
    budgetId = inserted?['id']?.toString();
  } else {
    await supabase.from('budgets').update(budgetPayload).eq('id', budgetId);
  }

  if (budgetId == null || budgetId.isEmpty) {
    throw StateError('Unable to resolve budget id for pockets sync');
  }

  final pockets = (payload['pockets'] as List?) ?? const [];
  for (final item in pockets) {
    if (item is! Map) continue;
    final pocket = Map<String, dynamic>.from(item);
    final id = pocket['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final amountCents = (pocket['budgetAmountCents'] as num?)?.toInt() ?? 0;
    final envelopePayload = <String, dynamic>{
      'budget_amount_cents': amountCents,
      'budget_id': budgetId,
      'household_id': scope == 'personal' ? null : householdId,
      'currency': pocket['currency']?.toString() ?? currency,
      'updated_at': nowIso,
      if (pocket['name'] != null) 'name': pocket['name'].toString(),
      if (pocket['icon'] != null) 'icon': pocket['icon'].toString(),
      if (pocket['color'] != null) 'color': pocket['color'].toString(),
      'user_id': userId,
    };
    String envelopeId = id;
    if (id.startsWith('optimistic-')) {
      final inserted = await supabase
          .from('budget_envelopes')
          .insert(envelopePayload)
          .select('id')
          .maybeSingle();
      envelopeId = inserted?['id']?.toString() ?? id;
    } else {
      await supabase
          .from('budget_envelopes')
          .update(envelopePayload)
          .eq('id', id);
    }
    await supabase.from('envelope_allocations').upsert(
      <String, dynamic>{
        'envelope_id': envelopeId,
        'period_month': periodMonth,
        'amount_cents': amountCents,
        'carryover_policy': 'carryover',
        'updated_at': nowIso,
      },
      onConflict: 'envelope_id,period_month',
    );
    final categories = (pocket['categories'] as List?)
            ?.map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false) ??
        const <String>[];
    if (categories.isNotEmpty) {
      await supabase.from('envelope_category_links').upsert(
            categories
                .map((category) => {
                      'envelope_id': envelopeId,
                      'category': category,
                      'created_at': nowIso,
                    })
                .toList(growable: false),
            onConflict: 'envelope_id,category',
          );
    }
  }
}

Future<void> _assignPocketCategory(Map<String, dynamic> payload) async {
  final pocketId = payload['pocketId']?.toString();
  final category = payload['category']?.toString().trim().toLowerCase();
  if (pocketId == null || pocketId.isEmpty) {
    throw ArgumentError('Missing pocketId for pocket category sync');
  }
  if (category == null || category.isEmpty) {
    throw ArgumentError('Missing category for pocket category sync');
  }
  await supabase.from('envelope_category_links').upsert(
    {
      'envelope_id': pocketId,
      'category': category,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    },
    onConflict: 'envelope_id,category',
  );
}

Future<void> _saveSharedBudget(Map<String, dynamic> payload) async {
  final householdId = payload['householdId']?.toString();
  final name = payload['name']?.toString();
  final period = payload['period']?.toString();
  final currency = payload['currency']?.toString();
  final amountCents = (payload['amountCents'] as num?)?.toInt();
  if (householdId == null || householdId.isEmpty) {
    throw ArgumentError('Missing householdId for shared budget sync');
  }
  if (name == null || name.isEmpty) {
    throw ArgumentError('Missing name for shared budget sync');
  }
  if (period == null || period.isEmpty) {
    throw ArgumentError('Missing period for shared budget sync');
  }
  if (currency == null || currency.isEmpty) {
    throw ArgumentError('Missing currency for shared budget sync');
  }
  if (amountCents == null) {
    throw ArgumentError('Missing amountCents for shared budget sync');
  }

  final existing = await supabase
      .from('shared_budgets')
      .select('id')
      .eq('household_id', householdId)
      .eq('currency', currency)
      .eq('period', period)
      .eq('is_active', true)
      .maybeSingle();

  final updates = <String, dynamic>{
    'name': name,
    'amount_cents': amountCents,
    'warn_threshold': (payload['warnThreshold'] as num?)?.toDouble() ?? 0.8,
    'alert_threshold': (payload['alertThreshold'] as num?)?.toDouble() ?? 1.0,
    'count_split_portion_only': payload['countSplitPortionOnly'] == true,
  };

  if (existing != null && existing['id'] != null) {
    await supabase
        .from('shared_budgets')
        .update(updates)
        .eq('id', existing['id'] as String);
    return;
  }

  await supabase.from('shared_budgets').insert({
    'household_id': householdId,
    'period': period,
    'currency': currency,
    'budget_type': payload['budgetType']?.toString() ?? 'household',
    'is_active': true,
    ...updates,
  });
}
