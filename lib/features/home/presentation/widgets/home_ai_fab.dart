import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' hide XFile;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:crypto/crypto.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/services/sse_service.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/transaction_selection_sheet.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/image_compressor.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/ai_hold_quick_action_preference.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/utils/smart_transaction_input.dart';
import 'package:moneko/features/home/presentation/widgets/ai_camera_capture_view.dart';
import 'package:moneko/features/home/presentation/widgets/ai_input_target.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_config_codec.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/import/presentation/pages/import_wizard_page.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/utils/optimistic_split_group_builder.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared helpers and widgets for the unified transaction FAB / AI expense capture.

const int _reviewFirstPromptAt = 2;
const int _reviewSecondInterval = 2;
const int _reviewThirdInterval = 3;
const int _reviewMaxInterval = 5;
const String _reviewExpenseCountKey = 'review_expense_count';
const String _reviewLastPromptKey = 'review_last_prompt_count';
const String _reviewLastIntervalKey = 'review_last_prompt_interval';
const String _holdQuickActionReminderShownKey =
    'hold_quick_action_reminder_shown';
const String _holdQuickActionReminderExpenseCountKey =
    'hold_quick_action_reminder_expense_count';
const int _holdQuickActionReminderFirstPromptAt = 2;
const int _maxBatchSize = 400;
const int _maxAiFileUploadBytes = 20 * 1024 * 1024;
const double _recordCancelDragThreshold = 90;
const int _minimumHoldRecordingMs = 1000;
const double _silentRecordingPeakDb = -160.0;
const double _minimumVoicePeakDb = -55.0;
const String _smartInputMemoryKeyPrefix = 'smart_input_analysis_memory_v1';
const int _smartInputMemoryLimit = 25;
const String _pendingAiInputDirectoryName = 'pending_ai_inputs';

final ImagePicker _imagePicker = ImagePicker();

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

void homeSpendTrace(String message) {
  assert(() {
    foundation.debugPrint('🧾 [HomeSpendTrace] $message');
    return true;
  }());
}

String traceAiAmount(num value) => value.toStringAsFixed(2);

String _friendlyProgressMessage(AnalysisProgressEvent event) {
  const stageFallback = <String, String>{
    'started': 'Getting things ready...',
    'extracting_text': 'Reading the details...',
    'processing_vision': 'Looking through your receipt...',
    'analyzing_chunk': 'Reviewing transactions...',
    'complete': 'Finishing up...',
  };

  final stage = event.stage.trim().toLowerCase();
  final raw = event.message.trim();
  final lowered = raw.toLowerCase();

  final hasJargon = [
    'gemini',
    'model',
    'llm',
    'token',
    'json',
    'function call',
    'retry',
    'timeout',
    'api',
    'ocr',
  ].any(lowered.contains);

  String baseMessage;
  if (raw.isEmpty || hasJargon) {
    baseMessage = stageFallback[stage] ?? 'Working on it...';
  } else if (lowered.contains('extracting text')) {
    baseMessage = 'Reading the details...';
  } else if (lowered.contains('processing vision')) {
    baseMessage = 'Looking through your receipt...';
  } else {
    baseMessage = raw;
  }

  if (event.currentItem != null && event.totalItems != null) {
    return '$baseMessage (${event.currentItem}/${event.totalItems})';
  }
  return baseMessage;
}

class _AiParsedItem {
  final ParsedExpense transaction;
  final String optimisticId;
  final ExpenseEntry optimisticEntry;
  final Map<String, dynamic> raw;

  const _AiParsedItem({
    required this.transaction,
    required this.optimisticId,
    required this.optimisticEntry,
    required this.raw,
  });
}

class _AiPreparedMutation {
  final _AiParsedItem item;
  final TransactionMutationMetadata metadata;
  final String functionName;
  final Map<String, dynamic> individualRequestBody;
  final Map<String, dynamic> batchRequestBody;

  const _AiPreparedMutation({
    required this.item,
    required this.metadata,
    required this.functionName,
    required this.individualRequestBody,
    required this.batchRequestBody,
  });
}

class _AutoSplitContext {
  final Household household;
  final List<HouseholdMember> members;

  const _AutoSplitContext({
    required this.household,
    required this.members,
  });
}

class _ExplicitAmountSplitOverride {
  final double totalAmount;
  final List<Map<String, dynamic>> memberSplits;
  final String? descriptionHint;

  const _ExplicitAmountSplitOverride({
    required this.totalAmount,
    required this.memberSplits,
    this.descriptionHint,
  });
}

class AiLogSuccess {
  final int count;
  final String targetLabel;
  final List<ParsedExpense> items;

  const AiLogSuccess({
    required this.count,
    required this.targetLabel,
    required this.items,
  });
}

Map<String, dynamic>? _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
  return null;
}

String _smartInputMemoryKey({
  required String userId,
  required String? householdId,
  required String? currency,
  required String languageTag,
}) {
  final scope = [
    userId.trim(),
    householdId?.trim() ?? '',
    currency?.trim().toUpperCase() ?? '',
    languageTag.trim().toLowerCase(),
  ].join('|');
  final digest = sha256.convert(utf8.encode(scope)).toString();
  return '${_smartInputMemoryKeyPrefix}_$digest';
}

List<SmartInputAnalysisMemory> _readSmartInputMemories(
  SharedPreferences prefs,
  String key,
) {
  final encoded = prefs.getStringList(key) ?? const <String>[];
  final memories = <SmartInputAnalysisMemory>[];
  for (final item in encoded) {
    try {
      final decoded = jsonDecode(item);
      final memory = SmartInputAnalysisMemory.fromJson(decoded);
      if (memory != null) {
        memories.add(memory);
      }
    } catch (_) {}
  }
  return memories;
}

Map<String, dynamic>? _tryBuildSmartInputMemoryResponse({
  required SharedPreferences prefs,
  required String userId,
  required String? householdId,
  required String? currency,
  required String languageTag,
  required String inputText,
  required String defaultDateYmd,
}) {
  final key = _smartInputMemoryKey(
    userId: userId,
    householdId: householdId,
    currency: currency,
    languageTag: languageTag,
  );
  for (final memory in _readSmartInputMemories(prefs, key)) {
    final response = memory.tryBuildResponseFor(
      inputText: inputText,
      defaultDateYmd: defaultDateYmd,
    );
    if (response != null) {
      return response;
    }
  }
  return null;
}

Future<void> _rememberSmartInputAnalysis({
  required SharedPreferences prefs,
  required String userId,
  required String? householdId,
  required String? currency,
  required String languageTag,
  required String inputText,
  required String defaultDateYmd,
  required Map<String, dynamic> responseData,
}) async {
  final memory = SmartInputAnalysisMemory.fromAnalysisResponse(
    inputText: inputText,
    responseData: responseData,
    defaultDateYmd: defaultDateYmd,
  );
  if (memory == null) return;

  final key = _smartInputMemoryKey(
    userId: userId,
    householdId: householdId,
    currency: currency,
    languageTag: languageTag,
  );
  final previous = _readSmartInputMemories(prefs, key);
  final updated = <SmartInputAnalysisMemory>[
    memory,
    ...previous.where(
      (candidate) =>
          candidate.measurement.orderedSignature !=
              memory.measurement.orderedSignature ||
          candidate.measurement.unorderedSignature !=
              memory.measurement.unorderedSignature,
    ),
  ].take(_smartInputMemoryLimit).toList(growable: false);

  await prefs.setStringList(
    key,
    updated.map((entry) => jsonEncode(entry.toJson())).toList(growable: false),
  );
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .map(_asStringDynamicMap)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

Map<String, dynamic> _unwrapFunctionData(Object? responseData) {
  final payload = _asStringDynamicMap(responseData);
  if (payload == null) {
    throw Exception('Unexpected response shape from Edge Function');
  }
  return payload;
}

Map<String, dynamic>? _extractSavedEntryPayload(Object? responseData) {
  final payload = _asStringDynamicMap(responseData);
  if (payload == null) return null;

  final nested = _asStringDynamicMap(payload['data']);
  if (nested != null) return nested;

  if (payload.containsKey('id') && payload['id'] != null) {
    return payload;
  }

  return null;
}

double? _parseAmountValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

String? _resolveHouseholdIdForAi(WidgetRef ref) {
  final scope = ref.read(householdScopeProvider);
  return scope.activeAccountHouseholdId;
}

String _resolveLogTargetLabel(BuildContext context, WidgetRef ref) {
  final householdId = _resolveHouseholdIdForAi(ref);
  if (householdId == null) return context.l10n.personalScope;

  final selected = ref.read(selectedHouseholdProvider);
  return selected.household?.name ?? context.l10n.forUs;
}

String _resolveLogTargetLabelFromInputTarget(
  BuildContext context,
  WidgetRef ref, {
  required AiInputTarget? inputTarget,
}) {
  if (inputTarget == null) {
    return _resolveLogTargetLabel(context, ref);
  }

  final explicitLabel = inputTarget.spaceLabel?.trim();
  if (explicitLabel != null && explicitLabel.isNotEmpty) {
    return explicitLabel;
  }

  final householdId = inputTarget.householdId?.trim();
  if (householdId == null || householdId.isEmpty) {
    return context.l10n.personalScope;
  }

  final selected = ref.read(selectedHouseholdProvider);
  if (selected.household?.id == householdId) {
    final selectedName = selected.household?.name.trim();
    if (selectedName != null && selectedName.isNotEmpty) return selectedName;
  }

  final userId = ref.read(authProvider).uid.trim();
  if (userId.isNotEmpty) {
    final households = ref.read(userHouseholdsProvider(userId)).valueOrNull ??
        const <Household>[];
    for (final household in households) {
      if (household.id == householdId) {
        final name = household.name.trim();
        if (name.isNotEmpty) return name;
      }
    }
  }

  return context.l10n.forUs;
}

String _truncateForToast(String? value, {int maxLen = 28}) {
  final s = (value ?? '').trim();
  if (s.isEmpty) return '';
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen - 1)}…';
}

String _formatAiLoggedToastMessage(
  BuildContext context, {
  required List<_AiParsedItem> items,
  required String targetLabel,
}) {
  if (items.isEmpty) return context.l10n.failedToAnalyzeNoData;

  final target = targetLabel;
  final count = items.length;
  final allIncome = items.every((e) => e.transaction.isIncome);
  final allExpense = items.every((e) => !e.transaction.isIncome);

  if (count == 1) {
    final tx = items.first.transaction;
    final savedLabel =
        tx.isIncome ? context.l10n.incomeSaved : context.l10n.expenseSaved;
    final desc = _truncateForToast(tx.description);
    final detail = desc.isEmpty ? '' : ' • $desc';
    final normalizedCurrency = tx.currency.trim().toUpperCase();
    final canonicalCurrency = canonicalizeCurrencyCode(normalizedCurrency);
    final amountDisplay = canonicalCurrency == null
        ? (normalizedCurrency.isEmpty
            ? formatAmount(tx.amount)
            : '$normalizedCurrency ${formatAmount(tx.amount)}')
        : formatCurrency(tx.amount, canonicalCurrency, context: context);
    return '$savedLabel $amountDisplay$detail → $target';
  }

  if (allIncome) {
    return '${context.l10n.incomeSaved} ($count) → $target';
  }
  if (allExpense) {
    return '${context.l10n.expenseSaved} ($count) → $target';
  }
  return '${context.l10n.transactions} ($count) → $target';
}

List<Map<String, dynamic>> _buildHouseholdMemberContext(
  WidgetRef ref,
  String householdId,
) {
  final membersAsync = ref.read(householdMembersProvider(householdId));
  final members = membersAsync.valueOrNull;
  if (members == null || members.isEmpty) return const [];

  return members
      .map(
        (m) => {
          'userId': m.userId,
          if (m.userName != null && m.userName!.trim().isNotEmpty)
            'userName': m.userName,
          if (m.userEmail != null && m.userEmail!.trim().isNotEmpty)
            'userEmail': m.userEmail,
        },
      )
      .toList(growable: false);
}

Household? _resolveHouseholdForAutoSplit(
  ProviderContainer container,
  String householdId,
) {
  final providerHousehold =
      container.read(householdProvider(householdId)).valueOrNull;
  if (providerHousehold?.id == householdId) return providerHousehold;

  final userId = container.read(authProvider).uid;
  if (userId.isNotEmpty) {
    final households =
        container.read(userHouseholdsProvider(userId)).valueOrNull ??
            const <Household>[];
    for (final household in households) {
      if (household.id == householdId) return household;
    }
  }

  return null;
}

bool _hasExplicitCustomSplits(Object? rawCustomSplits) {
  return _normalizeExplicitCustomSplits(rawCustomSplits) != null;
}

Map<String, dynamic>? _normalizeExplicitCustomSplits(Object? rawCustomSplits) {
  if (rawCustomSplits is! Map) return null;
  final customSplits = Map<String, dynamic>.from(rawCustomSplits);
  final splitType = customSplits['splitType']?.toString().trim().toLowerCase();
  if (splitType == null || splitType.isEmpty || splitType == 'equal') {
    return null;
  }
  final splitValueKey = switch (splitType) {
    'amount' => 'amount',
    'percentage' => 'percentage',
    'shares' => 'shares',
    _ => null,
  };
  if (splitValueKey == null) return null;

  final memberSplits = customSplits['memberSplits'];
  if (memberSplits is! List || memberSplits.isEmpty) return null;
  final hasValues = memberSplits.any((entry) =>
      entry is Map &&
      entry[splitValueKey] is num &&
      (entry['userId']?.toString().trim().isNotEmpty ?? false));
  if (!hasValues) return null;

  return customSplits;
}

