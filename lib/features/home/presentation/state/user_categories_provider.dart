import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_style_overrides.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

class UserCategoryLists {
  const UserCategoryLists({
    required this.expenseCategories,
    required this.incomeCategories,
  });

  final List<String> expenseCategories;
  final List<String> incomeCategories;
}

class UserCustomCategory {
  const UserCustomCategory({
    required this.name,
    required this.transactionType,
    required this.colorArgb,
    required this.iconKey,
  });

  final String name;

  /// 'expense' | 'income'
  final String transactionType;

  /// Optional persisted style overrides (ARGB int, Material icon key)
  final int? colorArgb;
  final String? iconKey;
}

class UserCategoryConfig {
  const UserCategoryConfig({
    required this.visibleExpenseCategories,
    required this.visibleIncomeCategories,
    required this.hiddenExpenseCategories,
    required this.hiddenIncomeCategories,
    required this.customCategories,
  });

  final List<String> visibleExpenseCategories;
  final List<String> visibleIncomeCategories;
  final Set<String> hiddenExpenseCategories;
  final Set<String> hiddenIncomeCategories;
  final List<UserCustomCategory> customCategories;
}

String _normalizeCategoryName(String raw) {
  return raw.trim().toLowerCase();
}

bool _isUnhidableCategory(String normalized) {
  return normalized == 'other' || normalized == 'uncategorized';
}

void _refreshCategoryDependentState({
  required WidgetRef ref,
  required String userId,
  bool refreshTransactions = true,
}) {
  ref.invalidate(userCategoryConfigProvider);
  ref.invalidate(userCategoryListsProvider);

  if (!refreshTransactions) {
    return;
  }

  ref.read(analyticsProvider.notifier).refresh(userId);
  ref.invalidate(pocketsProvider);
  ref.invalidate(currencyTransactionCountsProvider);
  ref.invalidate(recurringTransactionsProvider);
  ref.invalidate(recurringExpensesProvider);
  ref.invalidate(recurringIncomesProvider);

  ref.read(cacheInvalidatorProvider).invalidateAll();
  ref.invalidate(userHouseholdsProvider(userId));
  ref.invalidate(householdExpensesProvider);
  ref.invalidate(cachedHouseholdExpensesProvider);
  ref.invalidate(householdSplitsProvider);
  ref.invalidate(cachedHouseholdSplitsProvider);
  ref.invalidate(householdBudgetsProvider);
  ref.invalidate(householdMembersProvider);
}

