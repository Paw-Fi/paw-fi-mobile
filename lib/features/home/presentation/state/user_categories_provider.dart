import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_style_overrides.dart';

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
  if (name.length > 48) return false;
  final allowed = RegExp(r'^[a-z0-9 &/._-]+$');
  if (!allowed.hasMatch(name)) return false;
  if (name.contains('`')) return false;
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
    await supabase.from('user_transaction_categories').upsert(
      <String, dynamic>{
        'user_id': user.uid,
        'name': trimmed,
        'transaction_type': transactionType,
        'color_argb': colorArgb ?? computeFallbackCategoryColorArgb(trimmed),
        'icon_key': (iconKey != null && iconKey.trim().isNotEmpty)
            ? iconKey.trim()
            : 'tag',
      },
      onConflict: 'user_id,name,transaction_type',
    );
  } catch (_) {
    return null;
  }

  ref.invalidate(userCategoryConfigProvider);
  ref.invalidate(userCategoryListsProvider);
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
    if (hidden) {
      await supabase.from('user_hidden_transaction_categories').upsert(
        <String, dynamic>{
          'user_id': user.uid,
          'category_name': name,
          'transaction_type': type,
        },
        onConflict: 'user_id,category_name,transaction_type',
      );
    } else {
      await supabase
          .from('user_hidden_transaction_categories')
          .delete()
          .eq('user_id', user.uid)
          .eq('category_name', name)
          .eq('transaction_type', type);
    }
  } catch (_) {
    return false;
  }

  ref.invalidate(userCategoryConfigProvider);
  ref.invalidate(userCategoryListsProvider);
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
    await supabase
        .from('user_transaction_categories')
        .delete()
        .eq('user_id', user.uid)
        .eq('name', normalized)
        .eq('transaction_type', type);

    await supabase
        .from('user_hidden_transaction_categories')
        .delete()
        .eq('user_id', user.uid)
        .eq('category_name', normalized);
  } catch (_) {
    return false;
  }

  ref.invalidate(userCategoryConfigProvider);
  ref.invalidate(userCategoryListsProvider);
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
    await supabase.from('user_transaction_categories').upsert(
      <String, dynamic>{
        'user_id': user.uid,
        'name': normalized,
        'transaction_type': type,
        'color_argb': colorArgb ?? computeFallbackCategoryColorArgb(normalized),
        'icon_key': (iconKey != null && iconKey.trim().isNotEmpty)
            ? iconKey.trim()
            : 'tag',
      },
      onConflict: 'user_id,name,transaction_type',
    );
  } catch (_) {
    return false;
  }

  ref.invalidate(userCategoryConfigProvider);
  ref.invalidate(userCategoryListsProvider);
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
    await supabase
        .from('user_transaction_categories')
        .update(<String, dynamic>{
          'color_argb': colorArgb,
          'icon_key': iconKey.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.uid)
        .eq('name', normalized)
        .eq('transaction_type', type);
  } catch (_) {
    return false;
  }

  ref.invalidate(userCategoryConfigProvider);
  ref.invalidate(userCategoryListsProvider);
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
  if (newType != 'expense' && newType != 'income') {
    return false;
  }

  int? preservedColorArgb;
  String? preservedIconKey;

  try {
    try {
      final oldRow = await supabase
          .from('user_transaction_categories')
          .select('color_argb,icon_key')
          .eq('user_id', user.uid)
          .eq('name', oldNormalized)
          .eq('transaction_type', oldType)
          .maybeSingle();

      final colorRaw = oldRow?['color_argb'];
      final iconRaw = oldRow?['icon_key'];
      if (colorRaw is num) preservedColorArgb = colorRaw.toInt();
      if (iconRaw is String && iconRaw.trim().isNotEmpty) {
        preservedIconKey = iconRaw.trim();
      }
    } catch (_) {}

    await supabase.from('user_transaction_categories').upsert(
      <String, dynamic>{
        'user_id': user.uid,
        'name': newNormalized,
        'transaction_type': newType,
        'color_argb': preservedColorArgb ??
            computeFallbackCategoryColorArgb(newNormalized),
        'icon_key': (preservedIconKey != null && preservedIconKey.isNotEmpty)
            ? preservedIconKey
            : 'tag',
      },
      onConflict: 'user_id,name,transaction_type',
    );

    if (oldNormalized != newNormalized || oldType != newType) {
      await supabase
          .from('user_transaction_categories')
          .delete()
          .eq('user_id', user.uid)
          .eq('name', oldNormalized)
          .eq('transaction_type', oldType);

      await supabase
          .from('user_hidden_transaction_categories')
          .delete()
          .eq('user_id', user.uid)
          .eq('category_name', oldNormalized);
    }
  } catch (_) {
    return false;
  }

  ref.invalidate(userCategoryConfigProvider);
  ref.invalidate(userCategoryListsProvider);
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

  return saveUserCategoryRemapPreferenceForUser(
    userId: user.uid,
    fromCategory: fromCategory,
    toCategory: toCategory,
    transactionType: transactionType,
  );
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

  if (typeNormalized != 'expense' && typeNormalized != 'income') return false;
  if (!_isValidCategoryName(fromNormalized) ||
      !_isValidCategoryName(toNormalized)) {
    return false;
  }
  if (fromNormalized == toNormalized) return false;
  if (_isUnhidableCategory(fromNormalized)) return false;
  if (toNormalized == 'other') return false;

  int nextUseCount = 1;
  try {
    final existing = await supabase
        .from('user_category_remaps')
        .select('use_count')
        .eq('user_id', userId)
        .eq('transaction_type', typeNormalized)
        .eq('from_category_name', fromNormalized)
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
        'transaction_type': typeNormalized,
        'from_category_name': fromNormalized,
        'to_category_name': toNormalized,
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
