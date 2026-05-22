import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/manage_currencies_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_display_names.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

class CurrencyRatesPage extends ConsumerStatefulWidget {
  const CurrencyRatesPage({super.key});

  @override
  ConsumerState<CurrencyRatesPage> createState() => _CurrencyRatesPageState();
}

class _CurrencyRatesPageState extends ConsumerState<CurrencyRatesPage> {
  String? _baseCurrency;
  double _baseAmount = 1.0;
  List<String>? _shownCurrencies;
  List<String>? _orderedCurrencies;

  static const String _shownCurrenciesKey = 'currency_rates_shown_currencies';
  static const String _orderedCurrenciesKey = 'currency_rates_ordered_currencies';

  @override
  void initState() {
    super.initState();
    _loadShownCurrencies();
  }

  Future<void> _loadShownCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_shownCurrenciesKey);
    final orderedList = prefs.getStringList(_orderedCurrenciesKey);
    if (mounted) {
      setState(() {
        _shownCurrencies = list;
        _orderedCurrencies = orderedList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratesAsync = ref.watch(currencyRateTableProvider);
    final preferredCurrency = ref.watch(selectedHomeCurrencyCodeProvider);
    final homeSelectedCurrencies = ref.watch(homeFilterProvider).normalizedSelectedCurrencies;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.currency,
        actions: [
          if (ratesAsync case AsyncData(:final value))
            AdaptiveAppBarAction(
              onPressed: () {
                final allCodes = value.rates.keys.toList()..sort();
                final sheetCodes = _getManageSheetCodes(allCodes);
                final defaultCodes = _getDefaultShownCodes(preferredCurrency, homeSelectedCurrencies);
                final currentShown = _getShownCodes(defaultCodes, allCodes)
                    .where(sheetCodes.contains)
                    .toList();
                final safeCurrentShown = currentShown.isNotEmpty
                    ? currentShown
                    : (sheetCodes.isNotEmpty ? <String>[sheetCodes.first] : <String>[]);
                _openManageCurrencies(sheetCodes, safeCurrentShown);
              },
              iosSymbol: 'plus',
              icon: Icons.add_rounded,
            ),
        ],
      ),
      body: Padding(
        padding:  EdgeInsets.only(top:getSubPageTopPadding(context)+50),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (ratesAsync) {
            AsyncData(:final value) => _buildRatesContent(
                context,
                colorScheme,
                value,
                preferredCurrency,
                homeSelectedCurrencies,
              ),
            AsyncError(:final error) => Center(
                key: const ValueKey('currency_rates_error'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: colorScheme.destructive,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error.toString(),
                        style: TextStyle(color: colorScheme.destructive),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            _ => const Center(
                key: ValueKey('currency_rates_loading'),
                child: CircularProgressIndicator(),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildRatesContent(
    BuildContext context,
    ColorScheme colorScheme,
    CurrencyRateTable table,
    String preferredCurrency,
    List<String>? homeSelectedCurrencies,
  ) {
    final allCodes = table.rates.keys.toList()..sort();
    final resolvedBase = _resolveBaseCurrency(table, preferredCurrency, allCodes);
    final defaultCodes = _getDefaultShownCodes(resolvedBase, homeSelectedCurrencies);
    final shownCodes = _getShownCodes(defaultCodes, allCodes);
    final orderedCodes = _getOrderedCodes(shownCodes);

    // Formatted timestamp
    final lastUpdatedStr = table.fetchedAt != null
        ? DateFormat.yMMMd().add_Hm().format(table.fetchedAt!.toLocal())
        : '';

    return Column(
      key: const ValueKey('currency_rates_data'),
      children: [
        // Currency Exchange List
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            proxyDecorator: (child, index, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.05,
                  child: child,
                );
              },
              child: child,
            ),
            onReorder: (int oldIndex, int newIndex) async {
              HapticFeedback.lightImpact();
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = orderedCodes.removeAt(oldIndex);
                orderedCodes.insert(newIndex, item);
                _orderedCurrencies = orderedCodes;
              });
              
              // Save to SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setStringList(_orderedCurrenciesKey, orderedCodes);
            },
            children: [
              for (int i = 0; i < orderedCodes.length; i++) ...[
                ReorderableDelayedDragStartListener(
                  key: ValueKey(orderedCodes[i]),
                  index: i,
                  child: _CurrencyExchangeTile(
                    code: orderedCodes[i],
                    symbol: resolveCurrencySymbol(orderedCodes[i]),
                    amountLabel: resolveCurrencySymbol(orderedCodes[i]) + formatLocalizedNumber(context, table.convert(_baseAmount, resolvedBase, orderedCodes[i])),
                    onTap: () => _showAmountEditor(
                      context,
                      code: orderedCodes[i],
                      initialAmount: table.convert(_baseAmount, resolvedBase, orderedCodes[i]),
                    ),
                  ),
                ),
                if (i < orderedCodes.length - 1)
                  Padding(
                    key: ValueKey('divider_$i'),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.listDivider,
                    ),
                  ),
              ],
              // Updated time footer as the last item (not reorderable)
              Padding(
                key: const ValueKey('updated_time_footer'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (lastUpdatedStr.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 14,
                            color: colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lastUpdatedStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    if (table.isStale) ...[
                      if (lastUpdatedStr.isNotEmpty) const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: colorScheme.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.noData,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Set<String> _getDefaultShownCodes(
    String primaryCurrency,
    List<String>? homeSelectedCurrencies,
  ) {
    return {
      primaryCurrency,
      ...homeSelectedCurrencies ?? const <String>[],
    };
  }

  List<String> _getShownCodes(Set<String> defaultCodes, List<String> allCodes) {
    final list = _shownCurrencies;
    if (list != null && list.isNotEmpty) {
      // Ensure we keep only valid codes
      final filteredList = list.where((code) => allCodes.contains(code)).toList();
      // Safety rule: if list is empty after filtering, fall back to default
      if (filteredList.isNotEmpty) {
        // Always ensure base/primary currency is in shown list for usability
        final base = _baseCurrency ?? defaultCodes.first;
        if (!filteredList.contains(base) && allCodes.contains(base)) {
          filteredList.insert(0, base);
        }
        return filteredList;
      }
    }
    
    // Fallback: default codes filtered to exist in allCodes
    return defaultCodes.where((code) => allCodes.contains(code)).toList();
  }

  List<String> _getOrderedCodes(List<String> shownCodes) {
    final ordered = _orderedCurrencies;
    if (ordered != null && ordered.isNotEmpty) {
      // Filter to only include currently shown codes, maintaining order
      final filtered = ordered.where((code) => shownCodes.contains(code)).toList();
      // Add any new codes that aren't in the ordered list
      final newCodes = shownCodes.where((code) => !ordered.contains(code)).toList();
      return [...filtered, ...newCodes];
    }
    return shownCodes;
  }

  String _resolveBaseCurrency(
    CurrencyRateTable table,
    String preferredCurrency,
    List<String> availableCodes,
  ) {
    final current = _baseCurrency;
    if (current != null && table.rates.containsKey(current)) {
      return current;
    }

    final normalizedPreferred = preferredCurrency.trim().toUpperCase();
    if (table.rates.containsKey(normalizedPreferred)) {
      _baseCurrency = normalizedPreferred;
      return normalizedPreferred;
    }

    final normalizedBase = table.baseCurrency.trim().toUpperCase();
    if (table.rates.containsKey(normalizedBase)) {
      _baseCurrency = normalizedBase;
      return normalizedBase;
    }

    final fallback = availableCodes.isNotEmpty ? availableCodes.first : 'USD';
    _baseCurrency = fallback;
    return fallback;
  }

  List<String> _getManageSheetCodes(List<String> allCodes) {
    return allCodes
        .where((code) => currencyOptions.containsKey(code) && getCurrencyFlagPath(code) != null)
        .toList();
  }

  Future<void> _showAmountEditor(
    BuildContext context, {
    required String code,
    required double initialAmount,
  }) async {
    HapticFeedback.mediumImpact();
    
    final initialValue = initialAmount.toStringAsFixed(
      initialAmount == initialAmount.truncateToDouble() ? 0 : 2,
    );

    final flagPath = getCurrencyFlagPath(code);
    final currencyName = resolveCurrencyDisplayName(code);
    final symbol = resolveCurrencySymbol(code);
    final colorScheme = Theme.of(context).colorScheme;

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flagPath != null) ...[
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  flagPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            code,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.mutedForeground.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              currencyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );

    final resultStr = await showCalculatorKeypadSheet(
      context: context,
      initialValue: initialValue,
      prefix: symbol,
      header: header,
    );

    if (resultStr == null || !mounted) {
      return;
    }

    final normalized = resultStr.replaceAll(',', '').trim();
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return;
    }

    setState(() {
      _baseCurrency = code;
      _baseAmount = parsed;
    });
  }

  Future<void> _openManageCurrencies(
    List<String> allCodes,
    List<String> currentShown,
  ) async {
    HapticFeedback.lightImpact();

    final result = await MonekoBottomSheet.show<List<String>>(
      context: context,
      title: context.l10n.manageCurrencies,
      builder: (sheetContext) => ManageCurrenciesSheet(
        allCodes: allCodes,
        currentShown: currentShown,
      ),
    );

    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_shownCurrenciesKey, result);
      setState(() {
        _shownCurrencies = result;
        // If current base is no longer in the list, fallback base to first in list
        if (result.isNotEmpty && !result.contains(_baseCurrency)) {
          _baseCurrency = result.first;
          _baseAmount = 1.0;
        }
      });
    }
  }
}

class _CurrencyExchangeTile extends StatelessWidget {
  const _CurrencyExchangeTile({
    required this.code,
    required this.symbol,
    required this.amountLabel,
    required this.onTap,
  });

  final String code;
  final String symbol;
  final String amountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final flagPath = getCurrencyFlagPath(code);
    final currencyName = resolveCurrencyDisplayName(code);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Beautiful circular flag
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: flagPath != null
                      ? Image.asset(
                          flagPath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildSymbolFallback(colorScheme),
                        )
                      : _buildSymbolFallback(colorScheme),
                ),
              ),
              const SizedBox(width: 14),

              // Currency details (Code + Friendly Name)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currencyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Converted Amount (highlighted to indicate tappable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  amountLabel,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolFallback(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.muted,
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