final userCategoryConfigProvider =
    FutureProvider<UserCategoryConfig>((ref) async {
  final user = ref.watch(authProvider);

  final baseExpense = getExpenseCategories();
  final baseIncome = getIncomeCategories();

  if (user.uid.isEmpty) {
    setCustomCategoryStyleOverrides(<String, CustomCategoryStyle>{});
    return UserCategoryConfig(
      visibleExpenseCategories: baseExpense,
      visibleIncomeCategories: baseIncome,
      hiddenExpenseCategories: <String>{},
      hiddenIncomeCategories: <String>{},
      customCategories: const <UserCustomCategory>[],
    );
  }

  final rowsFuture = supabase
      .from('user_transaction_categories')
      .select('name,transaction_type,color_argb,icon_key')
      .eq('user_id', user.uid)
      .order('updated_at', ascending: false);

  final hiddenFuture = supabase
      .from('user_hidden_transaction_categories')
      .select('category_name,transaction_type')
      .eq('user_id', user.uid)
      .order('updated_at', ascending: false);

  final results = await Future.wait([rowsFuture, hiddenFuture]);
  final rows = results[0] as List;
  final hiddenRows = results[1] as List;

  final expenseSet = <String>{...baseExpense};
  final incomeSet = <String>{...baseIncome};

  final customCategories = <UserCustomCategory>[];
  final styleOverrides = <String, CustomCategoryStyle>{};

  for (final row in rows.cast<Map<String, dynamic>>()) {
    final name = _normalizeCategoryName(row['name'] as String? ?? '');
    if (name.isEmpty || name == 'other') continue;

    final type =
        _normalizeCategoryName(row['transaction_type'] as String? ?? '');
    final transactionType = switch (type) {
      'income' || 'expense' => type,
      _ => 'expense',
    };

    final colorArgbRaw = row['color_argb'];
    final iconKeyRaw = row['icon_key'];
    final int? colorArgb = colorArgbRaw is num ? colorArgbRaw.toInt() : null;
    final String? iconKey = iconKeyRaw is String && iconKeyRaw.trim().isNotEmpty
        ? iconKeyRaw.trim()
        : null;

    if (colorArgb != null || iconKey != null) {
      styleOverrides[name] = CustomCategoryStyle(
        colorArgb: colorArgb,
        iconKey: iconKey,
      );
    }

    customCategories.add(
      UserCustomCategory(
        name: name,
        transactionType: transactionType,
        colorArgb: colorArgb,
        iconKey: iconKey,
      ),
    );

    switch (transactionType) {
      case 'income':
        incomeSet.add(name);
        break;
      case 'expense':
      default:
        expenseSet.add(name);
        break;
    }
  }

  final hiddenExpense = <String>{};
  final hiddenIncome = <String>{};

  for (final row in hiddenRows.cast<Map<String, dynamic>>()) {
    final name = _normalizeCategoryName(row['category_name'] as String? ?? '');
    if (name.isEmpty || _isUnhidableCategory(name)) continue;

    final type =
        _normalizeCategoryName(row['transaction_type'] as String? ?? '');
    final transactionType = switch (type) {
      'income' || 'expense' => type,
      _ => 'expense',
    };

    switch (transactionType) {
      case 'expense':
        hiddenExpense.add(name);
        break;
      case 'income':
        hiddenIncome.add(name);
        break;
      default:
        // Safety fallback: treat unknown as expense-only
        hiddenExpense.add(name);
        break;
    }
  }

  expenseSet.removeWhere((c) => hiddenExpense.contains(c));
  incomeSet.removeWhere((c) => hiddenIncome.contains(c));

  // Always keep safe fallbacks.
  expenseSet.add('other');
  expenseSet.add('uncategorized');
  incomeSet.add('other');

  final visibleExpense = expenseSet.toList()..sort((a, b) => a.compareTo(b));
  final visibleIncome = incomeSet.toList()..sort((a, b) => a.compareTo(b));

  setCustomCategoryStyleOverrides(styleOverrides);

  return UserCategoryConfig(
    visibleExpenseCategories: visibleExpense,
    visibleIncomeCategories: visibleIncome,
    hiddenExpenseCategories: hiddenExpense,
    hiddenIncomeCategories: hiddenIncome,
    customCategories: customCategories,
  );
});

final userCategoryListsProvider =
    FutureProvider<UserCategoryLists>((ref) async {
  final config = await ref.watch(userCategoryConfigProvider.future);
  return UserCategoryLists(
    expenseCategories: config.visibleExpenseCategories,
    incomeCategories: config.visibleIncomeCategories,
  );
});

bool _isValidCategoryName(String name) {
  if (name.isEmpty) return false;
  if (name.length > 96) return false;
  if (name.contains('`')) return false;
  final hasControlChars = RegExp(r'[\x00-\x1F\x7F]').hasMatch(name);
  if (hasControlChars) return false;
  return true;
}

Future<String?> createUserCustomCategory({
  required WidgetRef ref,
  required String name,
  required bool isIncome,
  int? colorArgb,
  String? iconKey,
}) async {
  final user = ref.read(authProvider);
  final trimmed = _normalizeCategoryName(name);
  if (user.uid.isEmpty || !_isValidCategoryName(trimmed)) return null;

  final transactionType = isIncome ? 'income' : 'expense';

  try {
    final response = await supabase.functions.invoke(
      'manage-user-categories',
      body: <String, dynamic>{
        'action': 'upsert',
        'name': trimmed,
        'transactionType': transactionType,
        'colorArgb': colorArgb ?? computeFallbackCategoryColorArgb(trimmed),
        'iconKey': (iconKey != null && iconKey.trim().isNotEmpty)
            ? iconKey.trim()
            : 'tag',
      },
    );
    final data = response.data;
    if (data is Map && data['success'] != true) return null;
  } catch (error, stackTrace) {
    debugPrint(
      '[createUserCustomCategory] RPC failed: $error\n$stackTrace',
    );
    return null;
  }

  _refreshCategoryDependentState(ref: ref, userId: user.uid);
  return trimmed;
}

