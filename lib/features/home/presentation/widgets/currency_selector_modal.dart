import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool preselectPrimary = true,
}) async {
  final navigator = Navigator.maybeOf(context, rootNavigator: true);
  if (navigator == null) return null;
  return navigator.push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CurrencySelectorScreen(
        showAllByDefault: showAllByDefault,
        preselectPrimary: preselectPrimary,
      ),
    ),
  );
}

Future<void> _syncPreferredCurrencyOnBackend(
  String currency,
  BuildContext context,
) async {
  final userId = supabase.auth.currentSession?.user.id;
  if (userId == null || userId.isEmpty) {
    throw Exception(context.l10n.missingUserSession);
  }
  final response = await supabase.functions.invoke(
    'update-preferred-currency',
    body: {
      'currency': currency,
      'userId': userId,
    },
  );

  if (response.status >= 400) {
    throw Exception(context.l10n.requestFailed(response.status));
  }

  final payloadData = response.data;
  if (payloadData is! Map) {
    throw Exception(context.l10n.invalidResponse);
  }
  final payload = payloadData.cast<String, dynamic>();
  if (payload['ok'] != true) {
    throw Exception(
      (payload['error'] ?? context.l10n.unableToUpdateCurrency).toString(),
    );
  }
}

Future<void> _applyLocalCurrencySelection(
  ProviderContainer container, {
  required String primaryCurrency,
  required List<String> selectedCurrencies,
}) async {
  final service = container.read(currencyPreferenceServiceProvider);
  final filterNotifier = container.read(homeFilterProvider.notifier);
  final analyticsNotifier = container.read(analyticsProvider.notifier);

  await service.setSelectedCurrency(primaryCurrency);
  await service.setSelectedCurrencies(selectedCurrencies);
  filterNotifier.setSelectedCurrency(primaryCurrency);
  filterNotifier.setSelectedCurrencies(selectedCurrencies);
  analyticsNotifier.updatePreferredCurrency(primaryCurrency);
  await WidgetService().saveSelectedWidgetCurrency(primaryCurrency);
  await WidgetService().reloadWidgets();
}

Future<void> _retryCurrencySelectionSync({
  required ProviderContainer container,
  required BuildContext toastContext,
  required String primaryCurrency,
  required List<String> selectedCurrencies,
  required String successMessage,
  required String retryFailedMessage,
}) async {
  try {
    await _applyLocalCurrencySelection(
      container,
      primaryCurrency: primaryCurrency,
      selectedCurrencies: selectedCurrencies,
    );
    await _syncPreferredCurrencyOnBackend(primaryCurrency,toastContext);
    if (toastContext.mounted) {
      AppToast.success(toastContext, successMessage);
    }
  } catch (error) {
    debugPrint('Failed to retry preferred currency update: $error');
    if (toastContext.mounted) {
      AppToast.error(toastContext, retryFailedMessage);
    }
  }
}

/// Full-screen currency selector screen
class CurrencySelectorScreen extends ConsumerStatefulWidget {
  final bool showAllByDefault;
  final bool preselectPrimary;

  const CurrencySelectorScreen({
    super.key,
    this.showAllByDefault = false,
    this.preselectPrimary = true,
  });

  @override
  ConsumerState<CurrencySelectorScreen> createState() =>
      _CurrencySelectorScreenState();
}

