import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';
import 'package:moneko/core/utils/image_compressor.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final mobileOutboxSyncCoordinatorProvider =
    FutureProvider<SyncCoordinator>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  return SyncCoordinator(
    database: database,
    dispatchMutation: (mutation) => _dispatchMobileMutation(database, mutation),
    onMutationCancelled: (mutation, _) =>
        database.markTransactionMutationExhausted(mutation: mutation),
  );
});

bool _isMobileOutboxDrainScheduled = false;
bool _mobileOutboxDrainRequested = false;
Future<int>? _mobileOutboxDrainInFlight;

Duration? resolveNextMobileOutboxRetryDelay(
  Iterable<LocalMutationOutboxData> mutations, {
  required DateTime now,
}) {
  DateTime? nextRetryAt;
  for (final mutation in mutations) {
    if (mutation.status != localMutationStatusQueued &&
        mutation.status != localMutationStatusFailed) {
      continue;
    }

    final retryAfter = mutation.retryAfter;
    if (retryAfter == null || !retryAfter.isAfter(now)) {
      return Duration.zero;
    }
    if (nextRetryAt == null || retryAfter.isBefore(nextRetryAt)) {
      nextRetryAt = retryAfter;
    }
  }

  if (nextRetryAt == null) return null;
  return nextRetryAt.difference(now);
}

void scheduleMobileOutboxDrain(
  ProviderContainer container, {
  int maxMutations = 20,
  Duration initialDelay = Duration.zero,
}) {
  if (_isMobileOutboxDrainScheduled) {
    _mobileOutboxDrainRequested = true;
    return;
  }
  _isMobileOutboxDrainScheduled = true;

  Future<void>(() async {
    try {
      if (initialDelay > Duration.zero) {
        await Future<void>.delayed(initialDelay);
      }

      await _drainMobileOutboxWithContainer(
        container,
        maxMutations: maxMutations,
      );
    } catch (_) {
      // Main shell lifecycle sync remains the fallback if the container is
      // disposed or the local database/provider graph is unavailable.
    } finally {
      _isMobileOutboxDrainScheduled = false;
      if (_mobileOutboxDrainRequested) {
        _mobileOutboxDrainRequested = false;
        scheduleMobileOutboxDrain(container, maxMutations: maxMutations);
      }
    }
  });
}

Future<int> drainMobileOutbox(Ref ref, {int maxMutations = 20}) async {
  return _drainMobileOutboxWithReader(
    () => ref.read(mobileOutboxSyncCoordinatorProvider.future),
    maxMutations: maxMutations,
  );
}

Future<int> _drainMobileOutboxWithContainer(
  ProviderContainer container, {
  required int maxMutations,
}) {
  return _drainMobileOutboxWithReader(
    () => container.read(mobileOutboxSyncCoordinatorProvider.future),
    maxMutations: maxMutations,
  );
}

Future<int> _drainMobileOutboxWithReader(
  Future<SyncCoordinator> Function() readCoordinator, {
  required int maxMutations,
}) {
  final inFlight = _mobileOutboxDrainInFlight;
  if (inFlight != null) return inFlight;

  final run = () async {
    try {
      final coordinator = await readCoordinator();
      return coordinator.drainOutbox(maxMutations: maxMutations);
    } finally {
      _mobileOutboxDrainInFlight = null;
    }
  }();
  _mobileOutboxDrainInFlight = run;
  return run;
}