Future<bool> setUserCategoryHidden({
  required WidgetRef ref,
  required String categoryName,
  required String transactionType,
  required bool hidden,
}) async {
  final user = ref.read(authProvider);
  if (user.uid.isEmpty) return false;

  final name = _normalizeCategoryName(categoryName);
  final type = _normalizeCategoryName(transactionType);
  if (name.isEmpty || _isUnhidableCategory(name)) return false;
  if (type != 'expense' && type != 'income') return false;
  if (!_isValidCategoryName(name)) return false;

  try {
    final response = await supabase.functions.invoke(
      'manage-user-categories',
      body: <String, dynamic>{
        'action': 'hide',
        'name': name,
        'transactionType': type,
        'hidden': hidden,
      },
    );
    final data = response.data;
    if (data is Map && data['success'] != true) return false;
  } catch (error, stackTrace) {
    debugPrint('[setUserCategoryHidden] RPC failed: $error\n$stackTrace');
    return false;
  }

  _refreshCategoryDependentState(ref: ref, userId: user.uid);
  return true;
}

Future<bool> deleteUserCustomCategory({
  required WidgetRef ref,
  required String name,
  required String transactionType,
}) async {
  final user = ref.read(authProvider);
  if (user.uid.isEmpty) return false;

  final normalized = _normalizeCategoryName(name);
  final type = _normalizeCategoryName(transactionType);
  if (!_isValidCategoryName(normalized)) return false;

  try {
    final response = await supabase.functions.invoke(
      'manage-user-categories',
      body: <String, dynamic>{
        'action': 'delete',
        'name': normalized,
        'transactionType': type,
        'fallbackCategory': 'other',
      },
    );
    final data = response.data;
    if (data is Map && data['success'] != true) return false;
  } catch (error, stackTrace) {
    debugPrint('[deleteUserCustomCategory] RPC failed: $error\n$stackTrace');
    return false;
  }

  _refreshCategoryDependentState(ref: ref, userId: user.uid);
  return true;
}

Future<bool> upsertUserCustomCategory({
  required WidgetRef ref,
  required String name,
  required String transactionType,
  int? colorArgb,
  String? iconKey,
}) async {
  final user = ref.read(authProvider);
  if (user.uid.isEmpty) return false;

  final normalized = _normalizeCategoryName(name);
  final type = _normalizeCategoryName(transactionType);
  if (!_isValidCategoryName(normalized)) return false;
  if (type != 'expense' && type != 'income') return false;
  if (normalized == 'other') return false;

  try {
    final response = await supabase.functions.invoke(
      'manage-user-categories',
      body: <String, dynamic>{
        'action': 'upsert',
        'name': normalized,
        'transactionType': type,
        'colorArgb': colorArgb ?? computeFallbackCategoryColorArgb(normalized),
        'iconKey': (iconKey != null && iconKey.trim().isNotEmpty)
            ? iconKey.trim()
            : 'tag',
      },
    );
    final data = response.data;
    if (data is Map && data['success'] != true) return false;
  } catch (error, stackTrace) {
    debugPrint('[upsertUserCustomCategory] RPC failed: $error\n$stackTrace');
    return false;
  }

  _refreshCategoryDependentState(ref: ref, userId: user.uid);
  return true;
}

