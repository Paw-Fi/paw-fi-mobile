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
import 'package:moneko/features/utils/currency.dart';
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
                final defaultCodes = _getDefaultShownCodes(preferredCurrency, homeSelectedCurrencies);
                final currentShown = _getShownCodes(defaultCodes, allCodes);
                _openManageCurrencies(allCodes, currentShown);
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

  Future<void> _showAmountEditor(
    BuildContext context, {
    required String code,
    required double initialAmount,
  }) async {
    HapticFeedback.mediumImpact();
    
    final initialValue = initialAmount.toStringAsFixed(
      initialAmount == initialAmount.truncateToDouble() ? 0 : 2,
    );

    final resultStr = await showCalculatorKeypadSheet(
      context: context,
      initialValue: initialValue,
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
      title: "Manage Currencies",
      builder: (sheetContext) => _ManageCurrenciesSheet(
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
    final currencyName = _currencyNames[code] ?? code;

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

class _ManageCurrenciesSheet extends StatefulWidget {
  const _ManageCurrenciesSheet({
    required this.allCodes,
    required this.currentShown,
  });

  final List<String> allCodes;
  final List<String> currentShown;

  @override
  State<_ManageCurrenciesSheet> createState() => _ManageCurrenciesSheetState();
}

class _ManageCurrenciesSheetState extends State<_ManageCurrenciesSheet> {
  late Set<String> _selectedCodes;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCodes = Set<String>.from(widget.currentShown);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Filter codes based on query
    final query = _searchQuery.trim().toLowerCase();
    final filteredCodes = widget.allCodes.where((code) {
      final name = (_currencyNames[code] ?? '').toLowerCase();
      final lowerCode = code.toLowerCase();
      return lowerCode.contains(query) || name.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Apple-style Search Bar
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: colorScheme.mutedForeground,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: colorScheme.mutedForeground,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              hintText: 'Search currencies...',
              filled: true,
              fillColor: colorScheme.brightness == Brightness.dark
                  ? colorScheme.muted.withValues(alpha: 0.15)
                  : colorScheme.muted.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable Currency Options List
          Flexible(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: filteredCodes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No currencies match your search",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredCodes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final code = filteredCodes[index];
                        final isSelected = _selectedCodes.contains(code);
                        final flagPath = getCurrencyFlagPath(code);
                        final name = _currencyNames[code] ?? code;
                        final symbol = resolveCurrencySymbol(code);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (isSelected) {
                                  // Enforce at least one currency is always shown
                                  if (_selectedCodes.length > 1) {
                                    _selectedCodes.remove(code);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('At least one currency must be visible.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  _selectedCodes.add(code);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // Small Flag
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.outline.withValues(alpha: 0.08),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: flagPath != null
                                          ? Image.asset(
                                              flagPath,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  _buildSymbolFallback(colorScheme, symbol),
                                            )
                                          : _buildSymbolFallback(colorScheme, symbol),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Code and Full name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          code,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.foreground,
                                          ),
                                        ),
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Checkbox
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_circle_rounded,
                                            key: const ValueKey('selected'),
                                            color: colorScheme.primary,
                                            size: 24,
                                          )
                                        : Icon(
                                            Icons.radio_button_unchecked_rounded,
                                            key: const ValueKey('unselected'),
                                            color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Save Changes CTA Button
          Container(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottomPadding),
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(_selectedCodes.toList());
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save Visible Currencies',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolFallback(ColorScheme colorScheme, String symbol) {
    return Container(
      color: colorScheme.muted,
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// Friendly mapping of currency code to full name for elite UX/UI
const Map<String, String> _currencyNames = {
  'USD': 'United States Dollar',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'JPY': 'Japanese Yen',
  'CAD': 'Canadian Dollar',
  'AUD': 'Australian Dollar',
  'CNY': 'Chinese Yuan',
  'CHF': 'Swiss Franc',
  'HKD': 'Hong Kong Dollar',
  'SGD': 'Singapore Dollar',
  'NZD': 'New Zealand Dollar',
  'INR': 'Indian Rupee',
  'MXN': 'Mexican Peso',
  'BRL': 'Brazilian Real',
  'ZAR': 'South African Rand',
  'IDR': 'Indonesian Rupiah',
  'AED': 'United Arab Emirates Dirham',
  'SAR': 'Saudi Riyal',
  'TRY': 'Turkish Lira',
  'RUB': 'Russian Ruble',
  'KRW': 'South Korean Won',
  'PLN': 'Polish Zloty',
  'THB': 'Thai Baht',
  'MYR': 'Malaysian Ringgit',
  'PHP': 'Philippine Peso',
  'VND': 'Vietnamese Dong',
  'DKK': 'Danish Krone',
  'NOK': 'Norwegian Krone',
  'SEK': 'Swedish Krona',
  'EGP': 'Egyptian Pound',
  'ILS': 'Israeli New Shekel',
  'CLP': 'Chilean Peso',
  'COP': 'Colombian Peso',
  'DOP': 'Dominican Peso',
  'CZK': 'Czech Koruna',
  'BDT': 'Bangladeshi Taka',
  'BZD': 'Belize Dollar',
  'DZD': 'Algerian Dinar',
  'ETB': 'Ethiopian Birr',
  'GHS': 'Ghanaian Cedi',
  'GTQ': 'Guatemalan Quetzal',
  'HUF': 'Hungarian Forint',
  'JMD': 'Jamaican Dollar',
  'KES': 'Kenyan Shilling',
  'LKR': 'Sri Lankan Rupee',
  'MWK': 'Malawian Kwacha',
  'NGN': 'Nigerian Naira',
  'NPR': 'Nepalese Rupee',
  'PEN': 'Peruvian Sol',
  'PKR': 'Pakistani Rupee',
  'PYG': 'Paraguayan Guarani',
  'RSD': 'Serbian Dinar',
  'RON': 'Romanian Leu',
  'UAH': 'Ukrainian Hryvnia',
  'ZMW': 'Zambian Kwacha',
  'XOF': 'West African CFA Franc',
  'CRC': 'Costa Rican Colon',
  'XAF': 'Central African CFA Franc',
};