String _resolveOptimisticAiCategory({
  required Object? rawCategory,
  required Object? rawDescription,
  required bool isIncome,
}) {
  final fallback = isIncome ? 'income' : 'other';
  final category = rawCategory?.toString().trim() ?? '';
  final normalizedCategory = normalizeCategory(category);
  final builtinCategory = resolveBuiltinCategoryKeyAcrossLocales(
    normalizedCategory,
  );
  if (builtinCategory != null &&
      builtinCategory != 'other' &&
      builtinCategory != 'uncategorized') {
    return builtinCategory;
  }

  final description = rawDescription?.toString().trim() ?? '';
  final normalizedDescription = normalizeCategory(description);
  final descriptionCategory = resolveBuiltinCategoryKeyAcrossLocales(
    normalizedDescription,
  );
  if (descriptionCategory != null &&
      descriptionCategory != 'other' &&
      descriptionCategory != 'uncategorized') {
    return descriptionCategory;
  }

  return builtinCategory ?? fallback;
}

Future<Map<String, String>> _loadLocalCategoryRemaps(
  ProviderContainer container, {
  required String userId,
  required String transactionType,
}) async {
  if (userId.trim().isEmpty) return const <String, String>{};
  try {
    final database = await container.read(localDatabaseProvider.future);
    return database.getCategoryRemaps(
      userId: userId,
      transactionType: transactionType,
    );
  } catch (error) {
    _debugPrint('⚠️ Local category remaps unavailable: $error');
    return const <String, String>{};
  }
}

String _applyLocalCategoryRemap({
  required String category,
  required Map<String, String> remaps,
}) {
  if (remaps.isEmpty) return category;
  final direct = category.trim().toLowerCase();
  final normalized = normalizeCategory(category);
  return remaps[direct] ?? remaps[normalized] ?? category;
}

