import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:moneko/core/constants/links.dart';
import 'package:moneko/core/services/widget_service.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Shows a full-screen currency selector modal and returns the selected currency code
Future<String?> showCurrencySelectorModal(
  BuildContext context,
  WidgetRef ref, {
  bool showAllByDefault = false,
}) async {
  final navigator = Navigator.maybeOf(context, rootNavigator: true);
  if (navigator == null) return null;
  return navigator.push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          CurrencySelectorScreen(showAllByDefault: showAllByDefault),
    ),
  );
}

/// Full-screen currency selector screen
class CurrencySelectorScreen extends ConsumerStatefulWidget {
  final bool showAllByDefault;

  const CurrencySelectorScreen({super.key, this.showAllByDefault = false});

  @override
  ConsumerState<CurrencySelectorScreen> createState() =>
      _CurrencySelectorScreenState();
}

class _CurrencySelectorScreenState
    extends ConsumerState<CurrencySelectorScreen> {
  bool _showAllCurrencies = false;
  List<String>? _customOrder;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // When requested (e.g., onboarding), start with all currencies expanded
    _showAllCurrencies = widget.showAllByDefault;
    _loadCustomOrder();
  }

  Future<void> _loadCustomOrder() async {
    try {
      if (!mounted) return;
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
      if (!mounted) return;
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;
    final summaries =
        ref.watch(dashboardCurrencySummariesProvider).valueOrNull ??
            const <CurrencySummary>[];
    final filterState = ref.watch(homeFilterProvider);
    final currencyCounts =
        ref.watch(dashboardCurrencyTransactionCountsProvider);

    // Get all supported currencies from backend
    final currencyOptions = getAvailableCurrencyOptions();
    final allSupportedCurrencies = currencyOptions.keys.toList();

    // Create a map of existing summaries for quick lookup
    final summaryMap = {for (var s in summaries) s.currencyCode: s};

    // Create full list including all supported currencies
    final allCurrencySummaries = allSupportedCurrencies.map((code) {
      return summaryMap[code] ??
          CurrencySummary(
            currencyCode: code,
            totalExpenses: 0,
            totalIncome: 0,
            totalBudget: 0,
            transactionCount: 0,
          );
    }).toList();

    // Separate currencies into active (with transactions) and inactive
    var activeCurrencies = allCurrencySummaries.where((s) {
      final txCount = currencyCounts[s.currencyCode] ?? s.transactionCount;
      return txCount > 0;
    }).toList();

    var inactiveCurrencies = allCurrencySummaries.where((s) {
      final txCount = currencyCounts[s.currencyCode] ?? s.transactionCount;
      return txCount == 0;
    }).toList()
      ..sort((a, b) => a.currencyCode.compareTo(b.currencyCode));

    // Apply custom order
    activeCurrencies = _applyCustomOrder(activeCurrencies);
    inactiveCurrencies = _applyCustomOrder(inactiveCurrencies);

    // Full ordered list (active + inactive)
    final allOrderedCurrencies = <CurrencySummary>[
      ...activeCurrencies,
      ...inactiveCurrencies,
    ];

    // Apply search filter (by currency code or symbol)
    final query = _searchQuery.trim().toLowerCase();
    List<CurrencySummary> visibleCurrencies;
    if (query.isNotEmpty) {
      // When searching, bypass the "show all" toggle and search across all currencies
      visibleCurrencies = allOrderedCurrencies.where((s) {
        final code = s.currencyCode.toLowerCase();
        final symbol = (currencyOptions[s.currencyCode] ?? '').toLowerCase();
        return code.contains(query) || symbol.contains(query);
      }).toList();
    } else {
      // Default behavior respecting the "show all currencies" toggle
      visibleCurrencies = _showAllCurrencies
          ? List<CurrencySummary>.from(allOrderedCurrencies)
          : List<CurrencySummary>.from(activeCurrencies);
    }

    // Always put selected currency at the top and ensure it's visible
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    if (selectedCurrency != null) {
      final selectedIndex = visibleCurrencies.indexWhere(
        (s) => s.currencyCode == selectedCurrency,
      );

      if (selectedIndex > 0) {
        // Move selected currency to the front
        final selected = visibleCurrencies.removeAt(selectedIndex);
        visibleCurrencies.insert(0, selected);
      } else if (selectedIndex == -1 && query.isEmpty && _showAllCurrencies) {
        // When showing all currencies and not searching, ensure the selected currency is visible
        final selectedFromInactive = inactiveCurrencies.firstWhere(
          (s) => s.currencyCode == selectedCurrency,
          orElse: () => allCurrencySummaries.firstWhere(
            (s) => s.currencyCode == selectedCurrency,
            orElse: () => CurrencySummary(
              currencyCode: selectedCurrency,
              totalExpenses: 0,
              totalIncome: 0,
              totalBudget: 0,
              transactionCount: 0,
            ),
          ),
        );
        visibleCurrencies.insert(0, selectedFromInactive);
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.mutedForeground,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
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
                  hintText: context.l10n.search,
                  filled: true,
                  fillColor: colorScheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            Expanded(
              child: visibleCurrencies.isEmpty && query.isNotEmpty
                  ? _buildEmptySearchState(context, colorScheme, query)
                  : ReorderableListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        final reorderedList =
                            List<CurrencySummary>.from(visibleCurrencies);
                        final item = reorderedList.removeAt(oldIndex);
                        reorderedList.insert(newIndex, item);

                        // Save new order
                        final newOrder =
                            reorderedList.map((s) => s.currencyCode).toList();
                        _saveCustomOrder(newOrder);
                      },
                      children: [
                        // Individual currency cards
                        for (final summary in visibleCurrencies)
                          Padding(
                            key: Key(summary.currencyCode),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CurrencyCard(
                              summary: summary,
                              transactionCount:
                                  (currencyCounts[summary.currencyCode] ??
                                      summary.transactionCount),
                              isSelected:
                                  filterState.selectedCurrency?.toUpperCase() ==
                                      summary.currencyCode,
                              onTap: () async {
                                final previousCurrency =
                                    filterState.selectedCurrency;
                                final service =
                                    ref.read(currencyPreferenceServiceProvider);
                                final filterNotifier =
                                    ref.read(homeFilterProvider.notifier);
                                final analyticsNotifier =
                                    ref.read(analyticsProvider.notifier);
                                final toastContext = Navigator.maybeOf(context,
                                        rootNavigator: true)
                                    ?.context;

                                // Optimistically update UI immediately
                                await service
                                    .setSelectedCurrency(summary.currencyCode);
                                filterNotifier
                                    .setSelectedCurrency(summary.currencyCode);
                                analyticsNotifier.updatePreferredCurrency(
                                    summary.currencyCode);
                                await WidgetService()
                                    .saveSelectedWidgetCurrency(
                                        summary.currencyCode);
                                await WidgetService().reloadWidgets();

                                // Close modal immediately for better UX and return selected currency
                                if (context.mounted) {
                                  Navigator.pop(context, summary.currencyCode);
                                }

                                // Make BE call in background
                                final hasSession =
                                    supabase.auth.currentSession != null;
                                if (hasSession) {
                                  try {
                                    final userId =
                                        supabase.auth.currentSession?.user.id;
                                    if (userId == null || userId.isEmpty) {
                                      throw Exception('Missing user session');
                                    }
                                    final response =
                                        await supabase.functions.invoke(
                                      'update-preferred-currency',
                                      body: {
                                        'currency': summary.currencyCode,
                                        'userId': userId,
                                      },
                                    );

                                    final status = response.status;
                                    if (status >= 400) {
                                      throw Exception(
                                          'Request failed ($status)');
                                    }

                                    final payloadData = response.data;
                                    if (payloadData is! Map) {
                                      throw Exception('Invalid response');
                                    }
                                    final payload =
                                        payloadData.cast<String, dynamic>();
                                    if (payload['ok'] != true) {
                                      throw Exception(
                                        (payload['error'] ??
                                                'Unable to update currency')
                                            .toString(),
                                      );
                                    }

                                    // Success - currency is now synced with backend
                                  } catch (error) {
                                    // Rollback on error
                                    debugPrint(
                                        'Failed to update preferred currency on backend: $error');

                                    final currentSelection = ref
                                        .read(homeFilterProvider)
                                        .selectedCurrency
                                        ?.toUpperCase();
                                    final selectedCode =
                                        summary.currencyCode.toUpperCase();
                                    if (previousCurrency != null &&
                                        currentSelection == selectedCode) {
                                      await service.setSelectedCurrency(
                                          previousCurrency);
                                      filterNotifier.setSelectedCurrency(
                                          previousCurrency);
                                      analyticsNotifier.updatePreferredCurrency(
                                          previousCurrency);
                                      await WidgetService()
                                          .saveSelectedWidgetCurrency(
                                              previousCurrency);
                                      await WidgetService().reloadWidgets();
                                    }

                                    if (toastContext != null &&
                                        toastContext.mounted) {
                                      final toastCtx = toastContext;
                                      final missingUserSessionMessage =
                                          context.l10n.missingUserSession;
                                      final invalidResponseMessage =
                                          context.l10n.invalidResponse;
                                      final unableToUpdateCurrencyMessage =
                                          context.l10n.unableToUpdateCurrency;
                                      // Use AppToast with action so message appears above any bottom sheet
                                      AppToast.action(
                                        toastCtx,
                                        context.l10n.failedToSyncCurrency,
                                        actionLabel: context.l10n.retry,
                                        type: AppToastType.warning,
                                        onPressed: () async {
                                          try {
                                            if (!toastCtx.mounted) return;
                                            final hasSession =
                                                supabase.auth.currentSession !=
                                                    null;
                                            if (!hasSession) {
                                              throw Exception(
                                                  missingUserSessionMessage);
                                            }
                                            final userId = supabase
                                                .auth.currentSession?.user.id;
                                            if (userId == null ||
                                                userId.isEmpty) {
                                              throw Exception(
                                                  missingUserSessionMessage);
                                            }
                                            final retryResponse =
                                                await supabase.functions.invoke(
                                              'update-preferred-currency',
                                              body: {
                                                'currency':
                                                    summary.currencyCode,
                                                'userId': userId,
                                              },
                                            );
                                            if (retryResponse.status >= 400) {
                                              throw Exception(
                                                  'Retry failed (${retryResponse.status})');
                                            }
                                            final retryData =
                                                retryResponse.data;
                                            if (retryData is! Map) {
                                              throw Exception(
                                                  invalidResponseMessage);
                                            }
                                            final payload = retryData
                                                .cast<String, dynamic>();
                                            if (payload['ok'] != true) {
                                              throw Exception(
                                                (payload['error'] ??
                                                        unableToUpdateCurrencyMessage)
                                                    .toString(),
                                              );
                                            }
                                            await service.setSelectedCurrency(
                                                summary.currencyCode);
                                            filterNotifier.setSelectedCurrency(
                                                summary.currencyCode);
                                            analyticsNotifier
                                                .updatePreferredCurrency(
                                                    summary.currencyCode);
                                            await WidgetService()
                                                .saveSelectedWidgetCurrency(
                                                    summary.currencyCode);
                                            await WidgetService()
                                                .reloadWidgets();
                                            if (toastCtx.mounted) {
                                              AppToast.success(
                                                toastCtx,
                                                context.l10n
                                                    .currencyUpdatedSuccess,
                                              );
                                            }
                                          } catch (retryError) {
                                            debugPrint(
                                                'Failed to retry preferred currency update: $retryError');
                                            if (toastCtx.mounted) {
                                              AppToast.error(
                                                toastCtx,
                                                context.l10n.retryFailed(''),
                                              );
                                            }
                                          }
                                        },
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ),

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
                                          : context.l10n.showAllCurrencies(
                                              inactiveCurrencies.length),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(
      BuildContext context, ColorScheme colorScheme, String searchQuery) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 48,
            color: colorScheme.mutedForeground.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.currencyNotFound,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.currencyNotFoundDescription,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ContactButton(
                label: 'Email',
                icon: Icons.email_outlined,
                onTap: () {
                  // Launch email with predefined subject and body
                  final subject =
                      Uri.encodeComponent('Request: Add my local currency');
                  final body = Uri.encodeComponent(
                      "Hi Moneko team,\n\nI'd love to use Moneko with my local currency. Could you please add support for $searchQuery?\n\nThanks!");
                  final uri = Uri.parse(
                      'mailto:hello@moneko.io?subject=$subject&body=$body');
                  launchUrl(uri);
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 12),
              _ContactButton(
                label: 'Discord',
                icon: Icons.chat_bubble_outline,
                onTap: () {
                  // Launch Discord invite link
                  final uri = Uri.parse(Links.discordSupport);
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Currency icon widget with flag image and fallback
class _CurrencyIcon extends StatelessWidget {
  final String currencyCode;
  final String currencySymbol;
  final ColorScheme colorScheme;

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
          border: Border.all(
              color: colorScheme.border.withValues(alpha: 0.3), width: 1),
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
  final int transactionCount;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyCard({
    required this.summary,
    required this.transactionCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencySymbol = resolveCurrencySymbol(summary.currencyCode);

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
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

              // Right side: transaction count only
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$transactionCount ${transactionCount != 1 ? context.l10n.txns : context.l10n.txn}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contact button widget for empty state
class _ContactButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ContactButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
