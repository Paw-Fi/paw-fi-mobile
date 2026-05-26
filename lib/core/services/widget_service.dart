import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static const String _appGroupId = 'group.moneko.mobile';
  static const String _androidWidgetName = 'MonekoWidgetProvider';
  static const String _iOSWidgetName = 'MonekoWidget';
  static const String _iOSTopCategoriesWidgetName = 'MonekoTopCategoriesWidget';

  Future<void> _ensureAppGroupIdSet() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  Future<void> saveSelectedWidgetCurrency(String currency) async {
    try {
      await _ensureAppGroupIdSet();
      await HomeWidget.saveWidgetData<String>(
        'selected_widget_currency',
        normalizeHomeWidgetCurrency(currency),
      );
    } catch (e) {
      debugPrint('Error saving selected widget currency: $e');
    }
  }

  Future<void> reloadWidgets() async {
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      iOSName: _iOSTopCategoriesWidgetName,
    );
  }

  Future<void> updateWidgetData({
    required double totalSpent,
    required double totalBudget,
    double? remainingBudget,
    double? budgetProgress,
    required String currency,
    required List<WidgetPocketData> pockets,
    bool shouldReloadWidgets = true,
  }) async {
    try {
      // Ensure App Group ID is set
      await _ensureAppGroupIdSet();

      // Format currency
      final currencyFormat = NumberFormat.simpleCurrency(name: currency);
      final spentStr = currencyFormat.format(totalSpent);
      final budgetStr = currencyFormat.format(totalBudget);
      final remaining = remainingBudget ?? (totalBudget - totalSpent);
      final remainingStr = currencyFormat.format(remaining);

      // Calculate progress
      final progress = budgetProgress ??
          (totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0);

      // Save Summary Data
      await HomeWidget.saveWidgetData<String>('total_spent', spentStr);
      await HomeWidget.saveWidgetData<String>('total_budget', budgetStr);
      await HomeWidget.saveWidgetData<String>('remaining_budget', remainingStr);
      await HomeWidget.saveWidgetData<double>('budget_progress', progress);
      await HomeWidget.saveWidgetData<String>(
        'legacy_widget_currency',
        currency.trim().toUpperCase(),
      );

      // Save Pockets Data (JSON)
      final pocketsJson = jsonEncode(pockets.map((p) => p.toJson()).toList());
      await HomeWidget.saveWidgetData<String>('pockets_data', pocketsJson);

      if (shouldReloadWidgets) {
        await reloadWidgets();
      }

      debugPrint('✅ Widget data updated: $spentStr / $budgetStr');
    } catch (e) {
      debugPrint('❌ Failed to update widget data: $e');
    }
  }

  /// Updates the widget data for a specific scope and currency
  Future<void> updateWidgetDataWithScope({
    required String scopeId, // 'personal' or household UUID
    required String currency,
    required double totalSpent,
    required double totalBudget,
    double? remainingBudget,
    required double budgetProgress,
    required List<WidgetPocketData> pockets,
    bool shouldReloadWidgets = true,
  }) async {
    try {
      await _ensureAppGroupIdSet();

      final keySuffix = '${scopeId}_$currency';

      await HomeWidget.saveWidgetData(
          'total_spent_$keySuffix',
          NumberFormat.simpleCurrency(name: currency)
              .format(totalSpent)); // Using NumberFormat directly
      await HomeWidget.saveWidgetData(
          'remaining_budget_$keySuffix',
          NumberFormat.simpleCurrency(name: currency)
              .format(remainingBudget ?? (totalBudget - totalSpent)));
      await HomeWidget.saveWidgetData(
          'budget_progress_$keySuffix', budgetProgress);

      final pocketsJson = jsonEncode(pockets.map((e) => e.toJson()).toList());
      await HomeWidget.saveWidgetData('pockets_data_$keySuffix', pocketsJson);

      if (shouldReloadWidgets) {
        await reloadWidgets();
      }
    } catch (e) {
      debugPrint('Error updating widget data for $scopeId/$currency: $e');
    }
  }

  /// Saves a separate list of \"top categories\" pockets for a scope/currency.
  /// This is used by the optional \"Top Spending\" widget variant, while the
  /// primary widget uses the main pockets list for budget envelopes.
  Future<void> saveTopCategoriesForScope({
    required String scopeId,
    required String currency,
    required List<WidgetPocketData> pockets,
    bool shouldReloadWidgets = true,
  }) async {
    try {
      await _ensureAppGroupIdSet();

      final keySuffix = '${scopeId}_$currency';
      final pocketsJson = jsonEncode(pockets.map((e) => e.toJson()).toList());
      await HomeWidget.saveWidgetData('top_categories_$keySuffix', pocketsJson);

      if (shouldReloadWidgets) {
        await reloadWidgets();
      }
    } catch (e) {
      debugPrint('Error saving top categories for $scopeId/$currency: $e');
    }
  }

  Future<void> saveConfigurationOptions({
    required List<Map<String, Object?>> households,
  }) async {
    try {
      await _ensureAppGroupIdSet();

      final householdsJson = jsonEncode(households);

      await HomeWidget.saveWidgetData('config_households', householdsJson);
      // No need to update widget, just saving data for the intent to read
    } catch (e) {
      debugPrint('Error saving config options: $e');
    }
  }

  Future<void> saveWidgetConfiguration({
    required int widgetId,
    required String scopeId,
    required String currency,
  }) async {
    try {
      await _ensureAppGroupIdSet();

      await HomeWidget.saveWidgetData('config_scope_$widgetId', scopeId);
      await HomeWidget.saveWidgetData(
        'config_currency_$widgetId',
        normalizeHomeWidgetCurrency(currency),
      );

      // Trigger update so the widget re-reads the config and loads the correct data
      await reloadWidgets();
    } catch (e) {
      debugPrint('Error saving widget config: $e');
    }
  }
}

String normalizeHomeWidgetCurrency(String? currency) {
  final normalized = currency?.trim().toUpperCase();
  if (normalized == null || normalized.isEmpty) {
    return 'USD';
  }
  return normalized;
}

class WidgetPocketData {
  final String name;
  final double spent;
  final double budget;
  final String color; // Hex string
  final String? currency; // Optional 3-letter code
  final String? icon; // Optional icon identifier (pocket or category key)

  WidgetPocketData({
    required this.name,
    required this.spent,
    required this.budget,
    required this.color,
    this.currency,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'spent': spent,
        'budget': budget,
        'color': color,
        if (currency != null) 'currency': currency,
        if (icon != null) 'icon': icon,
      };

  double get progress {
    if (budget <= 0) return 0.0;
    return (spent / budget).clamp(0.0, 1.0);
  }
}