String _normalizeMemberAlias(String value) {
  final lowered = value.toLowerCase().trim();
  if (lowered.isEmpty) return '';
  return lowered
      .replaceAll(RegExp(r'@[^ ]+$'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _resolveMentionedMemberId({
  required String rawMention,
  required List<Map<String, dynamic>> householdMembers,
  required String callerUserId,
}) {
  final mention = _normalizeMemberAlias(rawMention);
  if (mention.isEmpty) return null;

  const callerAliases = {'me', 'myself', 'i', 'my', 'mine'};
  if (callerAliases.contains(mention)) return callerUserId;

  final exact = <String>{};
  final fuzzy = <String>{};

  for (final member in householdMembers) {
    final userId = member['userId']?.toString().trim() ?? '';
    if (userId.isEmpty) continue;

    final rawName = member['userName']?.toString() ?? '';
    final rawEmail = member['userEmail']?.toString() ?? '';
    final normalizedName = _normalizeMemberAlias(rawName);
    final normalizedEmail = _normalizeMemberAlias(rawEmail);
    final emailLocal = normalizedEmail.split(' ').first;
    final nameParts =
        normalizedName.isEmpty ? const <String>[] : normalizedName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.last : '';

    final aliases = <String>{
      normalizedName,
      firstName,
      lastName,
      emailLocal,
      normalizedEmail,
    }.where((s) => s.isNotEmpty).toSet();

    if (aliases.contains(mention)) {
      exact.add(userId);
      continue;
    }
    if (aliases
        .any((alias) => alias.contains(mention) || mention.contains(alias))) {
      fuzzy.add(userId);
    }
  }

  if (exact.length == 1) return exact.first;
  if (exact.isNotEmpty) return null;
  if (fuzzy.length == 1) return fuzzy.first;
  return null;
}

double? _parseLooseAmount(String raw) {
  final cents = tryParseMoneyToCents(raw);
  return cents != null ? centsToAmount(cents) : null;
}

String? _extractDescriptionHintFromTotalClause(String clause) {
  final match = RegExp(
    r'(\d+(?:\.\d{1,2})?)\s*(?:for|on)\s+(.+)',
    caseSensitive: false,
  ).firstMatch(clause);
  if (match == null) return null;
  final raw = (match.group(2) ?? '').trim();
  if (raw.isEmpty) return null;
  final stripped = raw
      .replaceAll(RegExp(r'[^a-z0-9 ]', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return stripped.isEmpty ? null : stripped;
}

bool _itemsContainExplicitCustomSplits(List<dynamic> items) {
  for (final item in items) {
    if (item is! Map) continue;
    if (_hasExplicitCustomSplits(item['customSplits'])) return true;
  }
  return false;
}

List<String> _expandAmountSplitClauses(String text) {
  final baseClauses = text
      .split(RegExp(r'[;,]'))
      .expand((chunk) => chunk.split(RegExp(r'\band\b', caseSensitive: false)))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  final repeatedAmountPattern = RegExp(
    r'(?:\bsplit\s+)?(\d+(?:\.\d{1,2})?)\s*(?:for|to|with)\s+(.+?)(?=\s+(?:\bsplit\s+)?\d+(?:\.\d{1,2})?\s*(?:for|to|with)\b|$)',
    caseSensitive: false,
  );

  return baseClauses.expand((clause) {
    final matches = repeatedAmountPattern.allMatches(clause).toList();
    if (matches.length <= 1) return <String>[clause];
    return matches
        .map((match) => match.group(0)?.trim() ?? '')
        .where((match) => match.isNotEmpty);
  }).toList(growable: false);
}

_ExplicitAmountSplitOverride? _extractExplicitAmountSplitOverride({
  required String text,
  required List<Map<String, dynamic>> householdMembers,
  required String callerUserId,
}) {
  if (text.trim().isEmpty || householdMembers.isEmpty) return null;

  final clauses = _expandAmountSplitClauses(text);

  if (clauses.isEmpty) return null;

  final memberAmounts = <String, double>{};
  double? totalHint;
  String? descriptionHint;

  final memberSplitPatterns = <RegExp>[
    RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:for|to)\s+(.+)', caseSensitive: false),
    RegExp(r'(?:split\s+)?(\d+(?:\.\d{1,2})?)\s*(?:with)\s+(.+)',
        caseSensitive: false),
  ];

  for (final clause in clauses) {
    for (final pattern in memberSplitPatterns) {
      final match = pattern.firstMatch(clause);
      if (match == null) continue;

      final amount = _parseLooseAmount(match.group(1) ?? '');
      if (amount == null || amount <= 0) break;

      final rawMention = (match.group(2) ?? '').trim();
      final mentionTokens = rawMention
          .replaceAll(RegExp(r'[^a-zA-Z0-9@._ ]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList(growable: false);
      if (mentionTokens.isEmpty) break;

      String? resolvedUserId;
      for (var len = min(3, mentionTokens.length); len >= 1; len--) {
        final probe = mentionTokens.take(len).join(' ');
        resolvedUserId = _resolveMentionedMemberId(
          rawMention: probe,
          householdMembers: householdMembers,
          callerUserId: callerUserId,
        );
        if (resolvedUserId != null) break;
      }

      if (resolvedUserId != null) {
        memberAmounts.update(
          resolvedUserId,
          (existing) => existing + amount,
          ifAbsent: () => amount,
        );
      } else {
        totalHint ??= amount;
        descriptionHint ??= _extractDescriptionHintFromTotalClause(clause);
      }
      break;
    }
  }

  if (memberAmounts.isEmpty) return null;

  final allMemberIds = householdMembers
      .map((m) => m['userId']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (allMemberIds.isEmpty) return null;

  final sumSpecified = memberAmounts.values.fold<double>(0, (a, b) => a + b);
  var totalAmount = totalHint ?? sumSpecified;
  if (totalAmount < sumSpecified) totalAmount = sumSpecified;

  var totalCents = (totalAmount * 100).round();
  final specifiedCents = <String, int>{
    for (final entry in memberAmounts.entries)
      entry.key: (entry.value * 100).round(),
  };
  var specifiedSumCents = specifiedCents.values.fold<int>(0, (a, b) => a + b);

  if (specifiedSumCents > totalCents) {
    totalCents = specifiedSumCents;
    totalAmount = totalCents / 100.0;
  }

  final missingIds =
      allMemberIds.where((id) => !specifiedCents.containsKey(id)).toList();
  var remainderCents = totalCents - specifiedSumCents;
  if (totalHint != null &&
      remainderCents > 0 &&
      missingIds.contains(callerUserId)) {
    specifiedCents[callerUserId] = remainderCents;
    specifiedSumCents = specifiedCents.values.fold<int>(0, (a, b) => a + b);
    remainderCents = totalCents - specifiedSumCents;
  } else if (missingIds.isNotEmpty && remainderCents > 0) {
    final per = remainderCents ~/ missingIds.length;
    var extra = remainderCents % missingIds.length;
    for (final id in missingIds) {
      specifiedCents[id] = per + (extra > 0 ? 1 : 0);
      if (extra > 0) extra -= 1;
    }
    specifiedSumCents = specifiedCents.values.fold<int>(0, (a, b) => a + b);
    remainderCents = totalCents - specifiedSumCents;
  }

  if (remainderCents != 0 && allMemberIds.isNotEmpty) {
    final tailId = allMemberIds.last;
    specifiedCents[tailId] = (specifiedCents[tailId] ?? 0) + remainderCents;
  }

  final memberSplits = allMemberIds
      .map((id) => <String, dynamic>{
            'userId': id,
            'amount': ((specifiedCents[id] ?? 0) / 100.0),
          })
      .toList(growable: false);

  return _ExplicitAmountSplitOverride(
    totalAmount: totalAmount,
    memberSplits: memberSplits,
    descriptionHint: descriptionHint,
  );
}

List<dynamic> _applyExplicitSplitOverrideToItems({
  required List<dynamic> items,
  required String? text,
  required String callerUserId,
  required List<Map<String, dynamic>> householdMembers,
}) {
  if (items.isEmpty || text == null || text.trim().isEmpty) return items;
  if (householdMembers.isEmpty) return items;

  final override = _extractExplicitAmountSplitOverride(
    text: text,
    householdMembers: householdMembers,
    callerUserId: callerUserId,
  );
  if (override == null) return items;

  final shouldOverride =
      items.length > 1 || !_itemsContainExplicitCustomSplits(items);
  if (!shouldOverride) return items;

  final baseItem = items.firstWhere(
    (item) => item is Map,
    orElse: () => <String, dynamic>{},
  );
  final normalizedBase = baseItem is Map
      ? Map<String, dynamic>.from(baseItem)
      : <String, dynamic>{};

  normalizedBase['amount'] = override.totalAmount;
  normalizedBase['customSplits'] = <String, dynamic>{
    'splitType': 'amount',
    'memberSplits': override.memberSplits,
  };
  final existingDescription = normalizedBase['description']?.toString().trim();
  if ((override.descriptionHint ?? '').isNotEmpty &&
      ((existingDescription == null || existingDescription.isEmpty) ||
          items.length > 1)) {
    normalizedBase['description'] = override.descriptionHint;
  }

  _debugPrint(
    '[AI] Applied explicit split override from text. '
    'members=${override.memberSplits.length} total=${override.totalAmount}',
  );
  return <dynamic>[normalizedBase];
}

Future<_AutoSplitContext?> _loadAutoSplitContext(
  ProviderContainer container, {
  required String householdId,
}) {
  final selectedHousehold =
      _resolveHouseholdForAutoSplit(container, householdId);

  Future<Household?> resolveHousehold() async {
    try {
      final fresh =
          await container.read(householdRepositoryProvider).getHousehold(
                householdId,
              );
      if (fresh != null) {
        if (selectedHousehold != null &&
            selectedHousehold.updatedAt.isAfter(fresh.updatedAt)) {
          return selectedHousehold;
        }
        return fresh;
      }
    } catch (error) {
      _debugPrint('⚠️ Failed to load fresh household split settings: $error');
    }
    if (selectedHousehold != null) return selectedHousehold;
    return await container.read(householdProvider(householdId).future);
  }

  Future<List<HouseholdMember>> resolveMembers() async {
    final cached =
        container.read(householdMembersProvider(householdId)).valueOrNull;
    if (cached != null) return cached;
    return await container
        .read(householdRepositoryProvider)
        .getHouseholdMembers(householdId);
  }

  return Future.wait<Object?>([
    resolveHousehold(),
    resolveMembers(),
  ]).then((results) {
    final household = results[0] as Household?;
    final members = results[1] as List<HouseholdMember>?;
    if (household == null || members == null || members.isEmpty) return null;
    return _AutoSplitContext(household: household, members: members);
  }).catchError((_) => null);
}

Map<String, dynamic>? _resolveAutoSplitCustomSplitsPayload(
  _AutoSplitContext? context, {
  required double totalAmount,
}) {
  final household = context?.household;
  if (household == null || !household.autoSplitEnabled) return null;

  final config = household.autoSplitConfig;
  if (config == null || config.isEmpty) return null;

  final members = context?.members;
  if (members == null || members.isEmpty) return null;

  final splitType = resolveStoredSplitType(config);
  if (splitType.name == 'equal') return null;

  final templateSplits = deserializeStoredSplitConfig(
    members: members,
    totalAmount: totalAmount,
    config: config,
  );
  final splits = resolveStoredSplitsForTransaction(
    splitType: splitType,
    splits: templateSplits,
    config: config,
    totalAmount: totalAmount,
  );
  return buildCustomSplitsPayload(splitType: splitType, splits: splits);
}

Future<void> _maybeRequestReviewAfterExpenseSave({
  required String userId,
  required SharedPreferences prefs,
  required int additionalExpenseCount,
}) async {
  try {
    if (userId.isEmpty || additionalExpenseCount <= 0) return;
    final userKey = sha256.convert(utf8.encode(userId)).toString();
    final countKey = '${_reviewExpenseCountKey}_$userKey';
    final lastPromptKey = '${_reviewLastPromptKey}_$userKey';
    final lastIntervalKey = '${_reviewLastIntervalKey}_$userKey';

    final updatedCount = (prefs.getInt(countKey) ?? 0) + additionalExpenseCount;
    await prefs.setInt(countKey, updatedCount);

    final lastPromptCount = prefs.getInt(lastPromptKey) ?? 0;
    final lastInterval = prefs.getInt(lastIntervalKey) ?? 0;
    final nextInterval = () {
      if (lastInterval <= 0) return _reviewSecondInterval;
      if (lastInterval == _reviewSecondInterval) return _reviewThirdInterval;
      return _reviewMaxInterval;
    }();

    final shouldPrompt = updatedCount == _reviewFirstPromptAt ||
        (updatedCount - lastPromptCount) >= nextInterval;
    if (!shouldPrompt) return;

    await prefs.setInt(lastPromptKey, updatedCount);
    await prefs.setInt(lastIntervalKey, nextInterval);

    final inAppReview = InAppReview.instance;
    final available = await inAppReview.isAvailable();
    if (!available) return;

    await inAppReview.requestReview();
  } catch (error) {
    _debugPrint('[REVIEW] Failed to request review: $error');
  }
}

Future<void> _persistAiTransactions(
  ProviderContainer container, {
  required String userId,
  required String? householdId,
  required bool isPortfolio,
  required List<_AiParsedItem> transactions,
  required String? accountId,
  String? accountCurrency,
  String? localImagePath,
}) async {
  if (transactions.isEmpty) return;

  final clientCreatedAtIso = DateTime.now().toUtc().toIso8601String();
  final batchTraceBase = sha256
      .convert(utf8.encode([
        userId,
        householdId ?? '',
        clientCreatedAtIso,
        ...transactions.map((item) => item.optimisticId),
      ].join('|')))
      .toString();
  MonekoDatabase? localDatabase;
  var queuedLocally = false;
  _AutoSplitContext? autoSplitContext;
  final fallbackAccountId = accountId?.trim();
  String? resolveAccountIdForCurrency(String currency) {
    final normalizedCurrency = currency.trim().toUpperCase();
    if (fallbackAccountId != null &&
        accountCurrency != null &&
        normalizedCurrency == accountCurrency.trim().toUpperCase()) {
      return fallbackAccountId;
    }
    return null;
  }

  Future<void> cacheSavedEntriesAndRefresh(
    List<ExpenseEntry> savedEntries,
  ) async {
    final cacheable = savedEntries
        .where((entry) => entry.userId?.trim().isNotEmpty == true)
        .toList(growable: false);
    if (cacheable.isEmpty) return;

    try {
      final MonekoDatabase database =
          localDatabase ?? await container.read(localDatabaseProvider.future);
      localDatabase = database;
      await database.upsertTransactions(
        cacheable,
        syncStatus: localSyncStatusSynced,
      );
    } catch (error) {
      _debugPrint('⚠️ Failed to cache AI saved transactions locally: $error');
    }

    final savedHousehold = householdId ?? '<personal>';
    homeSpendTrace(
      'ai-saved-cache count=${cacheable.length} household=$savedHousehold '
      'total=${traceAiAmount(cacheable.fold<double>(0, (sum, entry) => sum + (((entry.type ?? 'expense').toLowerCase() == 'income') ? 0 : entry.amount.abs())))}',
    );
    container.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    container.read(dashboardRefreshSignalProvider.notifier).state += 1;
    container
        .read(dashboardCurrencySummariesRefreshSignalProvider.notifier)
        .state += 1;
  }

  Future<void> replaceLocalOptimisticTransaction({
    required String optimisticId,
    required ExpenseEntry savedEntry,
    required TransactionMutationMetadata metadata,
  }) async {
    try {
      await localDatabase?.replaceOptimisticTransaction(
        optimisticId: optimisticId,
        savedEntry: savedEntry,
        clientMutationId: metadata.clientMutationId,
      );
    } catch (error) {
      _debugPrint(
        '⚠️ Failed to replace local AI optimistic transaction: $error',
      );
    }
  }

  String? normalizeBucketId(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  bool resolveIsRecurring(Map<String, dynamic> raw) {
    final dynamicValue = raw['is_recurring'] ?? raw['isRecurring'];
    if (dynamicValue is bool) return dynamicValue;
    if (dynamicValue is num) return dynamicValue != 0;
    if (dynamicValue is String) {
      final normalized = dynamicValue.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  Map<String, dynamic>? normalizeRecurrenceRule(
    Map<String, dynamic> raw,
    String fallbackAnchorDate,
  ) {
    String? normalizeCalendarDateString(dynamic value) {
      final parsed = parseCalendarDateFromFlexibleInput(value?.toString());
      return parsed == null ? null : formatDateOnlyYmd(parsed);
    }

    final sourceRule = raw['recurrence_rule'] ?? raw['recurrenceRule'];
    final sourceMap = sourceRule is Map
        ? Map<String, dynamic>.from(sourceRule)
        : <String, dynamic>{};

    final rawFrequency = sourceMap['frequency'] ?? raw['frequency'];
    final frequency =
        rawFrequency is String ? rawFrequency.trim().toLowerCase() : '';
    const allowedFrequencies = <String>{
      'daily',
      'weekly',
      'biweekly',
      'monthly',
      'yearly',
      'custom',
    };
    if (!allowedFrequencies.contains(frequency)) {
      return null;
    }

    final rawAnchorDate = sourceMap['anchor_date'] ?? sourceMap['anchorDate'];
    final anchorDate =
        normalizeCalendarDateString(rawAnchorDate) ?? fallbackAnchorDate;

    final normalizedRule = <String, dynamic>{
      'frequency': frequency,
      'anchor_date': anchorDate,
    };

    final rawEndDate = sourceMap['end_date'] ?? sourceMap['endDate'];
    final normalizedEndDate = normalizeCalendarDateString(rawEndDate);
    if (normalizedEndDate != null) {
      normalizedRule['end_date'] = normalizedEndDate;
    }

    final rawInterval = sourceMap['interval'];
    if (rawInterval is num && rawInterval > 0) {
      normalizedRule['interval'] = rawInterval.toInt();
    }

    final rawReminder = sourceMap['reminder'];
    if (rawReminder is Map) {
      final reminder = Map<String, dynamic>.from(rawReminder);
      final rawEnabled = reminder['enabled'];
      final rawValue = reminder['value'];
      final rawUnit = reminder['unit'];
      if (rawEnabled is bool &&
          rawValue is num &&
          rawValue > 0 &&
          rawUnit is String) {
        final unit = rawUnit.trim().toLowerCase();
        if (unit == 'days' || unit == 'hours') {
          normalizedRule['reminder'] = <String, dynamic>{
            'enabled': rawEnabled,
            'value': rawValue,
            'unit': unit,
          };
        }
      }
    }

    return normalizedRule;
  }

  Future<ExpenseEntry> upsertSavedEntry({
    required _AiPreparedMutation prepared,
    required ExpenseEntry savedEntry,
  }) async {
    final optimisticId = prepared.item.optimisticId;
    var entryToStore = savedEntry.copyWith(
      clientRecordId: prepared.metadata.clientRecordId,
      clientMutationId: prepared.metadata.clientMutationId,
      idempotencyKey: prepared.metadata.idempotencyKey,
    );
    final savedHouseholdId = savedEntry.householdId?.trim();
    if (savedHouseholdId != null &&
        savedHouseholdId.isNotEmpty &&
        !prepared.item.transaction.isIncome) {
      final existingSplitGroupId = savedEntry.splitGroupId?.trim();
      final optimisticSplitGroup = buildOptimisticHouseholdSplitGroup(
        householdId: savedHouseholdId,
        expenseId: savedEntry.id,
        payerUserId: (prepared.batchRequestBody['payerUserId'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true
            ? (prepared.batchRequestBody['payerUserId'] as String).trim()
            : userId,
        totalAmount: savedEntry.amount,
        currency: savedEntry.currency ?? prepared.item.transaction.currency,
        members: autoSplitContext?.members ?? const <HouseholdMember>[],
        autoSplitEnabled: autoSplitContext?.household.autoSplitEnabled ?? false,
        autoSplitConfig: autoSplitContext?.household.autoSplitConfig,
        rawCustomSplits: prepared.batchRequestBody['customSplits'],
        description:
            savedEntry.rawText ?? prepared.item.transaction.description,
        splitGroupId: existingSplitGroupId?.isNotEmpty == true
            ? existingSplitGroupId
            : null,
      );
      if (optimisticSplitGroup != null) {
        container
            .read(householdOptimisticSplitsProvider.notifier)
            .addSplitGroup(savedHouseholdId, optimisticSplitGroup);
        if (existingSplitGroupId == null || existingSplitGroupId.isEmpty) {
          entryToStore =
              entryToStore.copyWith(splitGroupId: optimisticSplitGroup.id);
        }
      } else {
        final optimisticSplitsNotifier =
            container.read(householdOptimisticSplitsProvider.notifier);
        optimisticSplitsNotifier.removeSplitByExpenseIdAcrossHouseholds(
          optimisticId,
        );
        if (savedEntry.id.isNotEmpty) {
          optimisticSplitsNotifier.removeSplitByExpenseIdAcrossHouseholds(
            savedEntry.id,
          );
        }
      }
    }
    if (savedEntry.id.isNotEmpty) {
      container
          .read(householdOptimisticExpensesProvider.notifier)
          .removeExpenseByIdAcrossHouseholds(savedEntry.id);
    }
    final fromBucket = normalizeBucketId(householdId);
    final toBucket = normalizeBucketId(entryToStore.householdId);

    if (fromBucket == toBucket) {
      await replaceLocalOptimisticTransaction(
        optimisticId: optimisticId,
        savedEntry: entryToStore,
        metadata: prepared.metadata,
      );
      replaceOptimisticTransactionWithContainer(
        container: container,
        optimisticId: optimisticId,
        savedEntry: entryToStore,
        householdId: fromBucket,
      );
      return entryToStore;
    }

    await replaceLocalOptimisticTransaction(
      optimisticId: optimisticId,
      savedEntry: entryToStore,
      metadata: prepared.metadata,
    );
    removeOptimisticTransactionWithContainer(
      container: container,
      optimisticId: optimisticId,
      householdId: fromBucket,
    );
    addOptimisticTransactionWithContainer(
      container: container,
      entry: entryToStore,
      householdId: toBucket,
    );
    return entryToStore;
  }

  Future<Map<String, ExpenseEntry>> attachOptimisticSplitsForSavedExpenses(
    Map<String, ExpenseEntry> savedExpensesById,
  ) async {
    if (savedExpensesById.isEmpty) return const <String, ExpenseEntry>{};
    final targetHouseholdId = householdId?.trim();
    if (targetHouseholdId == null || targetHouseholdId.isEmpty) {
      return const <String, ExpenseEntry>{};
    }
    if (isPortfolio) return const <String, ExpenseEntry>{};

    try {
      final repository = container.read(householdRepositoryProvider);
      const maxAttempts = 5;
      const delay = Duration(milliseconds: 250);

      List<ExpenseSplitGroup> splits = const <ExpenseSplitGroup>[];
      Map<String, ExpenseSplitGroup> splitsByExpenseId =
          const <String, ExpenseSplitGroup>{};

      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        splits = await repository.getHouseholdSplits(
          householdId: targetHouseholdId,
        );

        splitsByExpenseId = {
          for (final group in splits) group.expenseId: group,
        };

        final missing = savedExpensesById.keys
            .where((id) => !splitsByExpenseId.containsKey(id))
            .toList(growable: false);

        if (missing.isEmpty || attempt == maxAttempts) break;
        await Future.delayed(delay);
      }

      if (splitsByExpenseId.isEmpty) return const <String, ExpenseEntry>{};
      await cacheHouseholdSplitsSnapshot(
        params: HouseholdSplitsParams(householdId: targetHouseholdId),
        splits: splits,
      );

      final splitsNotifier =
          container.read(householdOptimisticSplitsProvider.notifier);
      final expensesNotifier =
          container.read(householdOptimisticExpensesProvider.notifier);
      final updatedEntries = <String, ExpenseEntry>{};

      for (final entry in savedExpensesById.values) {
        final group = splitsByExpenseId[entry.id];
        if (group == null) continue;
        splitsNotifier.addSplitGroup(targetHouseholdId, group);

        final splitGroupId = entry.splitGroupId?.trim();
        if (splitGroupId != group.id) {
          final updated = entry.copyWith(splitGroupId: group.id);
          updatedEntries[updated.id] = updated;
          expensesNotifier.replaceExpense(targetHouseholdId, entry.id, updated);
        }
      }

      if (updatedEntries.isNotEmpty) {
        try {
          final MonekoDatabase database = localDatabase ??
              await container.read(localDatabaseProvider.future);
          localDatabase = database;
          await database.upsertTransactions(
            updatedEntries.values.toList(growable: false),
            syncStatus: localSyncStatusSynced,
            preserveLocalPending: false,
          );
        } catch (error) {
          _debugPrint(
            '⚠️ Failed to persist AI split group ids locally: $error',
          );
        }
      }

      return updatedEntries;
    } catch (error) {
      _debugPrint('❌ [AI Batch Save] Failed to attach split groups: $error');
    }
    return const <String, ExpenseEntry>{};
  }

  // Upload receipt image first (if any) - shared across all transactions
  String? receiptUrl;
  final hasReceiptExpense = localImagePath != null &&
      localImagePath.isNotEmpty &&
      transactions.any((item) => !item.transaction.isIncome);
  Object? receiptUploadError;
  if (localImagePath != null && localImagePath.isNotEmpty) {
    try {
      receiptUrl = await _uploadReceiptImageForAiQueue(
        File(localImagePath),
        userId,
      );
    } catch (error) {
      receiptUploadError = error;
      _debugPrint(
        '⚠️ Receipt upload failed before AI transaction queueing; continuing without receipt image: $error',
      );
    }
  }
  var shouldDeferForReceiptUpload = hasReceiptExpense &&
      receiptUrl == null &&
      receiptUploadError != null &&
      _shouldKeepQueuedLocalMutation(receiptUploadError);
  String? durableReceiptImagePath;
  if (shouldDeferForReceiptUpload) {
    try {
      durableReceiptImagePath = await _copyPendingAiInputFile(
        source: File(localImagePath),
        prefix: 'receipt',
        fallbackExtension: 'jpg',
      );
    } catch (error) {
      shouldDeferForReceiptUpload = false;
      _debugPrint(
        '⚠️ Failed to keep receipt image for retry; saving without receipt: $error',
      );
    }
  }

  autoSplitContext =
      householdId != null && householdId.isNotEmpty && !isPortfolio
          ? await _loadAutoSplitContext(
              container,
              householdId: householdId,
            )
          : null;

  // Build both the batch payload and individual outbox payloads. The outbox
  // makes AI saves survive weak/offline network and app restarts.
  final preparedMutations = transactions.map((item) {
    final tx = item.transaction;
    final isIncome = tx.isIncome;
    final isRecurring = resolveIsRecurring(item.raw);
    final mutationMetadata = buildTransactionMutationMetadata(
      item.optimisticId,
    );
    final recurrenceRule = normalizeRecurrenceRule(
      item.raw,
      formatDateOnlyYmd(tx.date),
    );

    // Extract payer and splits for household transactions.
    final rawPayerUserId = item.raw['payerUserId'];
    final payerUserId =
        rawPayerUserId is String && rawPayerUserId.trim().isNotEmpty
            ? rawPayerUserId.trim()
            : null;

    final hasExplicitCustomSplits = _hasExplicitCustomSplits(
      item.raw['customSplits'],
    );
    final autoSplitEnabled =
        autoSplitContext?.household.autoSplitEnabled != false;
    final explicitCustomSplits = _normalizeExplicitCustomSplits(
      item.raw['customSplits'],
    );
    final defaultCustomSplits = householdId != null &&
            householdId.isNotEmpty &&
            !isPortfolio &&
            autoSplitEnabled &&
            !hasExplicitCustomSplits
        ? _resolveAutoSplitCustomSplitsPayload(
            autoSplitContext,
            totalAmount: tx.amount,
          )
        : null;
    final effectiveCustomSplits = explicitCustomSplits ?? defaultCustomSplits;
    _debugPrint(
      '[AI Batch Save] Auto-split payload decision: household=$householdId '
      'enabled=$autoSplitEnabled explicit=$hasExplicitCustomSplits '
      'sendPayer=${(autoSplitEnabled || explicitCustomSplits != null) && payerUserId != null} '
      'sendSplits=${effectiveCustomSplits != null} type=${tx.isIncome ? 'income' : 'expense'} '
      'rawCustomSplits=${jsonEncode(item.raw['customSplits'])} '
      'effectiveCustomSplits=${jsonEncode(effectiveCustomSplits)}',
    );

    final resolvedAccountIdForTransaction = resolveAccountIdForCurrency(
      tx.currency,
    );

    final commonRequestBody = <String, dynamic>{
      'amount': tx.amount,
      'category': tx.category,
      'currency': tx.currency,
      'date': formatDateOnlyYmd(tx.date),
      if (resolvedAccountIdForTransaction != null &&
          resolvedAccountIdForTransaction.isNotEmpty)
        'accountId': resolvedAccountIdForTransaction,
      'clientCreatedAt': clientCreatedAtIso,
      ...mutationMetadata.toRequestJson(),
      if (isRecurring) 'isRecurring': true,
      if (isRecurring && recurrenceRule != null)
        'recurrence_rule': recurrenceRule,
      if (tx.description?.isNotEmpty == true) 'description': tx.description,
      if (tx.breakdown?.isNotEmpty == true) 'breakdown': tx.breakdown,
      if (receiptUrl != null && !isIncome) 'receiptImageUrl': receiptUrl,
      if ((autoSplitEnabled || explicitCustomSplits != null) &&
          payerUserId != null)
        'payerUserId': payerUserId,
      if (effectiveCustomSplits != null) 'customSplits': effectiveCustomSplits,
      // Income ownerType/privacyScope use backend defaults.
    };

    return _AiPreparedMutation(
      item: item,
      metadata: mutationMetadata,
      functionName: isIncome ? 'save-income' : 'save-expense',
      individualRequestBody: <String, dynamic>{
        'userId': userId,
        ...commonRequestBody,
        if (householdId != null && householdId.isNotEmpty)
          'householdId': householdId,
        if (householdId != null && householdId.isNotEmpty)
          'isPortfolio': isPortfolio,
      },
      batchRequestBody: <String, dynamic>{
        'type': isIncome ? 'income' : 'expense',
        ...commonRequestBody,
      },
    );
  }).toList(growable: false);

  final batchTransactions = preparedMutations
      .map((prepared) => prepared.batchRequestBody)
      .toList(growable: false);

  try {
    final database = await container.read(localDatabaseProvider.future);
    localDatabase = database;
    for (final prepared in preparedMutations) {
      await database.writeOptimisticTransaction(
        entry: prepared.item.optimisticEntry,
        clientMutationId: prepared.metadata.clientMutationId,
        operation: 'create',
        payload: {
          ...prepared.metadata.toRequestJson(),
          'transaction': prepared.item.optimisticEntry.toJson(),
          'functionName': prepared.functionName,
          'requestBody': prepared.individualRequestBody,
          if (shouldDeferForReceiptUpload &&
              !prepared.item.transaction.isIncome)
            'localReceiptImagePath': durableReceiptImagePath,
        },
      );
    }
    queuedLocally = true;
    final queuedHousehold = householdId ?? '<personal>';
    homeSpendTrace(
      'ai-local-queued count=${preparedMutations.length} '
      'household=$queuedHousehold '
      'total=${traceAiAmount(preparedMutations.fold<double>(0, (sum, item) => sum + (item.item.transaction.isIncome ? 0 : item.item.transaction.amount.abs())))}',
    );
    container.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
    container.read(dashboardRefreshSignalProvider.notifier).state += 1;
  } catch (error) {
    _debugPrint('⚠️ Failed to queue AI transactions locally: $error');
  }

  if (shouldDeferForReceiptUpload && queuedLocally) {
    _debugPrint(
      '📦 Keeping queued AI transaction(s) for receipt upload retry',
    );
    scheduleMobileOutboxDrain(
      container,
      maxMutations: max(20, preparedMutations.length),
    );
    return;
  }

  try {
    _debugPrint(
        '[AI Batch Save] Saving ${batchTransactions.length} transactions in single request');
    _debugPrint('[AI Batch Save] Function: save-transactions-batch');

    final batches = chunkList(batchTransactions, _maxBatchSize);
    var batchOffset = 0;

    var didPersistAny = false;
    var savedExpenseCount = 0;
    final savedEntries = <ExpenseEntry>[];
    final savedExpenseEntriesById = <String, ExpenseEntry>{};

    for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      _debugPrint(
          '[AI Batch Save] Batch ${batchIndex + 1}/${batches.length} size=${batch.length}');

      final response = await supabase.functions.invoke(
        'save-transactions-batch',
        body: {
          'userId': userId,
          'debugTraceId': 'mobile-ai-$batchTraceBase-$batchOffset',
          if (householdId != null && householdId.isNotEmpty)
            'householdId': householdId,
          if (householdId != null && householdId.isNotEmpty)
            'isPortfolio': isPortfolio,
          'transactions': batch,
        },
      );

      if (response.data == null) {
        throw Exception('No response from save-transactions-batch');
      }

      final responseData = _unwrapFunctionData(response.data);
      final results = _asMapList(responseData['results']);
      final summary = _asStringDynamicMap(responseData['summary']);
      final backendSucceeded = responseData['success'] == true;
      final hasStructuredResults = results.isNotEmpty;

      if (!backendSucceeded && !hasStructuredResults) {
        final backendError = responseData['error']?.toString();
        throw Exception(backendError ?? 'Batch save failed');
      }

      _debugPrint(
          '[AI Batch Save] Result: ${summary?['succeeded'] ?? 0} succeeded, ${summary?['failed'] ?? 0} failed');

      if (hasStructuredResults) {
        // Map results back to optimistic entries by index
        for (final resultItem in results) {
          final result = resultItem;
          final index = (result['index'] as num?)?.toInt();
          final success = result['success'] == true;
          final data = _asStringDynamicMap(result['data']);

          if (index == null) {
            _debugPrint(
              '⚠️ Batch result missing index, ignoring item: $result',
            );
            continue;
          }

          final originalIndex = batchOffset + index;
          if (originalIndex < 0 || originalIndex >= preparedMutations.length) {
            continue;
          }

          final prepared = preparedMutations[originalIndex];
          final originalItem = prepared.item;

          if (success && data != null) {
            final savedEntry = ExpenseEntry.fromJson(data);
            final storedEntry = await upsertSavedEntry(
              prepared: prepared,
              savedEntry: savedEntry,
            );
            didPersistAny = true;
            savedEntries.add(storedEntry);
            if (!originalItem.transaction.isIncome) {
              savedExpenseCount += 1;
              savedExpenseEntriesById[storedEntry.id] = storedEntry;
            }
          } else {
            // Remove failed optimistic entry
            removeOptimisticTransactionWithContainer(
              container: container,
              optimisticId: originalItem.optimisticId,
              householdId: householdId,
            );
            await localDatabase?.rollbackOptimisticTransaction(
              optimisticId: originalItem.optimisticId,
              clientMutationId: prepared.metadata.clientMutationId,
              error: result['error'] ?? 'Batch item failed',
            );
            _debugPrint(
                '❌ Failed to persist transaction at index $originalIndex: ${result['error'] ?? 'unknown error'}');
          }
        }
      } else {
        _debugPrint(
          '⚠️ Batch response returned no per-item results; preserving optimistic entries and continuing',
        );
      }

      batchOffset += batch.length;
    }

    final splitAdjustedEntries =
        await attachOptimisticSplitsForSavedExpenses(savedExpenseEntriesById);
    if (splitAdjustedEntries.isNotEmpty) {
      for (var index = 0; index < savedEntries.length; index++) {
        savedEntries[index] =
            splitAdjustedEntries[savedEntries[index].id] ?? savedEntries[index];
      }
      savedExpenseEntriesById.addAll(splitAdjustedEntries);
    }
    await cacheSavedEntriesAndRefresh(savedEntries);

    if (didPersistAny) {
      await container
          .read(expenseSaveNotifierProvider.notifier)
          .invalidateAfterBatch(
            userId: userId,
            householdId: householdId,
            refreshAnalytics: false,
            refreshTransactionFeed: false,
            emitDashboardRefresh: false,
          );
    }

    if (savedExpenseCount > 0) {
      final prefs = container.read(sharedPreferencesProvider);
      unawaited(Future<void>.delayed(
        const Duration(milliseconds: 300),
        () => _maybeRequestReviewAfterExpenseSave(
          userId: userId,
          prefs: prefs,
          additionalExpenseCount: savedExpenseCount,
        ),
      ));
    }
  } catch (error) {
    _debugPrint('❌ Batch save failed: $error');

    final shouldFallback = shouldFallbackForBatchError(error);

    if (shouldFallback) {
      _debugPrint(
          '⚠️ Batch endpoint not available, falling back to individual saves');

      // Save transactions individually using existing endpoints
      var savedCount = 0;
      var savedExpenseCount = 0;
      var keptQueuedForRetry = false;
      final savedEntries = <ExpenseEntry>[];
      final savedExpenseEntriesById = <String, ExpenseEntry>{};

      for (final prepared in preparedMutations) {
        final item = prepared.item;
        try {
          final response = await supabase.functions.invoke(
            prepared.functionName,
            body: prepared.individualRequestBody,
          );

          final savedPayload = _extractSavedEntryPayload(response.data);

          if (savedPayload != null) {
            final savedEntry = ExpenseEntry.fromJson(savedPayload);
            final storedEntry = await upsertSavedEntry(
              prepared: prepared,
              savedEntry: savedEntry,
            );
            savedCount++;
            savedEntries.add(storedEntry);
            if (!item.transaction.isIncome) {
              savedExpenseCount++;
              savedExpenseEntriesById[storedEntry.id] = storedEntry;
            }
          } else {
            throw Exception(
                'No saved transaction data returned from ${prepared.functionName}');
          }
        } catch (itemError) {
          _debugPrint('❌ Failed to save individual transaction: $itemError');
          if (queuedLocally && _shouldKeepQueuedLocalMutation(itemError)) {
            _debugPrint(
              '📦 Keeping queued AI transaction ${item.optimisticId} for background retry',
            );
            keptQueuedForRetry = true;
            continue;
          }
          removeOptimisticTransactionWithContainer(
            container: container,
            optimisticId: item.optimisticId,
            householdId: householdId,
          );
          await localDatabase?.rollbackOptimisticTransaction(
            optimisticId: item.optimisticId,
            clientMutationId: prepared.metadata.clientMutationId,
            error: itemError,
          );
        }
      }

      _debugPrint(
          '[AI Fallback Save] Saved $savedCount/${transactions.length} transactions');

      if (savedExpenseEntriesById.isNotEmpty) {
        final splitAdjustedEntries =
            await attachOptimisticSplitsForSavedExpenses(
                savedExpenseEntriesById);
        if (splitAdjustedEntries.isNotEmpty) {
          for (var index = 0; index < savedEntries.length; index++) {
            savedEntries[index] =
                splitAdjustedEntries[savedEntries[index].id] ??
                    savedEntries[index];
          }
          savedExpenseEntriesById.addAll(splitAdjustedEntries);
        }
      }

      await cacheSavedEntriesAndRefresh(savedEntries);

      if (savedCount > 0) {
        await container
            .read(expenseSaveNotifierProvider.notifier)
            .invalidateAfterBatch(
              userId: userId,
              householdId: householdId,
              refreshAnalytics: false,
              refreshTransactionFeed: false,
              emitDashboardRefresh: false,
            );
      }

      if (savedExpenseCount > 0) {
        final prefs = container.read(sharedPreferencesProvider);
        unawaited(Future<void>.delayed(
          const Duration(milliseconds: 300),
          () => _maybeRequestReviewAfterExpenseSave(
            userId: userId,
            prefs: prefs,
            additionalExpenseCount: savedExpenseCount,
          ),
        ));
      }

      if (keptQueuedForRetry) {
        scheduleMobileOutboxDrain(
          container,
          maxMutations: max(20, preparedMutations.length),
        );
      }

      return; // Exit successfully after fallback
    }

    if (queuedLocally && _shouldKeepQueuedLocalMutation(error)) {
      _debugPrint(
        '📦 Keeping ${preparedMutations.length} queued AI transaction(s) for background retry',
      );
      container.read(transactionsFeedRefreshSignalProvider.notifier).state += 1;
      container.read(dashboardRefreshSignalProvider.notifier).state += 1;
      scheduleMobileOutboxDrain(
        container,
        maxMutations: max(20, preparedMutations.length),
      );
      return;
    }

    // For non-recoverable errors, remove all optimistic entries and rethrow
    for (final prepared in preparedMutations) {
      final item = prepared.item;
      removeOptimisticTransactionWithContainer(
        container: container,
        optimisticId: item.optimisticId,
        householdId: householdId,
      );
      await localDatabase?.rollbackOptimisticTransaction(
        optimisticId: item.optimisticId,
        clientMutationId: prepared.metadata.clientMutationId,
        error: error,
      );
    }

    rethrow;
  }
}

bool shouldFallbackForBatchError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('404') || message.contains('not_found')) {
    return true;
  }
  if (message.contains('bad file descriptor')) {
    return true;
  }
  if (message.contains('status: 503') ||
      message.contains('service is temporarily unavailable') ||
      message.contains('supabase_edge_runtime_error')) {
    return true;
  }
  // Backend rejected the batch size — fall back to individual saves.
  if (message.contains('batch size exceeds')) {
    return true;
  }
  return false;
}

bool _shouldKeepQueuedLocalMutation(Object error) {
  if (error is SocketException || error is TimeoutException) return true;

  final message = error.toString().toLowerCase();
  return message.contains('network') ||
      message.contains('socket') ||
      message.contains('failed host lookup') ||
      message.contains('connection') ||
      message.contains('timed out') ||
      message.contains('timeout') ||
      message.contains('status: 502') ||
      message.contains('status: 503') ||
      message.contains('status: 504') ||
      message.contains('service is temporarily unavailable') ||
      message.contains('supabase_edge_runtime_error') ||
      message.contains('bad file descriptor');
}

bool shouldQueueAiInputForRetry(Object error) =>
    _shouldKeepQueuedLocalMutation(error);

Map<String, dynamic> buildQueuedAiInputPayload({
  required String userId,
  required String? householdId,
  required bool isPortfolio,
  required String? accountId,
  String? accountCurrency,
  required Map<String, dynamic> analysisBody,
  String? localImagePath,
  String? imageContentType,
  String? localAudioPath,
  String? audioContentType,
}) {
  final body = Map<String, dynamic>.from(analysisBody)
    ..remove('image')
    ..remove('audio');
  final normalizedHouseholdId = householdId?.trim();
  final normalizedAccountId = accountId?.trim();
  final normalizedAccountCurrency = accountCurrency?.trim().toUpperCase();
  final normalizedImagePath = localImagePath?.trim();
  final normalizedAudioPath = localAudioPath?.trim();

  return <String, dynamic>{
    'userId': userId,
    'body': body,
    if (normalizedHouseholdId != null && normalizedHouseholdId.isNotEmpty)
      'householdId': normalizedHouseholdId,
    if (normalizedHouseholdId != null && normalizedHouseholdId.isNotEmpty)
      'isPortfolio': isPortfolio,
    if (normalizedAccountId != null && normalizedAccountId.isNotEmpty)
      'accountId': normalizedAccountId,
    if (normalizedAccountCurrency != null &&
        normalizedAccountCurrency.isNotEmpty)
      'accountCurrency': normalizedAccountCurrency,
    if (normalizedImagePath != null && normalizedImagePath.isNotEmpty)
      'localImagePath': normalizedImagePath,
    if (normalizedImagePath != null && normalizedImagePath.isNotEmpty)
      'imageContentType': imageContentType ?? 'image/jpeg',
    if (normalizedAudioPath != null && normalizedAudioPath.isNotEmpty)
      'localAudioPath': normalizedAudioPath,
    if (normalizedAudioPath != null && normalizedAudioPath.isNotEmpty)
      'audioContentType': audioContentType ?? 'audio/mpeg',
  };
}

String _fileExtensionFromPath(String path, {String fallback = 'bin'}) {
  final name = path.split('/').last;
  if (!name.contains('.')) return fallback;
  final extension = name.split('.').last.toLowerCase().trim();
  if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)) return fallback;
  return extension;
}

String _imageContentTypeForPath(String path) {
  final extension = _fileExtensionFromPath(path, fallback: 'jpg');
  return switch (extension) {
    'png' => 'image/png',
    'heic' => 'image/heic',
    'webp' => 'image/webp',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => 'image/jpeg',
  };
}

Future<Directory> _pendingAiInputDirectory() async {
  final documents = await getApplicationDocumentsDirectory();
  final directory =
      Directory('${documents.path}/$_pendingAiInputDirectoryName');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

Future<String> _copyPendingAiInputFile({
  required File source,
  required String prefix,
  String fallbackExtension = 'bin',
}) async {
  if (!await source.exists()) {
    throw FileSystemException(
        'Pending AI input file does not exist', source.path);
  }
  final directory = await _pendingAiInputDirectory();
  final extension = _fileExtensionFromPath(
    source.path,
    fallback: fallbackExtension,
  );
  final fileName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}_'
      '${Random.secure().nextInt(1 << 32)}.$extension';
  final copy = await source.copy('${directory.path}/$fileName');
  return copy.path;
}

Future<String> _writePendingAiInputBytes({
  required Uint8List bytes,
  required String prefix,
  required String extension,
}) async {
  final directory = await _pendingAiInputDirectory();
  final safeExtension =
      RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension) ? extension : 'bin';
  final fileName = '${prefix}_${DateTime.now().microsecondsSinceEpoch}_'
      '${Random.secure().nextInt(1 << 32)}.$safeExtension';
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> _uploadReceiptImageForAiQueue(
    File imageFile, String userId) async {
  final compressedBytes = await ImageCompressor.compressFile(
    imageFile,
    config: ImageCompressConfig.receipt,
  );
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  final path = 'receipts/$userId/$fileName';
  final response = await supabase.storage.from('expense-receipts').uploadBinary(
        path,
        compressedBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          cacheControl: '31536000',
        ),
      );
  if (response.isEmpty) throw StateError('Receipt upload failed');
  return supabase.storage.from('expense-receipts').getPublicUrl(path);
}

Future<bool> _queueAiInputForBackgroundRetry(
  ProviderContainer container, {
  required String userId,
  required String? householdId,
  required bool isPortfolio,
  required String? accountId,
  String? accountCurrency,
  required Map<String, dynamic> analysisBody,
  String? imagePath,
  Uint8List? audioBytes,
  String? audioContentType,
}) async {
  final hasText = analysisBody['text']?.toString().trim().isNotEmpty == true;
  final hasAttachments = analysisBody['attachments'] is List &&
      (analysisBody['attachments'] as List).isNotEmpty;
  final hasImage = imagePath?.trim().isNotEmpty == true;
  final hasAudio = audioBytes != null && audioBytes.isNotEmpty;
  if (!hasText && !hasAttachments && !hasImage && !hasAudio) return false;

  String? durableImagePath;
  String? durableAudioPath;
  if (hasImage) {
    durableImagePath = await _copyPendingAiInputFile(
      source: File(imagePath!),
      prefix: 'image',
      fallbackExtension: 'jpg',
    );
  }
  if (hasAudio) {
    final contentType = audioContentType ?? 'audio/mpeg';
    final extension = contentType.contains('aac')
        ? 'aac'
        : contentType.contains('wav')
            ? 'wav'
            : contentType.contains('m4a')
                ? 'm4a'
                : 'mp3';
    durableAudioPath = await _writePendingAiInputBytes(
      bytes: audioBytes,
      prefix: 'audio',
      extension: extension,
    );
  }

  final database = await container.read(localDatabaseProvider.future);
  final queuedId = makeOptimisticTransactionId().replaceFirst(
    'optimistic_',
    'ai_input_',
  );
  final payload = buildQueuedAiInputPayload(
    userId: userId,
    householdId: householdId,
    isPortfolio: isPortfolio,
    accountId: accountId,
    accountCurrency: accountCurrency,
    analysisBody: analysisBody,
    localImagePath: durableImagePath,
    imageContentType:
        imagePath == null ? null : _imageContentTypeForPath(imagePath),
    localAudioPath: durableAudioPath,
    audioContentType: audioContentType,
  );

  await database.enqueueMutation(
    clientMutationId: 'mobile:$queuedId',
    entityType: 'ai_input',
    entityId: queuedId,
    operation: 'analyze_ai_input',
    payload: payload,
  );
  return true;
}

List<List<T>> chunkList<T>(List<T> items, int maxSize) {
  if (items.isEmpty) return <List<T>>[];
  final chunks = <List<T>>[];
  for (var i = 0; i < items.length; i += maxSize) {
    final end = (i + maxSize) > items.length ? items.length : (i + maxSize);
    chunks.add(items.sublist(i, end));
  }
  return chunks;
}

Future<void> handleAiCameraCapture(
  BuildContext context,
  WidgetRef ref, {
  AiInputTarget? inputTarget,
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  _debugPrint('🎥 Starting camera capture...');

  try {
    final captured = await Navigator.of(context, rootNavigator: true)
        .push<AiCameraCaptureResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AiCameraCaptureView(
          initialTarget: inputTarget ?? resolveDefaultAiInputTarget(ref),
        ),
      ),
    );

    _debugPrint('🎥 Photo captured: ${captured != null}');

    if (captured != null) {
      if (context.mounted) {
        await _processExpense(
          context,
          ref,
          imagePath: captured.imagePath,
          inputTarget: captured.target,
          onSuccess: onSuccess,
        );
      }
    } else {
      _debugPrint('🎥 User cancelled or permission denied');
    }
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

Future<void> handleAiLibraryCapture(
  BuildContext context,
  WidgetRef ref, {
  AiInputTarget? inputTarget,
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  try {
    final XFile? image = await pickImageWithGuard(
      picker: _imagePicker,
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !context.mounted) {
      return;
    }

    await _processExpense(
      context,
      ref,
      imagePath: image.path,
      inputTarget: inputTarget ?? resolveDefaultAiInputTarget(ref),
      onSuccess: onSuccess,
    );
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

Future<void> handleAiAudioBytes(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List audioBytes,
  String contentType = 'audio/aac',
  AiInputTarget? inputTarget,
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  if (!context.mounted) return;
  await _processExpense(
    context,
    ref,
    audioBytes: audioBytes,
    audioContentType: contentType,
    inputTarget: inputTarget ?? resolveDefaultAiInputTarget(ref),
    onSuccess: onSuccess,
  );
}

Future<void> handleAiFreeFormText(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  await showTextInputDrawer(
    context,
    (text, target) async {
      if (!context.mounted) return;
      await _processExpense(
        context,
        ref,
        text: text,
        inputTarget: target,
        onSuccess: onSuccess,
      );
    },
    onSubmitAudio: (audioBytes, contentType, target) async {
      if (!context.mounted) return;
      await _processExpense(
        context,
        ref,
        audioBytes: audioBytes,
        audioContentType: contentType,
        inputTarget: target,
        onSuccess: onSuccess,
      );
    },
  );
}

Future<void> handleAiFileUpload(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['csv', 'pdf', 'xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final path = file.path;

    if (path == null) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.failedToAnalyze);
      }
      return;
    }

    final fileSize = file.size;
    if (fileSize > _maxAiFileUploadBytes) {
      if (context.mounted) {
        AppToast.error(
          context,
          'File is too large to analyze. Keep it under 20MB or split it into smaller files.',
        );
      }
      return;
    }

    final bytes = await File(path).readAsBytes();
    final base64Data =
        await foundation.compute<List<int>, String>(base64Encode, bytes);

    final extension = path.split('.').last.toLowerCase();
    String contentType = 'application/octet-stream';
    if (extension == 'csv') {
      contentType = 'text/csv';
    } else if (extension == 'pdf') {
      contentType = 'application/pdf';
    } else if (extension == 'xlsx') {
      contentType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (extension == 'xls') {
      contentType = 'application/vnd.ms-excel';
    }

    final attachments = <Map<String, dynamic>>[
      {
        'filename': file.name,
        'contentType': contentType,
        'data': base64Data,
      },
    ];

    if (context.mounted) {
      await _processExpense(
        context,
        ref,
        attachments: attachments,
        inputTarget: resolveDefaultAiInputTarget(ref),
        onSuccess: onSuccess,
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

Future<void> handleAiFileOrGallery(
  BuildContext context,
  WidgetRef ref, {
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  await AdaptiveAlertDialog.show(
    context: context,
    title: context.l10n.appTitle,
    message: context.l10n.chooseSourceForAnalysis,
    actions: [
      AlertAction(
        title: context.l10n.files,
        style: AlertActionStyle.primary,
        onPressed: () async {
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ImportWizardPage(),
            ),
          );
        },
      ),
      AlertAction(
        title: context.l10n.gallery,
        style: AlertActionStyle.primary,
        onPressed: () async {
          await handleAiLibraryCapture(context, ref, onSuccess: onSuccess);
        },
      ),
      AlertAction(
        title: context.l10n.cancel,
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
    ],
  );
}

/// Process analysis request with SSE streaming for real-time progress updates.
Future<Map<String, dynamic>?> _processWithSSE({
  required Map<String, dynamic> body,
  required BlockingProcessingController dialogController,
  required bool Function() onCancelCheck,
}) async {
  // Get Supabase URL and auth token
  final supabaseUrl = Constants.supabaseUrl;
  final session = supabase.auth.currentSession;
  if (session == null) {
    throw Exception('No auth session');
  }

  // Build SSE URL with stream=true query param
  final sseUrl =
      Uri.parse('$supabaseUrl/functions/v1/analyze-expense?stream=true');

  _debugPrint('[SSE] Starting streaming request');

  Map<String, dynamic>? result;

  await for (final event in SSEService.streamRequest(
    url: sseUrl,
    body: body,
    headers: {
      'Authorization': 'Bearer ${session.accessToken}',
    },
    timeout: const Duration(minutes: 3),
  )) {
    // Check for cancellation
    if (onCancelCheck()) {
      _debugPrint('[SSE] Cancelled by user');
      throw Exception('Cancelled');
    }

    _debugPrint('[SSE] Received event: ${event.event}');

    switch (event.event) {
      case 'progress':
        final progressEvent = AnalysisProgressEvent.fromJson(event.data);
        dialogController.updateSubMessage(
          _friendlyProgressMessage(progressEvent),
        );
        break;
      case 'complete':
        result = event.data;
        break;
      case 'error':
        if (event.data is Map<String, dynamic>) {
          throw Map<String, dynamic>.from(event.data as Map<String, dynamic>);
        }
        throw Exception(event.data?.toString() ?? 'Unknown error');
    }
  }

  return result;
}

Future<void> _maybeShowUnsetHoldQuickActionReminder(
  BuildContext context,
  WidgetRef ref, {
  required int additionalExpenseCount,
}) async {
  if (!context.mounted) return;
  if (additionalExpenseCount <= 0) return;

  final prefs = ref.read(sharedPreferencesProvider);
  final quickAction = readAiHoldQuickActionPreference(prefs);
  if (quickAction != null) return;

  final userId = ref.read(authProvider).uid;
  if (userId.trim().isEmpty) return;
  final userKey = sha256.convert(utf8.encode(userId)).toString();

  final countKey = '${_holdQuickActionReminderExpenseCountKey}_$userKey';
  final shownKey = '${_holdQuickActionReminderShownKey}_$userKey';

  final updatedCount = (prefs.getInt(countKey) ?? 0) + additionalExpenseCount;
  await prefs.setInt(countKey, updatedCount);

  final alreadyShown = prefs.getBool(shownKey) ?? false;
  if (alreadyShown) return;
  if (updatedCount < _holdQuickActionReminderFirstPromptAt) return;
  if (!context.mounted) return;

  await MonekoAlertDialog.show(
    context: context,
    title: context.l10n.fasterLoggingTipTitle,
    description: context.l10n.fasterLoggingTipDescription,
    confirmLabel: context.l10n.gotIt,
    cancelLabel: null,
  );
  await prefs.setBool(shownKey, true);
}

Future<void> _processExpense(
  BuildContext context,
  WidgetRef ref, {
  String? text,
  String? imagePath,
  List<Map<String, dynamic>>? attachments,
  Uint8List? audioBytes,
  String? audioContentType,
  required AiInputTarget inputTarget,
  void Function(AiLogSuccess success)? onSuccess,
}) async {
  final user = ref.read(authProvider);
  final preview = ref.read(previewModeProvider);
  final contact = ref.read(appUserContactProvider);
  final householdId = inputTarget.householdId;
  final isPortfolio = inputTarget.isPortfolio;
  final effectiveUserId = preview.isActive
      ? (PreviewMockData.contact.userId ?? 'preview-user')
      : user.uid;
  final locale = Localizations.localeOf(context);
  final languageTag =
      locale.countryCode != null && locale.countryCode!.isNotEmpty
          ? '${locale.languageCode}-${locale.countryCode!.toUpperCase()}'
          : locale.languageCode;
  final today = effectiveToday(preferredTimezone: contact?.preferredTimezone);
  final defaultDateYmd = formatDateOnlyYmd(today);
  final filterState = ref.read(homeFilterProvider);
  final selectedCurrency = filterState.selectedCurrency;
  final effectiveCurrency =
      (selectedCurrency != null && selectedCurrency.isNotEmpty)
          ? selectedCurrency.toUpperCase()
          : contact?.preferredCurrency?.toUpperCase();
  final providerContainer = ProviderScope.containerOf(context, listen: false);

  // Determine if this is a potentially slow operation.
  final hasAttachments = attachments?.isNotEmpty ?? false;
  final hasImageInput = imagePath != null && imagePath.isNotEmpty;
  final hasAudioInput = audioBytes != null && audioBytes.isNotEmpty;
  final hasTextInput = text != null && text.trim().isNotEmpty;
  final trimmedText = text?.trim();
  final isPdfUpload = attachments?.any((a) =>
          a['contentType']?.toString().contains('pdf') == true ||
          a['filename']?.toString().toLowerCase().endsWith('.pdf') == true) ??
      false;
  final isLargeFile = attachments?.any((a) {
        final data = a['data']?.toString() ?? '';
        // Base64 data > 500KB (roughly 375KB raw)
        return data.length > 500000;
      }) ??
      false;

  Map<String, dynamic>? responseData;
  var analysisRequestBody = <String, dynamic>{};
  Future<bool> queueCurrentAiInputForRetry() {
    return _queueAiInputForBackgroundRetry(
      providerContainer,
      userId: user.uid,
      householdId: householdId,
      isPortfolio: isPortfolio,
      accountId: inputTarget.accountId?.trim().isNotEmpty == true
          ? inputTarget.accountId!.trim()
          : null,
      accountCurrency: inputTarget.accountCurrency,
      analysisBody: analysisRequestBody,
      imagePath: imagePath,
      audioBytes: audioBytes,
      audioContentType: audioContentType,
    );
  }

  final canUseSmartInputMemory = !preview.isActive &&
      hasTextInput &&
      trimmedText != null &&
      !hasAttachments &&
      !hasImageInput &&
      !hasAudioInput;
  var usedSmartInputMemory = false;
  if (canUseSmartInputMemory) {
    responseData = _tryBuildSmartInputMemoryResponse(
      prefs: ref.read(sharedPreferencesProvider),
      userId: effectiveUserId,
      householdId: householdId,
      currency: effectiveCurrency,
      languageTag: languageTag,
      inputText: trimmedText,
      defaultDateYmd: defaultDateYmd,
    );
    usedSmartInputMemory = responseData != null;
  }

  final shouldShowProcessingDialog = !usedSmartInputMemory;
  final shouldStream = shouldShowProcessingDialog &&
      (hasAttachments || hasImageInput || hasAudioInput || hasTextInput);
  final useEnhancedDialog = shouldShowProcessingDialog &&
      (shouldStream || isPdfUpload || isLargeFile);

  // Show enhanced processing modal with timeout handling for PDFs
  BlockingProcessingController? dialogController;

  if (useEnhancedDialog) {
    dialogController = showEnhancedBlockingDialog(
      context: context,
      message: context.l10n.analyzingReceipt,
      subMessage: isPdfUpload
          ? 'Processing PDF document...'
          : hasTextInput
              ? 'Reading what you typed...'
              : hasImageInput
                  ? 'Looking through your image...'
                  : hasAudioInput
                      ? 'Listening to your recording...'
                      : hasAttachments
                          ? 'Processing file...'
                          : 'Processing large file...',
      showElapsedTime: true,
      enableCancelAfterSeconds: 0,
    );
  } else if (shouldShowProcessingDialog) {
    showBlockingProcessingDialog(
      context: context,
      message: imagePath != null
          ? context.l10n.analyzingReceipt
          : context.l10n.analyzingExpense,
    );
  }

  try {
    List<Map<String, dynamic>> householdMembersContext =
        const <Map<String, dynamic>>[];

    if (preview.isActive) {
      responseData = {
        'success': true,
        'data': {
          'items': [
            {
              'description': 'Demo coffee at Cafe Bloom',
              'amount': 5.50,
              'currency': 'USD',
              'category': 'Dining',
              'date': defaultDateYmd,
              'is_income': false,
            },
          ],
        },
      };
    }

    analysisRequestBody = <String, dynamic>{
      'userId': effectiveUserId,
      'date': defaultDateYmd,
      'language': languageTag,
      'typeHint': 'mixed',
    };
    final body = analysisRequestBody;

    if (householdId != null && householdId.isNotEmpty) {
      body['householdId'] = householdId;
      body['isPortfolio'] = isPortfolio;
      if (!isPortfolio) {
        final memberContext = _buildHouseholdMemberContext(ref, householdId);
        householdMembersContext = memberContext;
        if (memberContext.isNotEmpty) {
          body['householdMembers'] = memberContext;
        }
      }
    }

    // Always use selected currency as default (same as personal expense)
    // Backend will use this as a fallback if no currency is detected in the text/image.
    // If this is also missing, backend defaults to USD.
    if (effectiveCurrency != null && effectiveCurrency.isNotEmpty) {
      body['currency'] = effectiveCurrency;
    }

    // Add either text, image, audio, or file attachments to the request
    if (text != null) {
      body['text'] = text;
    } else if (imagePath != null) {
      // Read image bytes and convert to base64
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final base64Image =
          await foundation.compute<List<int>, String>(base64Encode, bytes);

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      final extension = imagePath.split('.').last.toLowerCase();
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'heic') {
        contentType = 'image/heic';
      }

      body['image'] = {
        'data': base64Image,
        'contentType': contentType,
      };
    }

    if (attachments != null && attachments.isNotEmpty) {
      body['attachments'] = attachments;
    }

    if (audioBytes != null && audioBytes.isNotEmpty) {
      final base64Audio =
          await foundation.compute<List<int>, String>(base64Encode, audioBytes);
      body['audio'] = {
        'data': base64Audio,
        'contentType': audioContentType ?? 'audio/mpeg',
      };
    }

    // Update dialog for PDFs
    if (dialogController != null && isPdfUpload) {
      dialogController.updateSubMessage('Extracting transactions from PDF...');
    }

    // Check if user cancelled before making request
    if (dialogController?.isCancelled ?? false) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return;
    }

    final isOffline =
        ref.read(networkReachabilityProvider).valueOrNull == false;
    if (!preview.isActive && responseData == null && isOffline) {
      if (shouldShowProcessingDialog && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final queued = await queueCurrentAiInputForRetry();
      if (queued) {
        if (context.mounted) {
          AppToast.success(
            context,
            context.l10n.walletCaptureOfflineDescription,
          );
        }
        return;
      }
    }

    // Use SSE streaming when media is involved to show real-time progress.
    if (responseData == null && shouldStream && dialogController != null) {
      try {
        responseData = await _processWithSSE(
          body: body,
          dialogController: dialogController,
          onCancelCheck: () => dialogController?.isCancelled ?? false,
        );
      } catch (e) {
        _debugPrint('[SSE] Failed, falling back to regular request: $e');
        // Fall through to regular request
        responseData = null;
      }
    }

    // Regular request (fallback or non-PDF/small files)
    if (responseData == null) {
      // Update dialog for PDFs
      if (dialogController != null && isPdfUpload) {
        dialogController
            .updateSubMessage('Extracting transactions from PDF...');
      }

      // Explicitly pass JWT so the Edge Function can enrich household context
      // (householdMembers) under RLS. This is required for reliable split output.
      final session = supabase.auth.currentSession;
      final response = await supabase.functions.invoke(
        'analyze-expense',
        body: body,
        headers: session != null
            ? <String, String>{
                'Authorization': 'Bearer ${session.accessToken}',
              }
            : null,
      );

      final parsedResponse = _asStringDynamicMap(response.data);
      if (parsedResponse != null) {
        responseData = parsedResponse;
      }
    }

    if (!usedSmartInputMemory &&
        canUseSmartInputMemory &&
        responseData != null) {
      unawaited(_rememberSmartInputAnalysis(
        prefs: ref.read(sharedPreferencesProvider),
        userId: effectiveUserId,
        householdId: householdId,
        currency: effectiveCurrency,
        languageTag: languageTag,
        inputText: trimmedText,
        defaultDateYmd: defaultDateYmd,
        responseData: responseData,
      ));
    }

    // Close processing modal
    if (shouldShowProcessingDialog && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) {
      return;
    }

    _debugPrint('Analysis response received');

    if (responseData != null && responseData['success'] == true) {
      final innerData = _asStringDynamicMap(responseData['data']);

      if (innerData != null && innerData['items'] is List) {
        List items = List.from(innerData['items'] as List);
        _debugPrint(
          '[AI] Analysis split fields: ${jsonEncode(items.map((rawItem) {
            final item = rawItem is Map
                ? Map<String, dynamic>.from(rawItem)
                : <String, dynamic>{};
            return <String, dynamic>{
              'amount': item['amount'],
              'description': item['description'],
              'payerUserId': item['payerUserId'],
              'customSplits': item['customSplits'],
            };
          }).toList(growable: false))}',
          wrapWidth: 1024,
        );
        // Safety filter: drop total/subtotal rows when multiple items exist
        if (items.length > 1) {
          bool isTotalLike(dynamic it) {
            final desc = (it is Map && it['description'] is String)
                ? (it['description'] as String)
                : '';
            return RegExp(r'(sub\s*total|subtotal|grand\s*total|total)',
                    caseSensitive: false)
                .hasMatch(desc);
          }

          final filtered = items.where((it) => !isTotalLike(it)).toList();
          if (filtered.isNotEmpty) items = filtered;
        }

        if (householdId != null && householdId.isNotEmpty && !isPortfolio) {
          items = _applyExplicitSplitOverrideToItems(
            items: items,
            text: text,
            callerUserId: user.uid,
            householdMembers: householdMembersContext,
          );
        }

        if (items.isNotEmpty) {
          final analyticsContactId = ref.read(appUserContactProvider)?.id;
          final rawScopedDefaultAccountId =
              inputTarget.accountId?.trim().isNotEmpty == true
                  ? inputTarget.accountId!.trim()
                  : null;
          final scopedDefaultAccountId =
              rawScopedDefaultAccountId?.isEmpty == true
                  ? null
                  : rawScopedDefaultAccountId;
          String? resolveScopedAccountIdForCurrency(String currency) {
            final normalizedCurrency = currency.trim().toUpperCase();
            final targetAccountCurrency = inputTarget.accountCurrency;
            if (scopedDefaultAccountId != null &&
                targetAccountCurrency != null &&
                normalizedCurrency == targetAccountCurrency) {
              return scopedDefaultAccountId;
            }
            return null;
          }

          final expenseCategoryRemaps = await _loadLocalCategoryRemaps(
            providerContainer,
            userId: user.uid,
            transactionType: 'expense',
          );
          final incomeCategoryRemaps = await _loadLocalCategoryRemaps(
            providerContainer,
            userId: user.uid,
            transactionType: 'income',
          );
          final optimisticAutoSplitContext =
              householdId != null && householdId.isNotEmpty && !isPortfolio
                  ? await _loadAutoSplitContext(
                      providerContainer,
                      householdId: householdId,
                    )
                  : null;

          // Parse ALL items and immediately optimistic-log them.
          final parsed = items
              .map((rawItem) {
                final item = rawItem is Map
                    ? Map<String, dynamic>.from(rawItem)
                    : <String, dynamic>{};
                final rawDate = item['date']?.toString();
                final parsedDateOnly = tryParseDateOnlyYmd(rawDate);
                DateTime? accountingDate;
                if (parsedDateOnly != null) {
                  accountingDate = parsedDateOnly;
                } else {
                  final parsedInstant = DateTime.tryParse(rawDate ?? '');
                  if (parsedInstant != null) {
                    final effective = parsedInstant.isUtc
                        ? parsedInstant.toLocal()
                        : parsedInstant;
                    accountingDate = DateTime(
                        effective.year, effective.month, effective.day);
                  }
                }
                if (accountingDate == null) {
                  _debugPrint('Skipping AI item with invalid date');
                  return null;
                }
                final isIncome =
                    (item['type']?.toString().toLowerCase() == 'income');
                final amount = _parseAmountValue(item['amount']);
                final currency = item['currency']?.toString().trim();
                if (amount == null || currency == null || currency.isEmpty) {
                  _debugPrint('Skipping AI item with invalid amount/currency');
                  return null;
                }
                final resolvedCategory = _resolveOptimisticAiCategory(
                  rawCategory: item['category'],
                  rawDescription: item['description'],
                  isIncome: isIncome,
                );
                final category = _applyLocalCategoryRemap(
                  category: resolvedCategory,
                  remaps:
                      isIncome ? incomeCategoryRemaps : expenseCategoryRemaps,
                );
                final transaction = ParsedExpense(
                  isIncome: isIncome,
                  amount: amount,
                  // Normalize income categories to at least 'income' umbrella if model returns a granular one
                  category: category,
                  currency: currency,
                  currencySymbol: item['currencySymbol'] as String? ?? '\$',
                  date: accountingDate,
                  description: item['description'] is String
                      ? sanitizeUtf16(item['description'] as String)
                      : null,
                  breakdown: item['breakdown'] is List
                      ? (item['breakdown'] as List)
                          .map((e) => sanitizeUtf16(e.toString()))
                          .toList()
                      : null,
                  localImagePath: imagePath,
                  payerUserId: (item['payerUserId'] is String)
                      ? (item['payerUserId'] as String)
                      : null,
                  payerHint: (item['payerHint'] is String)
                      ? (item['payerHint'] as String)
                      : (item['payerName'] is String)
                          ? (item['payerName'] as String)
                          : (item['paidBy'] is String)
                              ? (item['paidBy'] as String)
                              : (item['payerEmail'] is String)
                                  ? (item['payerEmail'] as String)
                                  : null,
                );

                final optimisticId = makeOptimisticTransactionId();
                final optimisticSplitGroup = householdId != null &&
                        householdId.isNotEmpty &&
                        !isPortfolio &&
                        !isIncome
                    ? buildOptimisticHouseholdSplitGroup(
                        householdId: householdId,
                        expenseId: optimisticId,
                        payerUserId:
                            transaction.payerUserId?.trim().isNotEmpty == true
                                ? transaction.payerUserId!.trim()
                                : user.uid,
                        totalAmount: transaction.amount,
                        currency: transaction.currency,
                        members: optimisticAutoSplitContext?.members ??
                            const <HouseholdMember>[],
                        autoSplitEnabled: optimisticAutoSplitContext
                                ?.household.autoSplitEnabled ??
                            false,
                        autoSplitConfig: optimisticAutoSplitContext
                            ?.household.autoSplitConfig,
                        rawCustomSplits: item['customSplits'],
                        description: transaction.description,
                      )
                    : null;
                final entry = buildOptimisticEntry(
                  transaction: transaction,
                  optimisticId: optimisticId,
                  userId: user.uid,
                  contactId: analyticsContactId,
                  householdId: householdId,
                  accountId: resolveScopedAccountIdForCurrency(
                    transaction.currency,
                  ),
                  type: isIncome ? 'income' : 'expense',
                  splitGroupId: optimisticSplitGroup?.id,
                );
                addOptimisticTransaction(
                  ref: ref,
                  entry: entry,
                  householdId: householdId,
                );
                final optimisticType = entry.type ?? 'expense';
                final optimisticCurrency = entry.currency ?? '<none>';
                final optimisticHousehold = householdId ?? '<personal>';
                homeSpendTrace(
                  'ai-optimistic-added id=${entry.id} type=$optimisticType '
                  'amount=${traceAiAmount(entry.amount)} currency=$optimisticCurrency '
                  'household=$optimisticHousehold',
                );
                if (optimisticSplitGroup != null) {
                  ref
                      .read(householdOptimisticSplitsProvider.notifier)
                      .addSplitGroup(
                        optimisticSplitGroup.householdId,
                        optimisticSplitGroup,
                      );
                }

                return _AiParsedItem(
                  transaction: transaction,
                  optimisticId: optimisticId,
                  optimisticEntry: entry,
                  raw: item,
                );
              })
              .whereType<_AiParsedItem>()
              .toList();

          if (parsed.isEmpty) {
            if (context.mounted) {
              AppToast.info(
                  context, context.l10n.noExpenseInformationExtracted);
            }
            return;
          }

          final optimisticTargetLabel = _resolveLogTargetLabelFromInputTarget(
            context,
            ref,
            inputTarget: inputTarget,
          );

          if (context.mounted) {
            AppToast.success(
              context,
              _formatAiLoggedToastMessage(
                context,
                items: parsed,
                targetLabel: optimisticTargetLabel,
              ),
            );
          }

          if (context.mounted && onSuccess != null) {
            onSuccess(
              AiLogSuccess(
                count: parsed.length,
                targetLabel: optimisticTargetLabel,
                items: parsed
                    .map((entry) => entry.transaction)
                    .toList(growable: false),
              ),
            );
          }

          final expenseCount =
              parsed.where((entry) => !entry.transaction.isIncome).length;
          if (context.mounted && expenseCount > 0) {
            unawaited(_maybeShowUnsetHoldQuickActionReminder(
              context,
              ref,
              additionalExpenseCount: expenseCount,
            ));
          }

          if (!preview.isActive) {
            unawaited(
              _persistAiTransactions(
                providerContainer,
                userId: user.uid,
                householdId: householdId,
                isPortfolio: isPortfolio,
                transactions: parsed,
                accountId: scopedDefaultAccountId,
                accountCurrency: inputTarget.accountCurrency,
                localImagePath: imagePath,
              ),
            );
          }
        } else {
          if (context.mounted) {
            AppToast.info(context, context.l10n.noExpenseInformationExtracted);
          }
        }
      } else {
        if (context.mounted) {
          AppToast.info(context, context.l10n.failedToAnalyzeNoData);
        }
      }
    } else {
      final errorPayload = <String, dynamic>{
        'error': responseData?['error'],
        'message': responseData?['message'],
        'code': responseData?['code'],
        'status': responseData?['status'],
      };
      if (!preview.isActive && shouldQueueAiInputForRetry(errorPayload)) {
        try {
          final queued = await queueCurrentAiInputForRetry();
          if (queued) {
            if (context.mounted) {
              AppToast.success(
                context,
                context.l10n.walletCaptureOfflineDescription,
              );
            }
            return;
          }
        } catch (queueError) {
          _debugPrint(
            '⚠️ Failed to queue AI input for background retry: $queueError',
          );
        }
      }
      if (context.mounted) {
        AppToast.error(
          context,
          ErrorHandler.getUserFriendlyMessage(
            errorPayload,
            context: BackendErrorContext.analyzeExpense,
          ),
        );
      }
    }
  } catch (e) {
    _debugPrint('Error in analysis: $e');

    // Close processing modal
    if (shouldShowProcessingDialog && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!preview.isActive && shouldQueueAiInputForRetry(e)) {
      try {
        final queued = await queueCurrentAiInputForRetry();
        if (queued) {
          if (context.mounted) {
            AppToast.success(
              context,
              context.l10n.walletCaptureOfflineDescription,
            );
          }
          return;
        }
      } catch (queueError) {
        _debugPrint(
            '⚠️ Failed to queue AI input for background retry: $queueError');
      }
    }

    if (context.mounted) {
      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }
}

/// Determines if the unified transaction FAB should be visible for a given
/// view mode and household loading state.
bool shouldShowHomeFab(
  ViewModeState viewMode,
  AsyncValue<List<Household>> householdsAsync,
) {
  // Always show FAB in personal mode
  if (viewMode.mode == ViewMode.personal) {
    return true;
  }

  // In household mode, hide FAB if households are empty (showing onboarding)
  return householdsAsync.maybeWhen(
    data: (households) => households.isNotEmpty,
    orElse: () => true, // Show FAB during loading or error states
  );
}

class HomeAiExpandableFab extends ConsumerStatefulWidget {
  const HomeAiExpandableFab({super.key});

  @override
  ConsumerState<HomeAiExpandableFab> createState() =>
      _HomeAiExpandableFabState();
}

class _HomeAiExpandableFabState extends ConsumerState<HomeAiExpandableFab> {
  final AudioRecorder _holdRecorder = AudioRecorder();
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();

  bool _isHoldRecording = false;
  bool _isHoldCancelled = false;
  bool _didCrossCancelThreshold = false;
  double _holdDragDeltaX = 0;
  DateTime? _holdRecordingStartedAt;
  double? _holdStartGlobalX;
  Timer? _holdAmplitudeTimer;
  double _holdRecordingPeakDb = _silentRecordingPeakDb;
  bool _isFabOpen = false;

  @override
  void dispose() {
    _holdAmplitudeTimer?.cancel();
    _holdRecorder.dispose();
    super.dispose();
  }

  Future<void> _playQuickActionDualNudge() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    HapticFeedback.lightImpact();
  }

  Future<void> _openManualEntrySheet() async {
    final contact = ref.read(appUserContactProvider);
    final filterState = ref.read(homeFilterProvider);
    final selectedCurrency =
        (filterState.selectedCurrency ?? contact?.preferredCurrency ?? 'USD')
            .trim()
            .toUpperCase();

    await showUnifiedTransactionSheet(
      context,
      contact: contact,
      newExpense: ParsedExpense(
        amount: 0,
        category: 'other',
        currency: selectedCurrency,
        currencySymbol: '\$',
        date: effectiveToday(preferredTimezone: contact?.preferredTimezone),
        description: null,
      ),
    );
  }

  Future<void> _runHoldAction() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final holdAction = readAiHoldQuickActionPreference(prefs);
    final selectedAction = holdAction ?? AiHoldQuickAction.textInputDrawer;

    switch (selectedAction) {
      case AiHoldQuickAction.camera:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await handleAiCameraCapture(context, ref);
        return;
      case AiHoldQuickAction.photoLibrary:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await handleAiLibraryCapture(context, ref);
        return;
      case AiHoldQuickAction.textInputDrawer:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await handleAiFreeFormText(context, ref);
        return;
      case AiHoldQuickAction.manualEntry:
        await _playQuickActionDualNudge();
        if (!mounted) return;
        await _openManualEntrySheet();
        return;
      case AiHoldQuickAction.recordAudio:
        await _startHoldRecording();
        return;
    }
  }

  Future<void> _startHoldRecording() async {
    if (_isHoldRecording) return;

    try {
      final hasPermission = await _holdRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          AppToast.info(
            context,
            context.l10n.microphonePermissionRequiredForQuickAudioLogging,
          );
        }
        return;
      }

      HapticFeedback.lightImpact();

      if (mounted) {
        setState(() {
          _isHoldRecording = true;
          _isHoldCancelled = false;
          _didCrossCancelThreshold = false;
          _holdDragDeltaX = 0;
          _holdRecordingStartedAt = DateTime.now();
        });
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/moneko_hold_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _holdRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );
      _startHoldAmplitudeProbe();
    } catch (error) {
      _holdAmplitudeTimer?.cancel();
      if (mounted) {
        setState(() {
          _isHoldRecording = false;
          _isHoldCancelled = false;
          _didCrossCancelThreshold = false;
          _holdDragDeltaX = 0;
        });
        AppToast.error(
          context,
          context.l10n.unableToStartRecording(
            ErrorHandler.getUserFriendlyMessage(
              error,
              context: BackendErrorContext.recording,
            ),
          ),
        );
      }
    }
  }

  void _startHoldAmplitudeProbe() {
    _holdRecordingPeakDb = _silentRecordingPeakDb;
    _holdAmplitudeTimer?.cancel();
    _holdAmplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) {
      unawaited(_captureHoldRecordingAmplitude());
    });
  }

  Future<void> _captureHoldRecordingAmplitude() async {
    try {
      final amp = await _holdRecorder.getAmplitude();
      final peak = max(amp.current, amp.max);
      if (peak > _holdRecordingPeakDb) {
        _holdRecordingPeakDb = peak;
      }
    } catch (_) {}
  }

  void _applyHoldDragDelta(double deltaX) {
    if (!_isHoldRecording) return;

    final shouldCancel = deltaX.abs() >= _recordCancelDragThreshold;
    final crossedIntoCancelArea = shouldCancel && !_didCrossCancelThreshold;
    final movedOutOfCancelArea = !shouldCancel && _didCrossCancelThreshold;

    if (crossedIntoCancelArea) {
      HapticFeedback.mediumImpact();
    }

    if (!mounted) return;
    setState(() {
      _holdDragDeltaX = deltaX;
      _isHoldCancelled = shouldCancel;
      if (crossedIntoCancelArea) {
        _didCrossCancelThreshold = true;
      } else if (movedOutOfCancelArea) {
        _didCrossCancelThreshold = false;
      }
    });
  }

  void _updateHoldRecordingDrag(LongPressMoveUpdateDetails details) {
    _applyHoldDragDelta(details.offsetFromOrigin.dx);
  }

  void _onHoldPointerMove(PointerMoveEvent event) {
    final startX = _holdStartGlobalX;
    if (startX == null || !_isHoldRecording) {
      return;
    }
    _applyHoldDragDelta(event.position.dx - startX);
  }

  Future<void> _finishHoldRecording() async {
    if (!_isHoldRecording) return;

    final wasCancelled = _isHoldCancelled;
    final startedAt = _holdRecordingStartedAt;

    if (mounted) {
      setState(() {
        _isHoldRecording = false;
        _isHoldCancelled = false;
        _didCrossCancelThreshold = false;
        _holdDragDeltaX = 0;
        _holdStartGlobalX = null;
        _holdRecordingStartedAt = null;
      });
    }

    File? audioFile;
    try {
      await _captureHoldRecordingAmplitude();
      _holdAmplitudeTimer?.cancel();
      final path = await _holdRecorder.stop();
      if (path == null) return;
      audioFile = File(path);

      if (wasCancelled) {
        HapticFeedback.selectionClick();
        return;
      }

      if (startedAt != null &&
          DateTime.now().difference(startedAt).inMilliseconds <
              _minimumHoldRecordingMs) {
        if (mounted) {
          AppToast.error(context, context.l10n.recordingTooShort);
        }
        return;
      }

      final hasVoiceInput = _holdRecordingPeakDb > _minimumVoicePeakDb;
      if (!hasVoiceInput) {
        if (mounted) {
          AppToast.error(context, context.l10n.recordingIsEmpty);
        }
        return;
      }

      if (!await audioFile.exists()) {
        if (mounted) {
          AppToast.error(context, context.l10n.recordingFileMissing);
        }
        return;
      }

      final bytes = await audioFile.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          AppToast.error(context, context.l10n.recordingIsEmpty);
        }
        return;
      }

      HapticFeedback.lightImpact();
      if (!mounted) return;
      await handleAiAudioBytes(
        context,
        ref,
        audioBytes: bytes,
        contentType: 'audio/aac',
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.unableToProcessRecording(
            ErrorHandler.getUserFriendlyMessage(
              error,
              context: BackendErrorContext.recording,
            ),
          ),
        );
      }
    } finally {
      if (audioFile != null) {
        try {
          if (await audioFile.exists()) {
            await audioFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  Widget _buildContextPill(ColorScheme colorScheme) {
    return _FabContextPill(
      colorScheme: colorScheme,
      isFabOpen: _isFabOpen,
    );
  }

  Widget _buildHoldRecordingIndicator(ColorScheme colorScheme) {
    final dragProgress = (_holdDragDeltaX.abs() / _recordCancelDragThreshold)
        .clamp(0.0, 1.0)
        .toDouble();
    final indicatorBackground = _isHoldCancelled
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHigh;

    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 120),
        offset: _isHoldRecording ? Offset.zero : const Offset(0.25, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _isHoldRecording ? 1 : 0,
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: indicatorBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHoldCancelled
                    ? colorScheme.error
                    : colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _isHoldRecording
                      ? _FabAudioWave(colorScheme: colorScheme)
                      : _FabAudioWavePlaceholder(colorScheme: colorScheme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isHoldCancelled
                        ? context.l10n.releaseToCancel
                        : context.l10n.slideRightToCancel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isHoldCancelled
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  duration: const Duration(milliseconds: 110),
                  scale: _isHoldCancelled ? 1.14 : 1.0,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 110),
                    turns: _isHoldCancelled ? 0.03 : 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      transform: Matrix4.translationValues(
                        (_holdDragDeltaX.sign * (dragProgress * 8)),
                        0,
                        0,
                      ),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.error.withValues(
                          alpha: 0.08 + (dragProgress * 0.22),
                        ),
                        border: Border.all(
                          color: colorScheme.error.withValues(
                            alpha: 0.15 + (dragProgress * 0.55),
                          ),
                        ),
                        boxShadow: _isHoldCancelled
                            ? [
                                BoxShadow(
                                  color:
                                      colorScheme.error.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: colorScheme.error.withValues(
                          alpha: 0.45 + (dragProgress * 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        _buildContextPill(colorScheme),
        ExpandableFab(
          key: _fabKey,
          distance: 120,
          onToggle: (isOpen) {
            if (mounted) {
              setState(() {
                _isFabOpen = isOpen;
              });
            }
          },
          openButtonBuilder: (context, defaultButton) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerMove: _onHoldPointerMove,
              onPointerUp: (_) {
                if (_isHoldRecording) {
                  unawaited(_finishHoldRecording());
                }
              },
              onPointerCancel: (_) {
                if (_isHoldRecording) {
                  unawaited(_finishHoldRecording());
                }
              },
              child: RawGestureDetector(
                gestures: {
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(
                      duration: const Duration(milliseconds: 280),
                    ),
                    (instance) {
                      instance
                        ..onLongPressStart = (details) async {
                          _holdStartGlobalX = details.globalPosition.dx;
                          await _runHoldAction();
                        }
                        ..onLongPressMoveUpdate = _updateHoldRecordingDrag
                        ..onLongPressEnd = (_) async {
                          await _finishHoldRecording();
                        }
                        ..onLongPressUp = () async {
                          await _finishHoldRecording();
                        };
                    },
                  ),
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerRight,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: _isHoldRecording ? 1.08 : 1.0,
                      child: defaultButton,
                    ),
                    Positioned(
                      right: 66,
                      child: _buildHoldRecordingIndicator(colorScheme),
                    ),
                  ],
                ),
              ),
            );
          },
          children: [
            ActionButton(
              onPressed: () async {
                _fabKey.currentState?.close();
                await handleAiFreeFormText(context, ref);
              },
              icon: Image.asset(
                'lib/assets/images/audio-message.png',
                width: 25,
                height: 25,
              ),
              label: context.l10n.textAudio,
            ),
            ActionButton(
              onPressed: () async {
                _fabKey.currentState?.close();
                await handleAiCameraCapture(context, ref);
              },
              icon: const Icon(Icons.camera_alt),
              label: context.l10n.takePhoto,
            ),
            ActionButton(
              onPressed: () async {
                _fabKey.currentState?.close();
                await handleAiFileOrGallery(context, ref);
              },
              icon: const Icon(Icons.attach_file),
              label: context.l10n.files,
            ),
          ],
        ),
      ],
    );
  }
}