class _CurrencySelectorScreenState
    extends ConsumerState<CurrencySelectorScreen> {
  bool _showAllCurrencies = false;
  List<String>? _customOrder;
  List<String>? _selectedCurrencies;
  String? _primaryCurrency;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String>? _stableCurrencyCodes;

  @override
  void initState() {
    super.initState();
    // When requested (e.g., onboarding), start with all currencies expanded
    _showAllCurrencies = widget.showAllByDefault;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      if (!mounted) return;
      final service = ref.read(currencyPreferenceServiceProvider);
      final order = await service.getCurrencyOrder();
      final selectedCurrencies = await service.getSelectedCurrencies();
      if (order != null && mounted) {
        setState(() {
          _customOrder = order;
          _selectedCurrencies = selectedCurrencies;
          _stableCurrencyCodes = order;
        });
      } else if (mounted) {
        setState(() {
          _selectedCurrencies = selectedCurrencies;
        });
      }
    } catch (e) {
      debugPrint('Error loading currency preferences: $e');
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
          _stableCurrencyCodes = order;
        });
      }
    } catch (e) {
      debugPrint('Error saving currency order: $e');
    }
  }

  void _initializeStableCurrencyList(List<CurrencySummary> activeCurrencies,
      List<CurrencySummary> inactiveCurrencies, String primaryCurrency) {
    if (_stableCurrencyCodes != null) return;

    final allOrdered = <CurrencySummary>[
      ...activeCurrencies,
      ...inactiveCurrencies,
    ];

    // Initial sort: Primary at top
    if (primaryCurrency.isNotEmpty) {
      final index =
          allOrdered.indexWhere((s) => s.currencyCode == primaryCurrency);
      if (index > 0) {
        final selected = allOrdered.removeAt(index);
        allOrdered.insert(0, selected);
      }
    }

    _stableCurrencyCodes = allOrdered.map((s) => s.currencyCode).toList();
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

  List<String> _normalizeCurrencySelection(Iterable<String> currencies) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final currency in currencies) {
      final code = currency.trim().toUpperCase();
      if (code.isEmpty || seen.contains(code)) continue;
      seen.add(code);
      normalized.add(code);
    }
    return normalized;
  }

  Future<void> _saveSelection({
    required String primaryCurrency,
    required List<String> selectedCurrencies,
  }) async {
    final previousFilterState = ref.read(homeFilterProvider);
    final previousCurrency = previousFilterState.selectedCurrency;
    final previousCurrencies = previousFilterState.normalizedSelectedCurrencies;
    final normalizedPrimary = primaryCurrency.trim().toUpperCase();
    final normalizedSelected = _normalizeCurrencySelection([
      normalizedPrimary,
      ...selectedCurrencies,
    ]);
    final resolvedPrimary = normalizedPrimary.isNotEmpty
        ? normalizedPrimary
        : (normalizedSelected.isNotEmpty
            ? normalizedSelected.first
            : (previousCurrency?.trim().toUpperCase() ?? ''));

    if (resolvedPrimary.isEmpty) {
      AppToast.warning(context, context.l10n.selectCurrencyFirst);
      return;
    }

    final resolvedSelected = _normalizeCurrencySelection([
      resolvedPrimary,
      ...normalizedSelected,
    ]);
    final container = ProviderScope.containerOf(context, listen: false);
    final toastContext =
        Navigator.maybeOf(context, rootNavigator: true)?.context;
    final failedToSyncCurrencyMessage = context.l10n.failedToSyncCurrency;
    final retryLabel = context.l10n.retry;
    final successMessage = context.l10n.currencyUpdatedSuccess;
    final retryFailedMessage = context.l10n.retryFailed('');

    await _applyLocalCurrencySelection(
      container,
      primaryCurrency: resolvedPrimary,
      selectedCurrencies: resolvedSelected,
    );

    if (mounted) {
      Navigator.pop(context, resolvedPrimary);
    }

    final hasSession = supabase.auth.currentSession != null;
    if (!hasSession) return;

    try {
      await _syncPreferredCurrencyOnBackend(resolvedPrimary, context);
    } catch (error) {
      debugPrint('Failed to update preferred currency on backend: $error');

      if (previousCurrency != null) {
        await _applyLocalCurrencySelection(
          container,
          primaryCurrency: previousCurrency,
          selectedCurrencies: previousCurrencies ?? <String>[previousCurrency],
        );
      }

      if (toastContext != null && toastContext.mounted) {
        AppToast.action(
          toastContext,
          failedToSyncCurrencyMessage,
          actionLabel: retryLabel,
          type: AppToastType.warning,
          onPressed: () => _retryCurrencySelectionSync(
            container: container,
            toastContext: toastContext,
            primaryCurrency: resolvedPrimary,
            selectedCurrencies: resolvedSelected,
            successMessage: successMessage,
            retryFailedMessage: retryFailedMessage,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summariesAsync = ref.watch(dashboardCurrencySummariesProvider);
    final summaries = summariesAsync.valueOrNull ?? const <CurrencySummary>[];
    final filterState = ref.watch(homeFilterProvider);
    final currencyCountsAsync =
        ref.watch(dashboardCurrencyTransactionCountsProvider);
    final summaryCurrencyCounts =
        ref.watch(dashboardCurrencySummaryTransactionCountsProvider);
    final currencyCounts = currencyCountsAsync.valueOrNull ??
        (summaryCurrencyCounts.isNotEmpty
            ? summaryCurrencyCounts
            : const <String, int>{});
    if (foundation.kDebugMode) {
      foundation.debugPrint(
        '[CurrencySelector][Modal] build summariesLoading=${summariesAsync.isLoading} countsLoading=${currencyCountsAsync.isLoading} hasError=${summariesAsync.hasError || currencyCountsAsync.hasError} summaryCount=${summaries.length} selected=${filterState.selectedCurrency ?? '<none>'} counts=$currencyCounts summaryCounts=$summaryCurrencyCounts summaryError=${summariesAsync.error ?? '<none>'} countsError=${currencyCountsAsync.error ?? '<none>'}',
      );
    }

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
    final activeCurrencies = allCurrencySummaries.where((s) {
      final txCount = currencyCounts[s.currencyCode] ?? s.transactionCount;
      return txCount > 0;
    }).toList();

    final inactiveCurrencies = allCurrencySummaries.where((s) {
      final txCount = currencyCounts[s.currencyCode] ?? s.transactionCount;
      return txCount == 0;
    }).toList()
      ..sort((a, b) => a.currencyCode.compareTo(b.currencyCode));

    final fallbackPrimary = ref.watch(selectedHomeCurrencyCodeProvider);
    final defaultPrimary = widget.preselectPrimary
        ? (filterState.selectedCurrency ?? fallbackPrimary)
        : null;
    final primaryCurrency =
        (_primaryCurrency ?? defaultPrimary ?? '').trim().toUpperCase();
    final selectedCurrencySet = _normalizeCurrencySelection(
      _selectedCurrencies ??
          filterState.normalizedSelectedCurrencies ??
          <String>[primaryCurrency],
    ).toSet();

    // Initialize stable list on first load
    if (_stableCurrencyCodes == null && allCurrencySummaries.isNotEmpty) {
      _initializeStableCurrencyList(
        _applyCustomOrder(activeCurrencies),
        _applyCustomOrder(inactiveCurrencies),
        primaryCurrency,
      );
    }

    // Map stable codes back to summaries (preserving the stable order)
    final stableSummaries = (_stableCurrencyCodes ?? []).map((code) {
      return allCurrencySummaries.firstWhere(
        (s) => s.currencyCode == code,
        orElse: () => CurrencySummary(
          currencyCode: code,
          totalExpenses: 0,
          totalIncome: 0,
          totalBudget: 0,
          transactionCount: 0,
        ),
      );
    }).toList();

    // Apply search filter (by currency code or symbol)
    final query = _searchQuery.trim().toLowerCase();
    List<CurrencySummary> visibleCurrencies;
    if (query.isNotEmpty) {
      // When searching, bypass the "show all" toggle and search across all summaries
      visibleCurrencies = allCurrencySummaries.where((s) {
        final code = s.currencyCode.toLowerCase();
        final symbol = (currencyOptions[s.currencyCode] ?? '').toLowerCase();
        return code.contains(query) || symbol.contains(query);
      }).toList();
      // Sort search results by primary and selected (optional, but good for UX)
      visibleCurrencies.sort((left, right) {
        int rank(CurrencySummary summary) {
          if (summary.currencyCode == primaryCurrency) return 0;
          if (selectedCurrencySet.contains(summary.currencyCode)) return 1;
          return 2;
        }

        return rank(left).compareTo(rank(right));
      });
    } else {
      // Respect the "show all currencies" toggle using the stable list
      if (_showAllCurrencies) {
        visibleCurrencies = stableSummaries;
      } else {
        visibleCurrencies = stableSummaries.where((s) {
          final txCount = currencyCounts[s.currencyCode] ?? s.transactionCount;
          // Always show primary or included currencies even if inactive
          return txCount > 0 ||
              s.currencyCode == primaryCurrency ||
              selectedCurrencySet.contains(s.currencyCode);
        }).toList();
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        backgroundColor: colorScheme.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.foreground),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Text(
          context.l10n.selectCurrency,
          style: TextStyle(
            color: colorScheme.foreground,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => _saveSelection(
                primaryCurrency: primaryCurrency,
                selectedCurrencies: selectedCurrencySet.toList(growable: false),
              ),
              child: Text(
                context.l10n.save,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: colorScheme.mutedForeground,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
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
                      hintText: context.l10n.search,
                      filled: true,
                      fillColor: colorScheme.muted.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        context.push('/currency-rates');
                      },
                      icon:
                          const Icon(Icons.currency_exchange_rounded, size: 16),
                      label: Text(context.l10n.converter),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visibleCurrencies.isEmpty && query.isNotEmpty
                  ? _buildEmptySearchState(context, colorScheme, query)
                  : ReorderableListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      onReorderStart: (index) {
                        HapticFeedback.mediumImpact();
                      },
                      onReorder: (oldIndex, newIndex) {
                        HapticFeedback.lightImpact();

                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }

                        // Reorder the current visible list
                        final reorderedList =
                            List<CurrencySummary>.from(visibleCurrencies);
                        final item = reorderedList.removeAt(oldIndex);
                        reorderedList.insert(newIndex, item);

                        // Update the stable list with the new position of this item
                        if (_stableCurrencyCodes != null) {
                          final newStableOrder =
                              List<String>.from(_stableCurrencyCodes!);
                          final code = item.currencyCode;
                          newStableOrder.remove(code);

                          // Find where to insert in the stable list relative to its neighbors in visible list
                          // If it's the first in visible, put it at index 0 of stable or after other filtered out items
                          // For simplicity, we can just rebuild the stable order by taking all codes in the reordered visible list
                          // and keeping the rest (filtered out) at the end.

                          final visibleCodes =
                              reorderedList.map((s) => s.currencyCode).toSet();
                          final updatedStableOrder = [
                            ...reorderedList.map((s) => s.currencyCode),
                            ..._stableCurrencyCodes!
                                .where((c) => !visibleCodes.contains(c)),
                          ];

                          _saveCustomOrder(updatedStableOrder);
                        }
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
                              isIncluded: selectedCurrencySet
                                  .contains(summary.currencyCode),
                              isPrimary:
                                  primaryCurrency == summary.currencyCode,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final next = selectedCurrencySet.toSet();
                                if (primaryCurrency.isEmpty) {
                                  next.add(summary.currencyCode);
                                  setState(() {
                                    _primaryCurrency = summary.currencyCode;
                                    _selectedCurrencies = next.toList();
                                  });
                                  return;
                                }
                                if (summary.currencyCode == primaryCurrency) {
                                  AppToast.warning(
                                    context,
                                    context.l10n.setAnotherCurrencyAsPrimary,
                                  );
                                  next.add(summary.currencyCode);
                                } else if (next
                                    .contains(summary.currencyCode)) {
                                  next.remove(summary.currencyCode);
                                } else {
                                  next.add(summary.currencyCode);
                                }
                                setState(() {
                                  _selectedCurrencies = next.toList();
                                });
                              },
                              onPrimaryTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _primaryCurrency = summary.currencyCode;
                                  _selectedCurrencies =
                                      _normalizeCurrencySelection([
                                    summary.currencyCode,
                                    ...selectedCurrencySet,
                                  ]);
                                });
                              },
                            ),
                          ),

                        // Show all currencies toggle button
                        if (inactiveCurrencies.isNotEmpty && query.isEmpty)
                          GestureDetector(
                            key: const Key('show_all_toggle'),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _showAllCurrencies = !_showAllCurrencies;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  _showAllCurrencies
                                      ? context.l10n.showLessCurrencies
                                      : context.l10n.showAllCurrencies(
                                          inactiveCurrencies.length),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.primary,
                                  ),
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
                label: context.l10n.email,
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

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: flagPath != null
            ? Image.asset(
                flagPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildSymbolFallback(),
              )
            : _buildSymbolFallback(),
      ),
    );
  }

  Widget _buildSymbolFallback() {
    return Container(
      color: colorScheme.muted,
      child: Center(
        child: Text(
          currencySymbol,
          style: TextStyle(
            fontSize: 18,
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
  final bool isIncluded;
  final bool isPrimary;
  final VoidCallback onTap;
  final VoidCallback onPrimaryTap;

  const _CurrencyCard({
    required this.summary,
    required this.transactionCount,
    required this.isIncluded,
    required this.isPrimary,
    required this.onTap,
    required this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencySymbol = resolveCurrencySymbol(summary.currencyCode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary
                ? colorScheme.primary.withValues(alpha: 0.04)
                : colorScheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.surfaceBorder.withValues(alpha: 0.12),
              width: isPrimary ? 1.5 : 1,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // 1. Checkbox on the very left
              Icon(
                isIncluded
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 24,
                color: isIncluded
                    ? colorScheme.success
                    : colorScheme.mutedForeground.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),

              // 2. Currency Icon
              _CurrencyIcon(
                currencyCode: summary.currencyCode,
                currencySymbol: currencySymbol,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 14),

              // 3. Body: Currency Code & Transaction Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.currencyCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$transactionCount ${transactionCount != 1 ? context.l10n.txns : context.l10n.txn}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Primary Selection on the right
              if (isIncluded)
                _PrimaryPill(
                  isPrimary: isPrimary,
                  onTap: onPrimaryTap,
                  colorScheme: colorScheme,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped toggle for setting the primary currency with an external tooltip
class _PrimaryPill extends StatelessWidget {
  final bool isPrimary;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _PrimaryPill({
    required this.isPrimary,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final tooltipMessage =
        context.l10n.baseCurrencyTooltip;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPrimary ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPrimary
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              isPrimary ? context.l10n.base : context.l10n.makeBase,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : colorScheme.primary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        if (isPrimary) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: tooltipMessage,
            triggerMode: TooltipTriggerMode.tap,
            preferBelow: false,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.foreground.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: TextStyle(
              color: colorScheme.appBackground,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.mutedForeground.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
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
