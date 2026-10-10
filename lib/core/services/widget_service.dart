import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/services/home_widget_snapshot.dart';

class WidgetService {
  static const String _appGroupId = 'group.moneko.mobile';
  static const MethodChannel _shortcutChannel =
      MethodChannel('moneko/siri_shortcut_auth');
  static const MethodChannel _androidChannel = MethodChannel('moneko/widgets');
  static const String _androidWidgetName = 'MonekoWidgetProvider';
  static const String _iOSWidgetName = 'MonekoWidget';
  static const String _iOSTopCategoriesWidgetName = 'MonekoTopCategoriesWidget';
  static Future<void> _writes = Future<void>.value();

  /// Serializes account transitions with publication in this Flutter engine.
  static Future<void> _write(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.catchError((Object error, StackTrace stack) {
      debugPrint('Home widget storage failed: ${error.runtimeType}');
    });
    return next;
  }

  Future<void> synchronizeOwner(String userId, {bool Function()? isCurrent}) =>
      _write(() async {
        if (isCurrent?.call() == false) return;
        await _ensureAppGroupIdSet();
        final previous =
            await HomeWidget.getWidgetData<String>('widget_user_id');
        if (previous == userId || isCurrent?.call() == false) return;
        // Readers reject previous-account snapshots immediately. Keep instance
        // configuration so existing widgets survive updates and sign-in.
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _androidChannel.invokeMethod<void>('synchronizeOwner', userId);
        } else {
          await HomeWidget.saveWidgetData('widget_user_id', userId);
          await HomeWidget.saveWidgetData('selected_widget_currency', null);
        }
        await reloadWidgets();
      });

  Future<bool> publishSnapshot({
    required String scopeId,
    required HomeWidgetSnapshot snapshot,
    required bool Function() isCurrent,
  }) async {
    var published = false;
    await _write(() async {
      if (!isCurrent()) return;
      await _ensureAppGroupIdSet();
      final owner = await HomeWidget.getWidgetData<String>('widget_user_id');
      if (owner != snapshot.userId || !isCurrent()) return;
      final key = 'widget_snapshot_${scopeId}_${snapshot.currency}';
      final data = snapshot.toJson();
      if (snapshot.topCategories == null) {
        final previous = await HomeWidget.getWidgetData<String>(key);
        if (previous != null) {
          try {
            final decoded = jsonDecode(previous) as Map<String, dynamic>;
            if (decoded['userId'] == snapshot.userId &&
                decoded['currency'] == snapshot.currency &&
                decoded['periodMonth'] == snapshot.periodMonth &&
                decoded['topCategories'] is List) {
              data['topCategories'] = decoded['topCategories'];
            }
          } on FormatException {
            debugPrint('Discarding malformed previous widget snapshot');
          } on TypeError {
            debugPrint('Discarding invalid previous widget snapshot');
          }
        }
      }
      if (!isCurrent()) return;
      data['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      // Native readers use this single JSON write, never partial scalar keys.
      if (defaultTargetPlatform == TargetPlatform.android) {
        published =
            await _androidChannel.invokeMethod<bool>('publishSnapshot', {
                  'userId': snapshot.userId,
                  'key': key,
                  'snapshot': jsonEncode(data),
                  'currency': snapshot.currency,
                }) ??
                false;
      } else {
        published =
            await HomeWidget.saveWidgetData(key, jsonEncode(data)) == true;
      }
      if (!published) throw StateError('Widget snapshot was not saved');
      if (!isCurrent()) return;
      await HomeWidget.saveWidgetData(
          'selected_widget_currency', snapshot.currency);
      await reloadWidgets();
    });
    return published;
  }

  Future<void> saveBackgroundRefreshContext(Map<String, Object?> settings) =>
      _write(() async {
        if (defaultTargetPlatform != TargetPlatform.android) return;
        await _androidChannel.invokeMethod<void>('configureRefresh', {
          'userId': settings['userId'],
          'context': jsonEncode(settings),
        });
      });

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
      debugPrint('Widget currency save failed: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> reloadWidgets() async {
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await HomeWidget.updateWidget(iOSName: _iOSTopCategoriesWidgetName);
    }
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
    } catch (e) {
      debugPrint('Home widget data save failed: ${e.runtimeType}');
      rethrow;
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
      debugPrint('Scoped widget data save failed: ${e.runtimeType}');
      rethrow;
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
      debugPrint('Widget category save failed: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> saveConfigurationOptions({
    required String userId,
    required List<Map<String, Object?>> households,
    required List<Map<String, Object?>> wallets,
  }) async {
    try {
      await _ensureAppGroupIdSet();

      final householdsJson = jsonEncode(households);
      final walletsJson = jsonEncode(wallets);

      await HomeWidget.saveWidgetData('config_households', householdsJson);
      await HomeWidget.saveWidgetData('config_wallets', walletsJson);
      await HomeWidget.saveWidgetData(
        'shortcut_destination_catalog_user_id',
        userId,
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _shortcutChannel.invokeMethod<void>('refreshDestinationCatalog');
      }
    } catch (e) {
      debugPrint('Home widget configuration catalog failed: ${e.runtimeType}');
    }
  }

  Future<void> saveWidgetConfiguration({
    required int widgetId,
    required String scopeId,
    required String currency,
  }) async {
    await _ensureAppGroupIdSet();

    await HomeWidget.saveWidgetData('config_scope_$widgetId', scopeId);
    await HomeWidget.saveWidgetData(
      'config_currency_$widgetId',
      normalizeHomeWidgetCurrency(currency),
    );

    // Trigger update so the widget re-reads the config and loads the correct data
    await reloadWidgets();
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
  final String? id;
  final String name;
  final double spent;
  final double budget;
  final String color; // Hex string
  final String? currency; // Optional 3-letter code
  final String? icon; // Optional icon identifier (pocket or category key)

  WidgetPocketData({
    this.id,
    required this.name,
    required this.spent,
    required this.budget,
    required this.color,
    this.currency,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
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
