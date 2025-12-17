import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:moneko/core/theme/theme.dart'; // Unnecessary (covered by core.dart)

import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';

import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:image_picker/image_picker.dart';

import 'package:moneko/features/households/presentation/widgets/household_home_content.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/widgets/mom_trend_bar.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_target.dart';
import 'package:moneko/features/home/presentation/state/home_spotlight_providers.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/insights/presentation/widgets/category_guide_dialog.dart';
import 'package:skeletonizer/skeletonizer.dart';

// ============================================================================
// HOME PAGE
// ============================================================================

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  late final SpotlightTourController _fabTourController;

  @override
  void initState() {
    super.initState();

    _fabTourController = ref.read(homeSpotlightControllerProvider);

    // Initialize filters on first mount
    // NOTE: Analytics data is loaded by app_initialization_provider - no need to trigger here
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize currency filter on first load (one-time)
      // Check provider state instead of local flag to prevent race conditions
      final currentCurrency = ref.read(homeFilterProvider).selectedCurrency;
      if (currentCurrency == null) {
        await _initializeCurrencyFilter();
      }

      // Initialize date range filter from local storage
      await _initializeDateRangeFilter();
    });
  }

  Future<void> _initializeCurrencyFilter() async {
    // Early exit if already initialized (idempotency check)
    if (ref.read(homeFilterProvider).selectedCurrency != null) {
      return;
    }

    // Read current analytics data once (not listening to changes)
    final analyticsData = ref.read(analyticsProvider);
    final service = ref.read(currencyPreferenceServiceProvider);

    String selectedCurrency = 'USD'; // Default to USD

    // 1. Try local storage first
    try {
      final storedCurrency = await service.getSelectedCurrency();
      if (storedCurrency != null && storedCurrency.isNotEmpty) {
        selectedCurrency = storedCurrency;
      }
    } catch (e) {
      debugPrint('Error loading currency from storage: $e');
    }

    // 2. If no stored currency, use preferred currency if available
    if (selectedCurrency == 'USD' &&
        analyticsData.contact?.preferredCurrency != null) {
      selectedCurrency =
          analyticsData.contact!.preferredCurrency!.toUpperCase();
    }

    // Always set the currency (never null, always defaults to USD)
    if (mounted) {
      ref
          .read(homeFilterProvider.notifier)
          .setSelectedCurrency(selectedCurrency);
    }
  }

  Future<void> _initializeDateRangeFilter() async {
    try {
      final service = ref.read(dateRangePreferenceServiceProvider);
      final stored = await service.getSelectedDateRange();
      if (stored != null && stored.isNotEmpty) {
        final matched = DateRangeFilter.values.firstWhere(
          (e) => e.name == stored,
          orElse: () => DateRangeFilter.last30Days,
        );
        if (!mounted) return;
        final current = ref.read(homeFilterProvider).dateRangeFilter;
        if (current != matched) {
          ref.read(homeFilterProvider.notifier).setFilter(matched);
        }
      }
    } catch (e) {
      debugPrint('Error loading date range filter from storage: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  Future<void> _handleCameraCapture() async {
    debugPrint('🎥 Starting camera capture...');

    try {
      // On iOS, image_picker handles permissions internally
      // Just try to open the camera directly
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      debugPrint('🎥 Photo captured: ${photo != null}');

      if (photo != null && mounted) {
        await _processExpense(imagePath: photo.path);
      } else if (photo == null) {
        debugPrint('🎥 User cancelled or permission denied');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
            context, '${context.l10n.failedToCapturePhoto}: ${e.toString()}');
      }
    }
  }

  Future<void> _processExpense({
    String? text,
    String? imagePath,
    Uint8List? audioBytes,
    String? audioContentType,
  }) async {
    final user = ref.read(authProvider);
    final contact = ref.read(analyticsProvider).contact;

    // Show processing modal
    if (!mounted) return;

    showBlockingProcessingDialog(
      context: context,
      message: imagePath != null
          ? context.l10n.analyzingReceipt
          : context.l10n.analyzingExpense,
    );

    try {
      final locale = Localizations.localeOf(context);
      final languageTag =
          locale.countryCode != null && locale.countryCode!.isNotEmpty
              ? '${locale.languageCode}-${locale.countryCode!.toUpperCase()}'
              : locale.languageCode;

      Map<String, dynamic> body = {
        'userId': user.uid,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'language': languageTag,
      };

      // Always use selected currency as default (same as personal expense)
      // Backend will use this as a fallback if no currency is detected in the text/image.
      // If this is also missing, backend defaults to USD.
      final filterState = ref.read(homeFilterProvider);
      final selectedCurrency = filterState.selectedCurrency;
      if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
        body['currency'] = selectedCurrency.toUpperCase();
      } else if (contact?.preferredCurrency != null) {
        body['currency'] = contact!.preferredCurrency!.toUpperCase();
      }

      // Add either text, image, audio, or attachments to the request
      if (text != null) {
        body['text'] = text;
      } else if (imagePath != null) {
        // Read image bytes and convert to base64
        final imageFile = File(imagePath);
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        // Determine content type from file extension
        String contentType = 'image/jpeg';
        final extension = imagePath.split('.').last.toLowerCase();
        if (extension == 'png') {
          contentType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          contentType = 'image/jpeg';
        } else if (extension == 'heic') {
          contentType = 'image/heic';
        }

        body['image'] = {
          'data': base64Image,
          'contentType': contentType,
        };
      }

      if (audioBytes != null && audioBytes.isNotEmpty) {
        final base64Audio = base64Encode(audioBytes);
        body['audio'] = {
          'data': base64Audio,
          'contentType': audioContentType ?? 'audio/mpeg',
        };
      }

      // Call analyze-expense endpoint (NEW: doesn't save yet). Backend now classifies income vs expense.
      final response = await supabase.functions.invoke(
        'analyze-expense',
        body: body,
      );

      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      debugPrint('=== ANALYSIS RESPONSE ===');
      debugPrint('response.data: ${response.data}');
      debugPrint('========================');

      if (response.data != null && response.data['success'] == true) {
        final responseData = response.data['data'];

        if (responseData != null && responseData['items'] != null) {
          List items = List.from(responseData['items'] as List);
          // Safety filter: drop total/subtotal rows when multiple items exist
          if (items.length > 1) {
            bool isTotalLike(dynamic it) {
              final desc = (it is Map && it['description'] is String)
                  ? (it['description'] as String)
                  : '';
              return RegExp(r'(sub\s*total|subtotal|grand\s*total|total)',
                      caseSensitive: false)
                  .hasMatch(desc);
            }

            final filtered = items.where((it) => !isTotalLike(it)).toList();
            if (filtered.isNotEmpty) items = filtered;
            // Additional check: if any item equals sum of others, drop it
            double amt(dynamic it) {
              final a = (it is Map && it['amount'] != null)
                  ? (it['amount'] as num).toDouble()
                  : 0.0;
              return a;
            }

            items = items.where((it) {
              final others = items.where((x) => !identical(x, it)).toList();
              final sumOthers = others.fold<double>(0.0, (s, x) => s + amt(x));
              return (amt(it) - sumOthers).abs() > 1e-6;
            }).toList();
          }

          if (items.isNotEmpty) {
            // Parse ALL items from the response
            final parsed = items.map((item) {
              final isIncome =
                  (item['type']?.toString().toLowerCase() == 'income');
              return ParsedExpense(
                isIncome: isIncome,
                amount: (item['amount'] as num).toDouble(),
                // Normalize income categories to at least 'income' umbrella if model returns a granular one
                category: (item['category'] as String?)?.isNotEmpty == true
                    ? (isIncome
                        ? (item['category'] as String)
                        : item['category'] as String)
                    : (isIncome ? 'income' : 'other'),
                currency: item['currency'] as String,
                currencySymbol: item['currencySymbol'] as String? ?? '\$',
                date: DateTime.parse(item['date'] as String),
                description: item['description'] as String?,
                localImagePath: imagePath,
              );
            }).toList();

            // Partition by type to handle mixed cases robustly
            final incomes = parsed.where((p) => p.isIncome).toList();
            final expenses = parsed.where((p) => !p.isIncome).toList();

            if (parsed.length == 1) {
              ref.read(pendingExpenseProvider.notifier).state = parsed.first;
              showUnifiedTransactionSheet(
                context,
                newExpense: parsed.first,
                localImagePath: imagePath,
              );
            } else if (incomes.isNotEmpty && expenses.isNotEmpty) {
              // We don't auto-merge mixed types. Ask user to submit separately.
              AppToast.info(context,
                  '${context.l10n.failedToAnalyzeNoData} (mixed income and expense detected; please submit separately)');
            } else if (incomes.isNotEmpty) {
              // Multiple income items - combine into a single summarized income
              _showMultiIncomeConfirmation(incomes, imagePath);
            } else {
              // Multiple expenses - combine existing behavior
              _showMultiExpenseConfirmation(expenses, imagePath);
            }
          } else {
            AppToast.info(context, context.l10n.noExpenseInformationExtracted);
          }
        } else {
          AppToast.info(context, context.l10n.failedToAnalyzeNoData);
        }
      } else {
        final error = response.data?['error'] ?? context.l10n.failedToAnalyze;
        AppToast.error(context, '${context.l10n.failedToAnalyze}: $error');
      }
    } catch (e) {
      debugPrint('=== ERROR IN ANALYSIS: $e ===');
      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      String errorMessage;
      // Check if exception has a 'details' property with an 'error' field
      if (e.runtimeType.toString().contains('Exception') &&
          e.toString().contains('status: 400') &&
          e.toString().contains('details:')) {
        // Parse the error from the exception string representation
        final detailsMatch =
            RegExp(r'details: \{([^}]+)\}').firstMatch(e.toString());
        if (detailsMatch != null) {
          final detailsStr = detailsMatch.group(1) ?? '';
          final errorMatch = RegExp(r'error: ([^,]+)').firstMatch(detailsStr);
          if (errorMatch != null) {
            errorMessage = errorMatch.group(1)?.replaceAll("'", '').trim() ??
                context.l10n.failedToAnalyze;
          } else {
            errorMessage = context.l10n.failedToAnalyze;
          }
        } else {
          errorMessage = context.l10n.failedToAnalyze;
        }
      } else {
        errorMessage = e.toString();
      }

      AppToast.error(context, '${context.l10n.failedToAnalyze}: $errorMessage');
    }
  }

  void _showMultiExpenseConfirmation(
      List<ParsedExpense> expenses, String? imagePath) {
    // Calculate total amount
    final totalAmount =
        expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

    // Get most common category or use 'other'
    final categoryCount = <String, int>{};
    for (final expense in expenses) {
      categoryCount[expense.category] =
          (categoryCount[expense.category] ?? 0) + 1;
    }
    final mostCommonCategory =
        categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Use AI-generated descriptions as-is - DO NOT append amounts (AI already includes them)
    final itemDescriptions = expenses
        .map((e) => e.description ?? e.category)
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    // Create single combined expense
    final combinedExpense = ParsedExpense(
      amount: totalAmount,
      category: mostCommonCategory,
      currency: expenses.first.currency,
      currencySymbol: expenses.first.currencySymbol,
      date: expenses.first.date,
      description: itemDescriptions,
      localImagePath: imagePath,
    );

    // Store in provider and show unified sheet
    ref.read(pendingExpenseProvider.notifier).state = combinedExpense;
    showUnifiedTransactionSheet(
      context,
      newExpense: combinedExpense,
      localImagePath: imagePath,
    );
  }

  void _showMultiIncomeConfirmation(
      List<ParsedExpense> incomes, String? imagePath) {
    // Sum all income amounts and use AI-generated descriptions as-is
    final totalAmount = incomes.fold<double>(0, (sum, inc) => sum + inc.amount);

    // Use AI-generated descriptions directly - DO NOT add prefixes or modify
    final combinedDescription = incomes
        .map((e) => e.description ?? e.category)
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    final combined = ParsedExpense(
      isIncome: true,
      amount: totalAmount,
      category: 'income',
      currency: incomes.first.currency,
      currencySymbol: incomes.first.currencySymbol,
      date: incomes.first.date,
      description: combinedDescription.isNotEmpty
          ? combinedDescription
          : context.l10n.income,
      localImagePath: imagePath,
    );

    ref.read(pendingExpenseProvider.notifier).state = combined;
    showUnifiedTransactionSheet(
      context,
      newExpense: combined,
      localImagePath: imagePath,
    );
  }

  // ignore: unused_element
  void _showTextInputDrawer() {
    showTextInputDrawer(
      context,
      _textController,
      (text) async {
        await _processExpense(text: text);
      },
      onSubmitAudio: (audioBytes, contentType) async {
        await _processExpense(
          audioBytes: audioBytes,
          audioContentType: contentType,
        );
      },
    );
  }

  Future<void> _startFabTourIfNeeded() async {
    await _fabTourController.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);
    final filterState = ref.watch(homeFilterProvider);
    final user = ref.watch(authProvider);
    final viewMode = ref.watch(viewModeProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));

    // Global currency remains shared; date ranges move to per-card filters
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();

    // Base personal transactions filtered by currency globally
    // This ensures ALL widgets receive currency-filtered data
    final personalExpensesAll = analyticsData.allExpenses.where((e) {
      // Filter by personal (non-household) transactions
      if (e.householdId != null) return false;
      // Filter by selected currency (if set)
      if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
        final expenseCurrency = (e.currency ?? '').toUpperCase();
        if (expenseCurrency.isNotEmpty && expenseCurrency != selectedCurrency) {
          return false;
        }
      }
      return true;
    }).toList();

    // Net cashflow card: its own per-card filter (still uses allExpenses for previous-period math)
    final netFilterState =
        ref.watch(cardDateFilterProvider(HomeCardFilterId.netCashflow));
    final netRange = getDateRangeFromFilter(
      netFilterState.dateRangeFilter,
      netFilterState.customStartDate,
      netFilterState.customEndDate,
    );
    final netFrom = netRange['from']!;
    final netTo = netRange['to']!;

    // Budgets filtered for the net cashflow / spending breakdown cards (by date + currency)
    final netBudgets = analyticsData.allBudgets.where((budget) {
      final d = DateTime(budget.date.year, budget.date.month, budget.date.day);
      final dateOk = !d.isBefore(netFrom) && !d.isAfter(netTo);
      final currencyOk = selectedCurrency == null ||
          (budget.currency?.toUpperCase() == selectedCurrency);
      return dateOk && currencyOk;
    }).toList();

    final isInitialAnalyticsLoading =
        analyticsData.isLoading && !(analyticsData.hasLoadedOnce ?? false);

    final shouldShowFab = _shouldShowFAB(viewMode, householdsAsync);

    if (shouldShowFab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startFabTourIfNeeded();
      });
    }

    final scrollView = CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (viewMode.mode == ViewMode.household) ...[
          const HouseholdHomeContent(),
          const SliverToBoxAdapter(child: EditDashboardButton()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ] else ...[
          // Personal mode - show customizable dashboard
          Consumer(
            builder: (context, ref, _) {
              final repoAsync = ref.watch(dashboardRepositoryFutureProvider);

              return repoAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, st) => SliverToBoxAdapter(
                  child:
                      Text('${context.l10n.errorInitializingRepository}: $e'),
                ),
                data: (_) {
                  final dashboardAsync =
                      ref.watch(personalDashboardProvider(user.uid));

                  return dashboardAsync.when(
                    loading: () => const SliverToBoxAdapter(
                        child: SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()))),
                    error: (e, st) => SliverToBoxAdapter(
                        child:
                            Text('${context.l10n.errorLoadingDashboard}: $e')),
                    data: (configs) {
                      return DraggableDashboardList(
                        configs: configs,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .reorder(oldIndex, newIndex);
                        },
                        onToggleVisibility: (id) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .toggleVisibility(id);
                        },
                        onUpdateConfig: (id,
                            {dateRange, viewMode, start, end}) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .updateConfig(id,
                                  dateRange: dateRange,
                                  viewMode: viewMode,
                                  start: start,
                                  end: end);
                        },
                        widgetBuilders: {
                          DashboardWidgetType.spendingSummary:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: buildSpendingCard(
                                      context,
                                      colorScheme,
                                      personalExpensesAll,
                                      analyticsData.contact,
                                      config.dateRange,
                                      selectedCurrency:
                                          filterState.selectedCurrency,
                                      customStartDate: config.customStartDate,
                                      customEndDate: config.customEndDate,
                                    ),
                                  ),
                          DashboardWidgetType.netCashflow: (context, config) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: SizedBox(
                                  height: 180,
                                  child: Row(
                                    children: [
                                      const Expanded(child: MoMTrendBar()),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: buildNetCashflowCard(
                                          context,
                                          colorScheme,
                                          netBudgets,
                                          analyticsData.allExpenses,
                                          analyticsData.contact,
                                          config.dateRange,
                                          selectedCurrency:
                                              filterState.selectedCurrency,
                                          customStartDate:
                                              config.customStartDate,
                                          customEndDate: config.customEndDate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          DashboardWidgetType.financialCalendar: (context,
                                  config) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    // NOTE: Recurring transactions are loaded by app_initialization_provider
                                    // Just watch the data here - no need to trigger load
                                    final recurringAsync = ref.watch(
                                        recurringTransactionsProvider(null));
                                    return FinancialCalendarWidget(
                                      transactions: personalExpensesAll,
                                      recurringTransactions:
                                          recurringAsync.data.valueOrNull ?? [],
                                      currency: selectedCurrency ??
                                          analyticsData
                                              .contact?.preferredCurrency ??
                                          'USD',
                                      isExpanded: config.viewMode ==
                                          DashboardWidgetViewMode.full,
                                    );
                                  },
                                ),
                              ),
                          DashboardWidgetType.recentTransactions:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: buildRecentTransactionsCard(
                                      context,
                                      colorScheme,
                                      personalExpensesAll,
                                      analyticsData.contact,
                                      selectedCurrency:
                                          filterState.selectedCurrency,
                                      onViewAll: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const TransactionsPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          DashboardWidgetType.spendingBreakdownChart:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: buildSpendingBreakdownChart(
                                      context,
                                      colorScheme,
                                      personalExpensesAll,
                                      analyticsData.allBudgets,
                                      analyticsData.contact,
                                      config.dateRange,
                                      selectedCurrency:
                                          filterState.selectedCurrency,
                                      customStartDate: config.customStartDate,
                                      customEndDate: config.customEndDate,
                                    ),
                                  ),
                          DashboardWidgetType.whereTheMoneyWent:
                              (context, config) {
                            final range = getDateRangeFromFilter(
                              config.dateRange,
                              config.customStartDate,
                              config.customEndDate,
                            );
                            final from = range['from']!;
                            final to = range['to']!;

                            final dateFilteredExpenses =
                                personalExpensesAll.where((e) {
                              final d = DateTime(
                                  e.date.year, e.date.month, e.date.day);
                              return !d.isBefore(from) && !d.isAfter(to);
                            }).toList();

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: WhereTheMoneyWentWidget(
                                expenses: dateFilteredExpenses,
                                currency: filterState.selectedCurrency,
                                onHelpTap: () =>
                                    showCategoryGuide(context, colorScheme),
                                dateRange: config.dateRange,
                              ),
                            );
                          },
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          // Edit Button
          const SliverToBoxAdapter(child: EditDashboardButton()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ], // end of else block for Personal mode
      ],
    );

    final scrollContent = viewMode.mode == ViewMode.personal
        ? Skeletonizer(
            enabled: isInitialAnalyticsLoading,
            effect: ShimmerEffect(
              baseColor: colorScheme.skeletonBase,
              highlightColor: colorScheme.skeletonHighlight,
            ),
            child: scrollView,
          )
        : scrollView;

    return AdaptiveScaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              final user = ref.read(authProvider);
              if (user.uid.isEmpty) return;

              // Refresh based on current view mode
              if (viewMode.mode == ViewMode.household) {
                // In household mode: invalidate ALL household-related providers
                debugPrint('🔄 Pull-to-refresh: Refreshing household data');
                ref.read(cacheInvalidatorProvider).invalidateAll();
                ref.invalidate(userHouseholdsProvider(user.uid));
                ref.invalidate(householdExpensesProvider);
                ref.invalidate(cachedHouseholdExpensesProvider);
                ref.invalidate(householdSplitsProvider);
                ref.invalidate(cachedHouseholdSplitsProvider);
                ref.invalidate(householdBudgetsProvider);
                ref.invalidate(householdSummaryProvider);
                ref.invalidate(householdMembersProvider);
                debugPrint(
                    '✅ Invalidated: households, expenses, splits, cached splits/expenses, budgets, summary, members');
              } else {
                // In personal mode: refresh analytics with current date filters
                // TODO: Once global date filter is fully removed, refresh should
                // simply reload all-time analytics without a date window.
                await ref.read(analyticsProvider.notifier).loadData(user.uid);
              }

              // Keep other tabs and selectors consistent.
              ref.invalidate(pocketsProvider);
              ref.invalidate(currencyTransactionCountsProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: scrollContent,
          ),
        ],
      ),
      floatingActionButton: _shouldShowFAB(viewMode, householdsAsync)
          ? SpotlightTarget(
              controller: _fabTourController,
              id: 'home_unified_fab',
              title: context.l10n.homeFabTourTitle,
              description: context.l10n.homeFabTourDescription,
              placement: SpotlightPlacement.top,
              padding: 6,
              borderRadius: 34,
              child: const Padding(
                padding: EdgeInsets.all(0),
                child: HomeAiExpandableFab(),
              ),
            )
          : null,
    );
  }

  /// Determine if FAB should be shown
  /// Hide FAB when in household mode with no households (showing onboarding)
  bool _shouldShowFAB(
      ViewModeState viewMode, AsyncValue<List<Household>> householdsAsync) {
    // Always show FAB in personal mode
    if (viewMode.mode == ViewMode.personal) {
      return true;
    }

    // In household mode, hide FAB if households are empty (showing onboarding)
    return householdsAsync.maybeWhen(
      data: (households) => households.isNotEmpty,
      orElse: () => true, // Show FAB during loading or error states
    );
  }

  // Global date helpers have been removed; per-card filters now own all
  // date-range logic, and analytics loads all-time data.
}
