import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Shows a full-screen currency selector modal and returns the selected currency code
Future<String?> showCurrencySelectorModal(BuildContext context, WidgetRef ref) async {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CurrencySelectorScreen(),
    ),
  );
}

/// Full-screen currency selector screen
class CurrencySelectorScreen extends ConsumerStatefulWidget {
  const CurrencySelectorScreen({super.key});

  @override
  ConsumerState<CurrencySelectorScreen> createState() => _CurrencySelectorScreenState();
}

class _CurrencySelectorScreenState extends ConsumerState<CurrencySelectorScreen> {
  bool _showAllCurrencies = false;
  List<String>? _customOrder;

  @override
  void initState() {
    super.initState();
    _loadCustomOrder();
  }

  Future<void> _loadCustomOrder() async {
    try {
      final service = ref.read(currencyPreferenceServiceProvider);
      final order = await service.getCurrencyOrder();
      if (order != null && mounted) {
        setState(() {
          _customOrder = order;
        });
      }
    } catch (e) {
      debugPrint('Error loading currency order: $e');
    }
  }

  Future<void> _saveCustomOrder(List<String> order) async {
    try {
      final service = ref.read(currencyPreferenceServiceProvider);
      await service.setCurrencyOrder(order);
      if (mounted) {
        setState(() {
          _customOrder = order;
        });
      }
    } catch (e) {
      debugPrint('Error saving currency order: $e');
    }
  }