Future<bool> setUserCustomCategoryStyle({
  required WidgetRef ref,
  required String name,
  required String transactionType,
  required int colorArgb,
  required String iconKey,
}) async {
  final user = ref.read(authProvider);
  if (user.uid.isEmpty) return false;

  final normalized = _normalizeCategoryName(name);
  final type = _normalizeCategoryName(transactionType);
  if (!_isValidCategoryName(normalized)) return false;
  if (type != 'expense' && type != 'income') return false;
  if (normalized == 'other') return false;
  if (iconKey.trim().isEmpty) return false;

  try {
    final response = await supabase.functions.invoke(
      'manage-user-categories',
      body: <String, dynamic>{
        'action': 'style',
        'name': normalized,
        'transactionType': type,
        'colorArgb': colorArgb,
        'iconKey': iconKey.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['success'] != true) return false;
  } catch (error, stackTrace) {
    debugPrint('[setUserCustomCategoryStyle] RPC failed: $error\n$stackTrace');
    return false;
  }

  final currentOverrides = getCustomCategoryStyleOverrides();
  final nextOverrides = <String, CustomCategoryStyle>{
    ...currentOverrides,
    normalized: CustomCategoryStyle(
      colorArgb: colorArgb,
      iconKey: iconKey.trim(),
    ),
  };
  setCustomCategoryStyleOverrides(nextOverrides);

  _refreshCategoryDependentState(
    ref: ref,
    userId: user.uid,
    refreshTransactions: false,
  );
  return true;
}

Future<bool> renameUserCustomCategory({
  required WidgetRef ref,
  required String oldName,
  required String oldTransactionType,
  required String newName,
  required String newTransactionType,
}) async {
  final user = ref.read(authProvider);
  if (user.uid.isEmpty) return false;

  final oldNormalized = _normalizeCategoryName(oldName);
  final newNormalized = _normalizeCategoryName(newName);
  final oldType = _normalizeCategoryName(oldTransactionType);
  final newType = _normalizeCategoryName(newTransactionType);

  if (!_isValidCategoryName(oldNormalized) ||
      !_isValidCategoryName(newNormalized)) {
    return false;
  }
  if (oldType != 'expense' && oldType != 'income') {
    return false;
  }
  if (newType != 'expense' && newType != 'income') {
    return false;
  }

  try {
    final response = await supabase.functions.invoke(
      'manage-user-categories',
      body: <String, dynamic>{
        'action': 'rename',
        'oldName': oldNormalized,
        'oldTransactionType': oldType,
        'newName': newNormalized,
        'newTransactionType': newType,
      },
    );
    final data = response.data;
    if (data is Map && data['success'] != true) {
      debugPrint(
        '[renameUserCustomCategory] Edge function returned unsuccessful response: $data',
      );
      return false;
    }
  } catch (error, stackTrace) {
    debugPrint(
        '[renameUserCustomCategory] Edge function failed: $error\n$stackTrace');
    return false;
  }

  _refreshCategoryDependentState(ref: ref, userId: user.uid);
  return true;
}

Future<bool> saveUserCategoryRemapPreference({
  required WidgetRef ref,
  required String fromCategory,
  required String toCategory,
  required String transactionType,
}) async {
  final user = ref.read(authProvider);
  if (user.uid.isEmpty) return false;

  final fromNormalized = _normalizeCategoryName(fromCategory);
  final toNormalized = _normalizeCategoryName(toCategory);
  final typeNormalized = _normalizeCategoryName(transactionType);
  if (!_isValidCategoryRemap(
    fromCategory: fromNormalized,
    toCategory: toNormalized,
    transactionType: typeNormalized,
  )) {
    return false;
  }

  final clientMutationId = _categoryRemapClientMutationId(
    userId: user.uid,
    transactionType: typeNormalized,
    fromCategory: fromNormalized,
  );

  try {
    final database = await ref.read(localDatabaseProvider.future);
    await database.saveCategoryRemapPreference(
      userId: user.uid,
      fromCategory: fromNormalized,
      toCategory: toNormalized,
      transactionType: typeNormalized,
      clientMutationId: clientMutationId,
    );

    try {
      final synced = await saveUserCategoryRemapPreferenceForUser(
        userId: user.uid,
        fromCategory: fromNormalized,
        toCategory: toNormalized,
        transactionType: typeNormalized,
      );
      if (synced) {
        await database.markMutationSynced(clientMutationId);
      }
    } catch (_) {
      // The local row and outbox entry already preserve the preference.
    }

    return true;
  } catch (_) {
    return saveUserCategoryRemapPreferenceForUser(
      userId: user.uid,
      fromCategory: fromNormalized,
      toCategory: toNormalized,
      transactionType: typeNormalized,
    );
  }
}

String _categoryRemapClientMutationId({
  required String userId,
  required String transactionType,
  required String fromCategory,
}) {
  final entity = [userId, transactionType, fromCategory]
      .join('_')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  return 'mobile:category_remap_$entity';
}

bool _isValidCategoryRemap({
  required String fromCategory,
  required String toCategory,
  required String transactionType,
}) {
  if (transactionType != 'expense' && transactionType != 'income') return false;
  if (!_isValidCategoryName(fromCategory) ||
      !_isValidCategoryName(toCategory)) {
    return false;
  }
  if (fromCategory == toCategory) return false;
  if (_isUnhidableCategory(fromCategory)) return false;
  if (toCategory == 'other') return false;
  return true;
}

Future<bool> _syncUserCategoryRemapPreferenceToSupabase({
  required String userId,
  required String fromCategory,
  required String toCategory,
  required String transactionType,
}) async {
  int nextUseCount = 1;
  try {
    final existing = await supabase
        .from('user_category_remaps')
        .select('use_count')
        .eq('user_id', userId)
        .eq('transaction_type', transactionType)
        .eq('from_category_name', fromCategory)
        .maybeSingle();
    final existingUseCount = existing?['use_count'];
    if (existingUseCount is num && existingUseCount > 0) {
      nextUseCount = existingUseCount.toInt() + 1;
    }
  } catch (_) {
    nextUseCount = 1;
  }

  try {
    await supabase.from('user_category_remaps').upsert(
      <String, dynamic>{
        'user_id': userId,
        'transaction_type': transactionType,
        'from_category_name': fromCategory,
        'to_category_name': toCategory,
        'use_count': nextUseCount,
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,transaction_type,from_category_name',
    );
  } catch (_) {
    return false;
  }

  return true;
}

Future<bool> saveUserCategoryRemapPreferenceForUser({
  required String userId,
  required String fromCategory,
  required String toCategory,
  required String transactionType,
}) async {
  if (userId.trim().isEmpty) return false;

  final fromNormalized = _normalizeCategoryName(fromCategory);
  final toNormalized = _normalizeCategoryName(toCategory);
  final typeNormalized = _normalizeCategoryName(transactionType);

  if (!_isValidCategoryRemap(
    fromCategory: fromNormalized,
    toCategory: toNormalized,
    transactionType: typeNormalized,
  )) {
    return false;
  }

  return _syncUserCategoryRemapPreferenceToSupabase(
    userId: userId,
    fromCategory: fromNormalized,
    toCategory: toNormalized,
    transactionType: typeNormalized,
  );
}

Future<void> syncUserCategoryRemapsFromSupabase(
  WidgetRef ref, {
  required String userId,
}) async {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) return;

  final rows = await supabase
      .from('user_category_remaps')
      .select(
        'transaction_type,from_category_name,to_category_name,use_count,last_used_at',
      )
      .eq('user_id', normalizedUserId);
  final remaps = <LocalCategoryRemapPreference>[];
  for (final row in rows.cast<Map<String, dynamic>>()) {
    final transactionType = _normalizeCategoryName(
      row['transaction_type']?.toString() ?? '',
    );
    final fromCategory = _normalizeCategoryName(
      row['from_category_name']?.toString() ?? '',
    );
    final toCategory = _normalizeCategoryName(
      row['to_category_name']?.toString() ?? '',
    );
    if (!_isValidCategoryRemap(
      fromCategory: fromCategory,
      toCategory: toCategory,
      transactionType: transactionType,
    )) {
      continue;
    }

    final useCountRaw = row['use_count'];
    final lastUsedAt = DateTime.tryParse(
          row['last_used_at']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    remaps.add(
      LocalCategoryRemapPreference(
        userId: normalizedUserId,
        transactionType: transactionType,
        fromCategory: fromCategory,
        toCategory: toCategory,
        useCount: useCountRaw is num ? useCountRaw.toInt() : 1,
        lastUsedAt: lastUsedAt,
      ),
    );
  }

  if (remaps.isEmpty) return;
  final database = await ref.read(localDatabaseProvider.future);
  await database.upsertCategoryRemapsFromRemote(remaps);
}
