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

  Future<void> updateWidgetData({
    required double totalSpent,
    required double totalBudget,
    required String currency,
    required List<WidgetPocketData> pockets,
  }) async {
    try {
      // Ensure App Group ID is set
      await _ensureAppGroupIdSet();

      // Format currency
      final currencyFormat = NumberFormat.simpleCurrency(name: currency);
      final spentStr = currencyFormat.format(totalSpent);
      final budgetStr = currencyFormat.format(totalBudget);
      final remaining = totalBudget - totalSpent;
      final remainingStr = currencyFormat.format(remaining);

      // Calculate progress
      double progress = 0.0;
      if (totalBudget > 0) {
        progress = (totalSpent / totalBudget).clamp(0.0, 1.0);
      }

      // Save Summary Data
      await HomeWidget.saveWidgetData<String>('total_spent', spentStr);
      await HomeWidget.saveWidgetData<String>('total_budget', budgetStr);
      await HomeWidget.saveWidgetData<String>('remaining_budget', remainingStr);
      await HomeWidget.saveWidgetData<double>('budget_progress', progress);

      // Save Pockets Data (JSON)
      final pocketsJson = jsonEncode(pockets.map((p) => p.toJson()).toList());
      await HomeWidget.saveWidgetData<String>('pockets_data', pocketsJson);

      // Update Widgets
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSTopCategoriesWidgetName,
      );

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
    required double budgetProgress,
    required List<WidgetPocketData> pockets,
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
              .format(totalBudget - totalSpent)); // Using NumberFormat directly
      await HomeWidget.saveWidgetData(
          'budget_progress_$keySuffix', budgetProgress);

      final pocketsJson = jsonEncode(pockets.map((e) => e.toJson()).toList());
      await HomeWidget.saveWidgetData('pockets_data_$keySuffix', pocketsJson);

      await HomeWidget.updateWidget(
        name: _androidWidgetName, // Use class constant
        iOSName: _iOSWidgetName, // Use class constant
      );
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSTopCategoriesWidgetName,
      );
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
  }) async {
    try {
      await _ensureAppGroupIdSet();

      final keySuffix = '${scopeId}_$currency';
      final pocketsJson = jsonEncode(pockets.map((e) => e.toJson()).toList());
      await HomeWidget.saveWidgetData('top_categories_$keySuffix', pocketsJson);

      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSTopCategoriesWidgetName,
      );
    } catch (e) {
      debugPrint('Error saving top categories for $scopeId/$currency: $e');
    }
  }

  Future<void> saveConfigurationOptions({
    required List<Map<String, String>> households, // id, name
    required List<String> currencies,
  }) async {
    try {
      await _ensureAppGroupIdSet();

      final householdsJson = jsonEncode(households);
      final currenciesJson = jsonEncode(currencies);

      await HomeWidget.saveWidgetData('config_households', householdsJson);
      await HomeWidget.saveWidgetData('config_currencies', currenciesJson);
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
      await HomeWidget.saveWidgetData('config_currency_$widgetId', currency);

      // Trigger update so the widget re-reads the config and loads the correct data
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrint('Error saving widget config: $e');
    }
  }
}

class WidgetPocketData {
  final String name;
  final double spent;
  final double budget;
  final String color; // Hex string
  final String? currency; // Optional 3-letter code

  WidgetPocketData({
    required this.name,
    required this.spent,
    required this.budget,
    required this.color,
    this.currency,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'spent': spent,
        'budget': budget,
        'color': color,
        if (currency != null) 'currency': currency,
      };

  double get progress {
    if (budget <= 0) return 0.0;
    return (spent / budget).clamp(0.0, 1.0);
  }
}