  List<CurrencySummary> _applyCustomOrder(List<CurrencySummary> currencies) {
    if (_customOrder == null || _customOrder!.isEmpty) {
      return currencies;
    }

    final orderedList = <CurrencySummary>[];
    final currencyMap = {for (var c in currencies) c.currencyCode: c};
    
    // Add currencies in custom order
    for (final code in _customOrder!) {
      if (currencyMap.containsKey(code)) {
        orderedList.add(currencyMap[code]!);
        currencyMap.remove(code);
      }
    }
    
    // Add any remaining currencies not in custom order
    orderedList.addAll(currencyMap.values);
    
    return orderedList;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final summaries = ref.watch(currencySummariesProvider);
    final filterState = ref.watch(homeFilterProvider);
    
    // Get all supported currencies from backend
    final allSupportedCurrencies = getAvailableCurrencyOptions().keys.toList();
    
    // Create a map of existing summaries for quick lookup
    final summaryMap = {for (var s in summaries) s.currencyCode: s};
    
    // Create full list including all supported currencies
    final allCurrencySummaries = allSupportedCurrencies.map((code) {
      return summaryMap[code] ?? CurrencySummary(
        currencyCode: code,
        totalExpenses: 0,
        totalBudget: 0,
        transactionCount: 0,
      );
    }).toList();
    
    // Separate currencies into active (with transactions/budget) and inactive
    var activeCurrencies = allCurrencySummaries.where((s) => 
      s.transactionCount > 0 || s.totalBudget > 0
    ).toList();
    
    var inactiveCurrencies = allCurrencySummaries.where((s) => 
      s.transactionCount == 0 && s.totalBudget == 0
    ).toList()..sort((a, b) => a.currencyCode.compareTo(b.currencyCode));
    
    // Apply custom order
    activeCurrencies = _applyCustomOrder(activeCurrencies);
    inactiveCurrencies = _applyCustomOrder(inactiveCurrencies);
    
    var visibleCurrencies = _showAllCurrencies 
      ? [...activeCurrencies, ...inactiveCurrencies]
      : activeCurrencies;
    
    // Always put selected currency at the top and ensure it's visible
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    if (selectedCurrency != null) {
      final selectedIndex = visibleCurrencies.indexWhere(
        (s) => s.currencyCode == selectedCurrency
      );
      
      if (selectedIndex > 0) {
        // Move selected currency to the front
        final selected = visibleCurrencies.removeAt(selectedIndex);
        visibleCurrencies.insert(0, selected);
      } else if (selectedIndex == -1) {
        // Selected currency not in visible list, add it from inactive currencies
        final selectedFromInactive = inactiveCurrencies.firstWhere(
          (s) => s.currencyCode == selectedCurrency,
          orElse: () => allCurrencySummaries.firstWhere(
            (s) => s.currencyCode == selectedCurrency,
            orElse: () => CurrencySummary(
              currencyCode: selectedCurrency,
              totalExpenses: 0,
              totalBudget: 0,
              transactionCount: 0,
            ),
          ),
        );
        visibleCurrencies.insert(0, selectedFromInactive);
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.foreground),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Text(
          context.l10n.selectCurrency,
          style: TextStyle(
            color: colorScheme.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ReorderableListView(
          padding: const EdgeInsets.all(16),
          onReorderStart: (index) {
            // Provide haptic feedback when drag starts
            HapticFeedback.mediumImpact();
          },
          onReorder: (oldIndex, newIndex) {
            // Provide haptic feedback on successful reorder
            HapticFeedback.lightImpact();
            
            // Adjust index if moving down
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            
            // Reorder the list
            final reorderedList = List<CurrencySummary>.from(visibleCurrencies);
            final item = reorderedList.removeAt(oldIndex);
            reorderedList.insert(newIndex, item);
            
            // Save new order
            final newOrder = reorderedList.map((s) => s.currencyCode).toList();
            _saveCustomOrder(newOrder);
          },
          children: [
            // Individual currency cards
            ...visibleCurrencies.map((summary) => Padding(
              key: Key(summary.currencyCode),
              padding: const EdgeInsets.only(bottom: 12),
              child: _CurrencyCard(
                summary: summary,
                isSelected: filterState.selectedCurrency?.toUpperCase() == summary.currencyCode,
                onTap: () async {
                  final colorScheme = shadcnui.Theme.of(context).colorScheme;
                  final authState = ref.read(authProvider);
                  final previousCurrency = filterState.selectedCurrency;
                  
                  // Optimistically update UI immediately
                  final service = ref.read(currencyPreferenceServiceProvider);
                  await service.setSelectedCurrency(summary.currencyCode);
                  ref.read(homeFilterProvider.notifier).setSelectedCurrency(summary.currencyCode);
                  
                  // Close modal immediately for better UX and return selected currency
                  if (context.mounted) {
                    Navigator.pop(context, summary.currencyCode);
                  }
                  
                  // Update analytics state optimistically
                  ref.read(analyticsProvider.notifier).updatePreferredCurrency(summary.currencyCode);
                  
                  // Make BE call in background
                  if (authState.uid.isNotEmpty) {
                    try {
                      final response = await supabase.functions.invoke(
                        'update-preferred-currency',
                        body: {
                          'userId': authState.uid,
                          'currency': summary.currencyCode,
                        },
                      );

                      final status = response.status;
                      if (status >= 400) {
                        throw Exception('Request failed ($status)');
                      }

                      final payload = response.data as Map<String, dynamic>?;
                      if (payload == null || payload['ok'] != true) {
                        final message = payload?['error'] as String? ?? 'Unable to update currency';
                        throw Exception(message);
                      }
                      
                      // Success - currency is now synced with backend
                    } catch (error) {
                      // Rollback on error
                      debugPrint('Failed to update preferred currency on backend: $error');
                      
                      // Revert to previous currency
                      if (previousCurrency != null) {
                        await service.setSelectedCurrency(previousCurrency);
                        ref.read(homeFilterProvider.notifier).setSelectedCurrency(previousCurrency);
                        ref.read(analyticsProvider.notifier).updatePreferredCurrency(previousCurrency);
                      }
                      
                      // Show error to user if context is still mounted
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to sync currency preference: $error'),
                            backgroundColor: colorScheme.destructive,
                            action: SnackBarAction(
                              label: 'Retry',
                              textColor: Colors.white,
                              onPressed: () async {
                                // Retry the operation
                                try {
                                  final retryResponse = await supabase.functions.invoke(
                                    'update-preferred-currency',
                                    body: {
                                      'userId': authState.uid,
                                      'currency': summary.currencyCode,
                                    },
                                  );
                                  
                                  if (retryResponse.status >= 400) {
                                    throw Exception('Retry failed');
                                  }
                                  
                                  // Update UI again after successful retry
                                  await service.setSelectedCurrency(summary.currencyCode);
                                  ref.read(homeFilterProvider.notifier).setSelectedCurrency(summary.currencyCode);
                                  ref.read(analyticsProvider.notifier).updatePreferredCurrency(summary.currencyCode);
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Currency updated successfully'),
                                        backgroundColor: colorScheme.primary,
                                      ),
                                    );
                                  }
                                } catch (retryError) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Retry failed: $retryError'),
                                        backgroundColor: colorScheme.destructive,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            )),
            
            // Show all currencies toggle button - minimal Apple-style design
            if (inactiveCurrencies.isNotEmpty)
              GestureDetector(
                key: const Key('show_all_toggle'),
                onTap: () {
                  setState(() {
                    _showAllCurrencies = !_showAllCurrencies;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                       
                        Text(
                          _showAllCurrencies 
                            ? context.l10n.showLessCurrencies
                            : context.l10n.showAllCurrencies(inactiveCurrencies.length),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.primary,
                          ),
                        ),
                       
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Currency icon widget with flag image and fallback
class _CurrencyIcon extends StatelessWidget {
  final String currencyCode;
  final String currencySymbol;
  final shadcnui.ColorScheme colorScheme;

  const _CurrencyIcon({
    required this.currencyCode,
    required this.currencySymbol,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final flagPath = getCurrencyFlagPath(currencyCode);
    
    if (flagPath != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.border.withValues(alpha: 0.3), width: 1),
        ),
        child: ClipOval(
          child: Image.asset(
            flagPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to symbol if flag image fails to load
              return _buildSymbolFallback();
            },
          ),
        ),
      );
    }
    
    // No flag available, use symbol
    return _buildSymbolFallback();
  }

  Widget _buildSymbolFallback() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.muted,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          currencySymbol,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Individual currency card widget
class _CurrencyCard extends StatelessWidget {
  final CurrencySummary summary;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyCard({
    required this.summary,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final currencySymbol = resolveCurrencySymbol(summary.currencyCode);
    final netCashflow = summary.netCashflow;
    final isPositive = summary.isPositive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Currency icon with flag image or symbol fallback
              _CurrencyIcon(
                currencyCode: summary.currencyCode,
                currencySymbol: currencySymbol,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 12),
              
              // Currency code
              SizedBox(
                width: 40,
                child: Text(
                  summary.currencyCode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Data in compact layout
              Expanded(
                child: Row(
                  children: [
                    // Left column - Budget and Spent
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.l10n.budget}: ${formatCurrency(summary.totalBudget, summary.currencyCode)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.l10n.spentLabel}: ${formatCurrency(summary.totalExpenses, summary.currencyCode)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Right column - Net and transaction count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isPositive ? '+' : ''}${formatCurrency(netCashflow, summary.currencyCode)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${summary.transactionCount} ${summary.transactionCount != 1 ? context.l10n.txns : context.l10n.txn}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
          
            ],
          ),
        ),
      ),
    );
  }
}
