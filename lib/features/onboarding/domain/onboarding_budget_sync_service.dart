import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/pockets/presentation/constants/budget_templates.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';

class OnboardingBudgetSyncService {
  static Future<void> createStarterBudget({
    required WidgetRef ref,
    required PocketsScopeParams scopeParams,
    required String userId,
    required String selectedCurrency,
    required double totalBudget,
    required List<PocketTemplate> pockets,
    required Set<String> builtinCategoryNames,
  }) async {
    final month = scopeParams.periodMonth ?? DateTime.now();
    final monthStart = DateTime(month.year, month.month, 1);
    final periodMonth = _formatDate(monthStart);
    final householdId = scopeParams.scope == PocketsScopeType.personal
        ? null
        : scopeParams.householdId;
    final nowIso = DateTime.now().toIso8601String();

    String? budgetId = await _findBudgetId(
      periodMonth: periodMonth,
      userId: userId,
      scope: scopeParams.scope,
      householdId: householdId,
    );

    final budgetPayload = <String, dynamic>{
      'user_id': userId,
      'household_id': householdId,
      'currency': selectedCurrency,
      'period_month': periodMonth,
      'total_budget_cents': (totalBudget * 100).round(),
      'updated_at': nowIso,
    };

    if (budgetId != null) {
      await supabase.from('budgets').update(budgetPayload).eq('id', budgetId);
    } else {
      try {
        final response = await supabase
            .from('budgets')
            .insert(budgetPayload)
            .select('id')
            .single();
        budgetId = response['id'] as String;
      } catch (error) {
        if (!_isConflictError(error)) rethrow;
        budgetId = await _findBudgetId(
          periodMonth: periodMonth,
          userId: userId,
          scope: scopeParams.scope,
          householdId: householdId,
        );
        if (budgetId == null) rethrow;
        await supabase.from('budgets').update(budgetPayload).eq('id', budgetId);
      }
    }

    final persistedBudgetId = budgetId;

    final existingEnvelopeRows = await supabase
        .from('budget_envelopes')
        .select('id')
        .eq('budget_id', persistedBudgetId);
    final existingEnvelopeIds = (existingEnvelopeRows as List?)
            ?.cast<Map<String, dynamic>>()
            .map((row) => row['id'] as String?)
            .whereType<String>()
            .toList() ??
        const <String>[];

    if (existingEnvelopeIds.isNotEmpty) {
      await supabase
          .from('envelope_category_links')
          .delete()
          .inFilter('envelope_id', existingEnvelopeIds);
      await supabase
          .from('envelope_allocations')
          .delete()
          .inFilter('envelope_id', existingEnvelopeIds);
      await supabase
          .from('budget_envelopes')
          .delete()
          .eq('budget_id', persistedBudgetId);
    }

    final linksPayload = <Map<String, dynamic>>[];
    final customCategoryPayload = <Map<String, dynamic>>[];
    for (final template in pockets) {
      final amountCents = (totalBudget * template.weight * 100).round();
      final insertedEnvelope = await supabase
          .from('budget_envelopes')
          .insert(<String, dynamic>{
            'user_id': userId,
            'budget_id': persistedBudgetId,
            'name': template.name,
            'budget_amount_cents': amountCents,
            'household_id': householdId,
            'currency': selectedCurrency,
            'color': template.color != null
                ? '#${(template.color!.r * 255).round().toRadixString(16).padLeft(2, '0')}${(template.color!.g * 255).round().toRadixString(16).padLeft(2, '0')}${(template.color!.b * 255).round().toRadixString(16).padLeft(2, '0')}'
                : null,
            'icon': template.iconName,
            'updated_at': nowIso,
          })
          .select('id')
          .single();

      final envelopeId = insertedEnvelope['id'] as String;

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

      for (final category in template.suggestedCategories) {
        linksPayload.add({
          'envelope_id': envelopeId,
          'category': category.toLowerCase(),
        });
        if (builtinCategoryNames.contains(category.trim().toLowerCase())) {
          continue;
        }
        customCategoryPayload.add({
          'user_id': userId,
          'name': category.toLowerCase(),
          'transaction_type': 'expense',
          'color_argb': template.color?.toARGB32(),
          'icon_key': _iconKeyForPocketIcon(template.iconName),
        });
      }
    }

    if (linksPayload.isNotEmpty) {
      await supabase.from('envelope_category_links').insert(linksPayload);
    }

    if (customCategoryPayload.isNotEmpty) {
      await supabase.from('user_transaction_categories').upsert(
            customCategoryPayload,
            onConflict: 'user_id,name,transaction_type',
          );
    }

    ref.invalidate(pocketsProvider(scopeParams));
    ref.read(analyticsProvider.notifier).refresh(userId);
    ref.read(widgetSyncVersionProvider.notifier).state++;
  }

  static Future<String?> _findBudgetId({
    required String periodMonth,
    required String userId,
    required PocketsScopeType scope,
    required String? householdId,
  }) async {
    var query =
        supabase.from('budgets').select('id').eq('period_month', periodMonth);

    switch (scope) {
      case PocketsScopeType.personal:
        query = query.eq('user_id', userId).isFilter('household_id', null);
        break;
      case PocketsScopeType.portfolio:
      case PocketsScopeType.household:
        query = query.eq('household_id', householdId!);
        break;
    }

    final row = await query.limit(1).maybeSingle();
    return row?['id'] as String?;
  }

  static bool _isConflictError(Object error) {
    return error is PostgrestException &&
        (error.code == '23505' || error.code == '409');
  }
}

String _iconKeyForPocketIcon(String? iconName) {
  return switch ((iconName ?? '').trim()) {
    'house' => 'apartment',
    'bolt' => 'bolt',
    'credit_card' => 'card',
    'savings' => 'savings',
    'groups' => 'people',
    'child_care' => 'child',
    'local_grocery_store' => 'grocery',
    'restaurant' => 'restaurant',
    'directions_car' => 'car',
    'subscriptions' => 'tv',
    'pets' => 'pet',
    'flight' => 'plane',
    'calendar_today' => 'bill',
    'coffee' => 'coffee',
    'celebration' => 'party',
    'account_balance_wallet' => 'bank',
    _ => 'tag',
  };
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