Future<void> _dispatchMobileMutation(
  MonekoDatabase database,
  LocalMutationOutboxData mutation,
) async {
  final payload = _decodePayload(mutation.payloadJson);

  switch (mutation.operation) {
    case 'create':
      final requestBody = await _requestBodyWithQueuedReceipt(
        _mapValue(payload['requestBody']),
        payload,
      );
      final responseBody = await _invokeMutationFunction(
        payload['functionName']?.toString(),
        requestBody,
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
      await _deleteQueuedLocalFile(payload['localReceiptImagePath']);
      return;
    case 'analyze_ai_input':
      await _analyzeQueuedAiInput(database, payload, mutation.entityId);
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
    case 'save_scenario_history':
      await _saveScenarioHistory(payload);
      return;
    case 'delete_scenario_history':
      await _deleteScenarioHistory(payload);
      return;
    case 'assign_pocket_category':
      await _assignPocketCategory(payload);
      return;
    case 'save_shared_budget':
      await _saveSharedBudget(payload);
      return;
    case 'save_category_remap':
      await _saveCategoryRemap(payload);
      return;
    case 'delete_category_remap':
      await _deleteCategoryRemap(payload);
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
      await database.markOptimisticTransactionDeleteSynced(
        clientMutationId: mutation.clientMutationId,
      );
      return;
    default:
      throw UnsupportedError(
          'Unsupported local mutation: ${mutation.operation}');
  }
}

Future<void> _saveScenarioHistory(Map<String, dynamic> payload) async {
  final userId = payload['userId']?.toString();
  final question = payload['question']?.toString();
  final answer = payload['answer']?.toString();
  if (userId == null || userId.isEmpty) {
    throw ArgumentError('Missing userId for scenario history sync');
  }
  if (question == null || question.isEmpty) {
    throw ArgumentError('Missing question for scenario history sync');
  }
  if (answer == null || answer.isEmpty) {
    throw ArgumentError('Missing answer for scenario history sync');
  }
  await supabase.from('ai_scenario_history').insert({
    'user_id': userId,
    'household_id': payload['householdId'],
    'question': question,
    'answer': answer,
    'target_date': payload['targetDate'],
    'currency': payload['currency'],
    'mode': payload['mode']?.toString() ?? 'personal',
  });
}

Future<void> _deleteScenarioHistory(Map<String, dynamic> payload) async {
  final scenarioId = payload['scenarioId']?.toString();
  if (scenarioId == null || scenarioId.isEmpty) {
    throw ArgumentError('Missing scenarioId for scenario history delete sync');
  }
  await supabase.from('ai_scenario_history').delete().eq('id', scenarioId);
}

Future<void> _saveCategoryRemap(Map<String, dynamic> payload) async {
  final userId = payload['userId']?.toString().trim();
  final transactionType = payload['transactionType']?.toString().trim();
  final fromCategory = payload['fromCategory']?.toString().trim();
  final toCategory = payload['toCategory']?.toString().trim();
  if (userId == null ||
      userId.isEmpty ||
      transactionType == null ||
      (transactionType != 'expense' && transactionType != 'income') ||
      fromCategory == null ||
      fromCategory.isEmpty ||
      toCategory == null ||
      toCategory.isEmpty) {
    throw ArgumentError('Invalid category remap payload');
  }

  final localUseCount =
      (payload['useCount'] is num) ? (payload['useCount'] as num).toInt() : 1;
  var nextUseCount = localUseCount < 1 ? 1 : localUseCount;
  try {
    final existing = await supabase
        .from('user_category_remaps')
        .select('use_count')
        .eq('user_id', userId)
        .eq('transaction_type', transactionType)
        .eq('from_category_name', fromCategory)
        .maybeSingle();
    final existingUseCount = existing?['use_count'];
    if (existingUseCount is num && existingUseCount >= nextUseCount) {
      nextUseCount = existingUseCount.toInt() + 1;
    }
  } catch (_) {
    // Keep the local count when the pre-read fails; the upsert below remains
    // idempotent and will retry from the outbox if Supabase is unavailable.
  }

  await supabase.from('user_category_remaps').upsert(
    <String, dynamic>{
      'user_id': userId,
      'transaction_type': transactionType,
      'from_category_name': fromCategory,
      'to_category_name': toCategory,
      'use_count': nextUseCount,
      'last_used_at': payload['lastUsedAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
    },
    onConflict: 'user_id,transaction_type,from_category_name',
  );
}

Future<void> _deleteCategoryRemap(Map<String, dynamic> payload) async {
  final userId = payload['userId']?.toString().trim();
  final transactionType = payload['transactionType']?.toString().trim();
  final fromCategory = payload['fromCategory']?.toString().trim();
  if (userId == null ||
      userId.isEmpty ||
      transactionType == null ||
      (transactionType != 'expense' && transactionType != 'income') ||
      fromCategory == null ||
      fromCategory.isEmpty) {
    throw ArgumentError('Invalid category remap delete payload');
  }

  await supabase
      .from('user_category_remaps')
      .delete()
      .eq('user_id', userId)
      .eq('transaction_type', transactionType)
      .eq('from_category_name', fromCategory);
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

Future<Map<String, dynamic>?> _requestBodyWithQueuedReceipt(
  Map<String, dynamic>? requestBody,
  Map<String, dynamic> payload,
) async {
  if (requestBody == null) return null;
  final localReceiptImagePath = payload['localReceiptImagePath']?.toString();
  if (localReceiptImagePath == null || localReceiptImagePath.isEmpty) {
    return requestBody;
  }
  if (requestBody['receiptImageUrl'] != null) return requestBody;

  final userId =
      requestBody['userId']?.toString() ?? payload['userId']?.toString();
  if (userId == null || userId.isEmpty) {
    throw ArgumentError('Missing userId for queued receipt upload');
  }
  final receiptUrl = await _uploadQueuedReceiptImage(
    localReceiptImagePath,
    userId,
    storageKey: payload['clientMutationId']?.toString() ??
        payload['idempotencyKey']?.toString(),
  );
  return <String, dynamic>{
    ...requestBody,
    'receiptImageUrl': receiptUrl,
  };
}

Future<void> _analyzeQueuedAiInput(
  MonekoDatabase database,
  Map<String, dynamic> payload,
  String queuedInputId,
) async {
  final userId = payload['userId']?.toString();
  if (userId == null || userId.isEmpty) {
    throw ArgumentError('Missing userId for queued AI input');
  }

  final analysisBody = await _queuedAiAnalysisBody(payload);
  final analysisResponse = await _invokeMutationFunction(
    'analyze-expense',
    analysisBody,
  );
  final transactions = await _saveTransactionsForQueuedAiInput(
    database: database,
    userId: userId,
    payload: payload,
    queuedInputId: queuedInputId,
    analysisResponse: analysisResponse,
  );
  if (transactions.isEmpty) {
    throw StateError('Queued AI input produced no saveable transactions');
  }

  final batchResponse =
      await _invokeMutationFunction('save-transactions-batch', {
    'userId': userId,
    'debugTraceId': 'mobile-ai-replay-$queuedInputId',
    if (payload['householdId'] != null) 'householdId': payload['householdId'],
    if (payload['householdId'] != null)
      'isPortfolio': payload['isPortfolio'] == true,
    'transactions': transactions,
  });
  _ensureQueuedBatchSavedAll(
    batchResponse,
    expectedCount: transactions.length,
  );
  await _deleteQueuedAiInputFiles(payload);
}

void _ensureQueuedBatchSavedAll(
  Map<String, dynamic> responseBody, {
  required int expectedCount,
}) {
  final summary = _mapValue(responseBody['summary']);
  final summaryFailed = (summary?['failed'] as num?)?.toInt();
  final summarySucceeded = (summary?['succeeded'] as num?)?.toInt();
  final rawResults = responseBody['results'];
  final results = rawResults is List
      ? rawResults.map(_mapValue).whereType<Map<String, dynamic>>().toList()
      : const <Map<String, dynamic>>[];
  final failedResults = results.where((result) => result['success'] != true);

  if (summaryFailed != null && summaryFailed > 0) {
    throw StateError(
      'Queued AI input batch save failed for $summaryFailed transaction(s)',
    );
  }
  if (failedResults.isNotEmpty) {
    throw StateError(
      'Queued AI input batch save returned failed transaction result(s)',
    );
  }
  if (summarySucceeded != null && summarySucceeded < expectedCount) {
    throw StateError(
      'Queued AI input batch save persisted $summarySucceeded/$expectedCount transaction(s)',
    );
  }
  if (results.isNotEmpty && results.length < expectedCount) {
    throw StateError(
      'Queued AI input batch save returned ${results.length}/$expectedCount transaction result(s)',
    );
  }
}

Future<void> _deleteQueuedAiInputFiles(Map<String, dynamic> payload) async {
  await _deleteQueuedLocalFile(payload['localImagePath']);
  await _deleteQueuedLocalFile(payload['localAudioPath']);
}

Future<void> _deleteQueuedLocalFile(Object? path) async {
  final value = path?.toString().trim();
  if (value == null || value.isEmpty) return;

  try {
    final file = File(value);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

Future<Map<String, dynamic>> _queuedAiAnalysisBody(
  Map<String, dynamic> payload,
) async {
  final body = _mapValue(payload['body']);
  if (body == null || body.isEmpty) {
    throw ArgumentError('Missing queued AI input body');
  }
  final nextBody = Map<String, dynamic>.from(body);

  final localImagePath = payload['localImagePath']?.toString();
  if (localImagePath != null && localImagePath.isNotEmpty) {
    final file = File(localImagePath);
    if (!await file.exists()) {
      throw FileSystemException('Queued AI image is missing', localImagePath);
    }
    nextBody['image'] = <String, dynamic>{
      'data': base64Encode(await file.readAsBytes()),
      'contentType': payload['imageContentType']?.toString() ?? 'image/jpeg',
    };
  }

  final localAudioPath = payload['localAudioPath']?.toString();
  if (localAudioPath != null && localAudioPath.isNotEmpty) {
    final file = File(localAudioPath);
    if (!await file.exists()) {
      throw FileSystemException('Queued AI audio is missing', localAudioPath);
    }
    nextBody['audio'] = <String, dynamic>{
      'data': base64Encode(await file.readAsBytes()),
      'contentType': payload['audioContentType']?.toString() ?? 'audio/mpeg',
    };
  }

  return nextBody;
}

Future<List<Map<String, dynamic>>> _saveTransactionsForQueuedAiInput({
  required MonekoDatabase database,
  required String userId,
  required Map<String, dynamic> payload,
  required String queuedInputId,
  required Map<String, dynamic> analysisResponse,
}) async {
  final data = _mapValue(analysisResponse['data']);
  final rawItems = data?['items'];
  if (rawItems is! List || rawItems.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  final items = rawItems.length > 1
      ? rawItems.where((item) => !_isTotalLikeAnalysisItem(item)).toList()
      : rawItems;
  if (items.isEmpty) return const <Map<String, dynamic>>[];

  String? receiptUrl;
  final localImagePath = payload['localImagePath']?.toString();
  if (localImagePath != null && localImagePath.isNotEmpty) {
    final userId = payload['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw ArgumentError('Missing userId for queued receipt upload');
    }
    receiptUrl = await _uploadQueuedReceiptImage(
      localImagePath,
      userId,
      storageKey: queuedInputId,
    );
  }

  final clientCreatedAt = DateTime.now().toUtc().toIso8601String();
  final queuedBody = _mapValue(payload['body']);
  final transactions = <Map<String, dynamic>>[];
  for (var index = 0; index < items.length; index++) {
    final item = _mapValue(items[index]);
    if (item == null) continue;

    final amount = _parseAmount(item['amount']);
    final currency = item['currency']?.toString().trim();
    final date =
        item['date']?.toString().trim() ?? queuedBody?['date']?.toString();
    if (amount == null || currency == null || currency.isEmpty) continue;
    if (date == null || date.isEmpty) continue;

    final rawType = item['type']?.toString().trim().toLowerCase();
    final isIncome = rawType == 'income' || item['is_income'] == true;
    final rawCategory = item['category']?.toString().trim();
    final category = await _resolveQueuedCategory(
      database: database,
      userId: userId,
      transactionType: isIncome ? 'income' : 'expense',
      rawCategory: rawCategory,
      rawDescription: item['description']?.toString().trim(),
      fallbackCategory: isIncome ? 'income' : 'other',
    );
    final clientRecordId = '$queuedInputId-$index';
    final transaction = <String, dynamic>{
      'type': isIncome ? 'income' : 'expense',
      'amount': amount,
      'category': category,
      'currency': currency,
      'date': date,
      'clientCreatedAt': clientCreatedAt,
      'clientRecordId': clientRecordId,
      'clientMutationId': 'mobile:$clientRecordId',
      'idempotencyKey': 'mobile:$clientRecordId',
      if (payload['accountId'] != null) 'accountId': payload['accountId'],
      if (!isIncome && receiptUrl != null) 'receiptImageUrl': receiptUrl,
      if (item['description']?.toString().trim().isNotEmpty == true)
        'description': item['description'].toString().trim(),
      if (item['breakdown'] is List) 'breakdown': item['breakdown'],
      if (item['payerUserId']?.toString().trim().isNotEmpty == true)
        'payerUserId': item['payerUserId'].toString().trim(),
      if (item['customSplits'] is Map) 'customSplits': item['customSplits'],
    };
    transactions.add(transaction);
  }
  return transactions;
}

Future<String> _resolveQueuedCategory({
  required MonekoDatabase database,
  required String userId,
  required String transactionType,
  required String? rawCategory,
  required String? rawDescription,
  required String fallbackCategory,
}) async {
  final category = _resolveQueuedBaseCategory(
    rawCategory: rawCategory,
    rawDescription: rawDescription,
    fallbackCategory: fallbackCategory,
  );
  final mapped = await database.resolveCategoryRemap(
    userId: userId,
    category: category,
    transactionType: transactionType,
  );
  return mapped ?? category;
}

String _resolveQueuedBaseCategory({
  required String? rawCategory,
  required String? rawDescription,
  required String fallbackCategory,
}) {
  final normalizedCategory = normalizeCategory(rawCategory ?? '');
  final builtinCategory = resolveBuiltinCategoryKeyAcrossLocales(
    normalizedCategory,
  );
  if (builtinCategory != null &&
      builtinCategory != 'other' &&
      builtinCategory != 'uncategorized') {
    return builtinCategory;
  }

  final normalizedDescription = normalizeCategory(rawDescription ?? '');
  final descriptionCategory = resolveBuiltinCategoryKeyAcrossLocales(
    normalizedDescription,
  );
  if (descriptionCategory != null &&
      descriptionCategory != 'other' &&
      descriptionCategory != 'uncategorized') {
    return descriptionCategory;
  }

  return builtinCategory ?? fallbackCategory;
}

double? _parseAmount(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool _isTotalLikeAnalysisItem(Object? value) {
  final item = _mapValue(value);
  final description = item?['description']?.toString() ?? '';
  return RegExp(
    r'(sub\s*total|subtotal|grand\s*total|total)',
    caseSensitive: false,
  ).hasMatch(description);
}

Future<String> _uploadQueuedReceiptImage(
  String localImagePath,
  String userId, {
  String? storageKey,
}) async {
  final imageFile = File(localImagePath);
  if (!await imageFile.exists()) {
    throw FileSystemException(
        'Queued receipt image is missing', localImagePath);
  }

  final compressedBytes = await ImageCompressor.compressFile(
    imageFile,
    config: ImageCompressConfig.receipt,
  );
  final safeStorageKey = storageKey
      ?.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .trim();
  final fileName = safeStorageKey != null && safeStorageKey.isNotEmpty
      ? '$safeStorageKey.jpg'
      : '${DateTime.now().millisecondsSinceEpoch}.jpg';
  final path = 'receipts/$userId/$fileName';
  final response = await supabase.storage.from('expense-receipts').uploadBinary(
        path,
        compressedBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          cacheControl: '31536000',
          upsert: true,
        ),
      );
  if (response.isEmpty) {
    throw StateError('Queued receipt upload failed');
  }
  return supabase.storage.from('expense-receipts').getPublicUrl(path);
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
  final replaceMissingPockets = payload['replaceMissingPockets'] == true;
  final replaceCategories = payload['replaceCategories'] == true;
  if (replaceMissingPockets) {
    final keptEnvelopeIds = pockets
        .whereType<Map>()
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty && !id.startsWith('optimistic-'))
        .toSet();
    final existingRows = await supabase
        .from('budget_envelopes')
        .select('id')
        .eq('budget_id', budgetId);
    for (final row in (existingRows as List?) ?? const []) {
      if (row is! Map) continue;
      final id = row['id']?.toString();
      if (id == null || id.isEmpty || keptEnvelopeIds.contains(id)) continue;
      await supabase.from('budget_envelopes').delete().eq('id', id);
    }
  }
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
    if (replaceCategories) {
      await supabase
          .from('envelope_category_links')
          .delete()
          .eq('envelope_id', envelopeId);
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