class _FabContextPill extends ConsumerWidget {
  const _FabContextPill({
    required this.colorScheme,
    required this.isFabOpen,
  });

  final ColorScheme colorScheme;
  final bool isFabOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdId = _resolveHouseholdIdForAi(ref);
    final targetLabel = _resolveLogTargetLabel(context, ref);
    final preferredCurrency = ref.watch(
      appUserContactProvider.select((contact) => contact?.preferredCurrency),
    );
    final selectedCurrency = ref.watch(
      homeFilterProvider.select((state) => state.selectedCurrency),
    );
    final displayCurrency =
        (selectedCurrency ?? preferredCurrency ?? 'USD').trim().toUpperCase();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastLinearToSlowEaseIn,
      bottom: 12,
      right: isFabOpen ? 72 : 24,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isFabOpen ? 1.0 : 0.0,
        curve: Curves.easeOut,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: isFabOpen ? 1.0 : 0.9,
          curve: Curves.fastLinearToSlowEaseIn,
          alignment: Alignment.centerRight,
          child: IgnorePointer(
            ignoring: !isFabOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.7),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        householdId == null
                            ? Icons.person_outline
                            : Icons.people_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$targetLabel • $displayCurrency',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FabAudioWave extends StatefulWidget {
  const _FabAudioWave({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  State<_FabAudioWave> createState() => _FabAudioWaveState();
}

class _FabAudioWaveState extends State<_FabAudioWave> {
  late final List<double> _bars;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bars = List<double>.filled(10, 0.25);
    _timer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _bars.length; i++) {
          final phase = DateTime.now().millisecondsSinceEpoch / 150 + i;
          final value = 0.15 + (sin(phase).abs() * 0.85);
          _bars[i] = value.clamp(0.12, 1.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(_bars.length, (index) {
          final barHeight = 4 + (_bars[index] * 13);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            width: 2.4,
            height: barHeight,
            decoration: BoxDecoration(
              color: widget.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

class _FabAudioWavePlaceholder extends StatelessWidget {
  const _FabAudioWavePlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(10, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            width: 2.4,
            height: 7,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
