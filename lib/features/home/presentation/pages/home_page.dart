import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:moneko/core/theme/theme.dart'; // Unnecessary (covered by core.dart)
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/households/presentation/widgets/household_home_content.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/widgets/mom_trend_bar.dart';
import 'package:moneko/features/home/presentation/widgets/currency_dropdown_button.dart';
// Removed unused imports

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
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();

  @override
  void initState() {
    super.initState();

    // Load data on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authProvider);
      final analyticsData = ref.read(analyticsProvider);

      // Only load if we've NEVER loaded successfully before
      // Don't reload if data already exists, even if there was a previous error
      if (!(analyticsData.hasLoadedOnce ?? false)) {
        ref.read(analyticsProvider.notifier).loadData(user.uid);
      }
      
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
    if (selectedCurrency == 'USD' && analyticsData.contact?.preferredCurrency != null) {
      selectedCurrency = analyticsData.contact!.preferredCurrency!.toUpperCase();
    }
    
    // Always set the currency (never null, always defaults to USD)
    if (mounted) {
      ref.read(homeFilterProvider.notifier).setSelectedCurrency(selectedCurrency);
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

  /// Helper to get date range from current filter
  Map<String, DateTime?> _getDateRangeFromFilter() {
    final filter = ref.read(homeFilterProvider).dateRangeFilter;
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate = now;
    
    switch (filter) {
      case DateRangeFilter.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case DateRangeFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case DateRangeFilter.thisWeek:
        // Start from Monday
        final weekday = now.weekday;
        startDate = now.subtract(Duration(days: weekday - 1));
        break;
      case DateRangeFilter.lastWeek:
        final weekday = now.weekday;
        final lastMonday = now.subtract(Duration(days: weekday + 6));
        final lastSunday = now.subtract(Duration(days: weekday));
        startDate = DateTime(lastMonday.year, lastMonday.month, lastMonday.day);
        endDate = DateTime(lastSunday.year, lastSunday.month, lastSunday.day, 23, 59, 59);
        break;
      case DateRangeFilter.last30Days:
        startDate = now.subtract(const Duration(days: 30));
        break;
      case DateRangeFilter.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case DateRangeFilter.allTime:
        startDate = null;
        endDate = null;
        break;
      case DateRangeFilter.custom:
        // For custom, use filter's custom dates if available
        startDate = null;
        endDate = null;
        break;
    }
    
    return {'startDate': startDate, 'endDate': endDate};
  }

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
        _showToast('${context.l10n.failedToCapturePhoto}: ${e.toString()}');
      }
    }
  }

  Future<void> _processExpense({String? text, String? imagePath}) async {
    final user = ref.read(authProvider);
    final contact = ref.read(analyticsProvider).contact;
    final viewMode = ref.read(viewModeProvider);
    final selectedHouseholdState = ref.read(selectedHouseholdProvider);

    // Show processing modal
    if (!mounted) return;
    
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/assets/gifs/loading-anim.gif',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  imagePath != null ? context.l10n.analyzingReceipt : context.l10n.analyzingExpense,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final locale = Localizations.localeOf(context);
      final languageTag = locale.countryCode != null && locale.countryCode!.isNotEmpty
          ? '${locale.languageCode}-${locale.countryCode!.toUpperCase()}'
          : locale.languageCode;

      Map<String, dynamic> body = {
        'userId': user.uid,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'language': languageTag,
      };
      
      // Determine currency based on view mode
      final filterState = ref.read(homeFilterProvider);
      if (viewMode.mode == ViewMode.household &&
          selectedHouseholdState.household?.currency != null) {
        body['currency'] = selectedHouseholdState.household!.currency.toUpperCase();
      } else {
        final selectedCurrency = filterState.selectedCurrency;
        if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
          body['currency'] = selectedCurrency.toUpperCase();
        } else if (contact?.preferredCurrency != null) {
          body['currency'] = contact!.preferredCurrency!.toUpperCase();
        }
      }

      // Add either text or image to the request
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
              final desc = (it is Map && it['description'] is String) ? (it['description'] as String) : '';
              return RegExp(r'(sub\s*total|subtotal|grand\s*total|total)', caseSensitive: false).hasMatch(desc);
            }
            final filtered = items.where((it) => !isTotalLike(it)).toList();
            if (filtered.isNotEmpty) items = filtered;
            // Additional check: if any item equals sum of others, drop it
            double amt(dynamic it) {
              final a = (it is Map && it['amount'] != null) ? (it['amount'] as num).toDouble() : 0.0;
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
              final isIncome = (item['type']?.toString().toLowerCase() == 'income');
              return ParsedExpense(
                isIncome: isIncome,
                amount: (item['amount'] as num).toDouble(),
                // Normalize income categories to at least 'income' umbrella if model returns a granular one
                category: (item['category'] as String?)?.isNotEmpty == true
                    ? (isIncome ? (item['category'] as String) : item['category'] as String)
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
              _showToast('${context.l10n.failedToAnalyzeNoData} (mixed income and expense detected; please submit separately)');
            } else if (incomes.isNotEmpty) {
              // Multiple income items - combine into a single summarized income
              _showMultiIncomeConfirmation(incomes, imagePath);
            } else {
              // Multiple expenses - combine existing behavior
              _showMultiExpenseConfirmation(expenses, imagePath);
            }
          } else {
            _showToast(context.l10n.noExpenseInformationExtracted);
          }
        } else {
          _showToast(context.l10n.failedToAnalyzeNoData);
        }
      } else {
        final error = response.data?['error'] ?? context.l10n.failedToAnalyze;
        _showToast('${context.l10n.failedToAnalyze}: $error');
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
        final detailsMatch = RegExp(r'details: \{([^}]+)\}').firstMatch(e.toString());
        if (detailsMatch != null) {
          final detailsStr = detailsMatch.group(1) ?? '';
          final errorMatch = RegExp(r'error: ([^,]+)').firstMatch(detailsStr);
          if (errorMatch != null) {
            errorMessage = errorMatch.group(1)?.replaceAll("'", '').trim() ?? context.l10n.failedToAnalyze;
          } else {
            errorMessage = context.l10n.failedToAnalyze;
          }
        } else {
          errorMessage = context.l10n.failedToAnalyze;
        }
      } else {
        errorMessage = e.toString();
      }
      
      AppToast.error('${context.l10n.failedToAnalyze}: $errorMessage');
    }
  }

  void _showMultiExpenseConfirmation(List<ParsedExpense> expenses, String? imagePath) {
    // Calculate total amount
    final totalAmount = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    
    // Get most common category or use 'other'
    final categoryCount = <String, int>{};
    for (final expense in expenses) {
      categoryCount[expense.category] = (categoryCount[expense.category] ?? 0) + 1;
    }
    final mostCommonCategory = categoryCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
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

  void _showMultiIncomeConfirmation(List<ParsedExpense> incomes, String? imagePath) {
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
      description: combinedDescription.isNotEmpty ? combinedDescription : context.l10n.income,
      localImagePath: imagePath,
    );

    ref.read(pendingExpenseProvider.notifier).state = combined;
    showUnifiedTransactionSheet(
      context,
      newExpense: combined,
      localImagePath: imagePath,
    );
  }

  void _showTextInputDrawer() {
    showTextInputDrawer(
      context,
      _textController,
      (text) async {
        // Process the expense with text
        await _processExpense(text: text);
      },
    );
  }

  void _showJointAccountModal() {
    // Simply switch to household mode
    // The HouseholdHomeContent widget will handle loading, empty, and error states
    final user = ref.read(authProvider);
    
    // ✅ CRITICAL: Invalidate households provider to force refresh when switching modes
    debugPrint('🔄 Switching to household mode - invalidating userHouseholdsProvider');
    ref.invalidate(userHouseholdsProvider(user.uid));
    
    ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
  }

  void _showDateRangeFilter() {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    showDateRangeFilter(context, colorScheme, height: 480);
  }

  // Removed unused _showCurrencySelector()

  Future<void> _showBudgetUpdateSheet() async {
    final analytics = ref.read(analyticsProvider);
    final contact = analytics.contact;
    final user = ref.read(authProvider);
    final filterState = ref.read(homeFilterProvider);

    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    
    // Determine the currency for the budget update
    final selectedCurrency = filterState.selectedCurrency ?? contact?.preferredCurrency;
    final currencySymbol = resolveCurrencySymbol(selectedCurrency);
    
    // Get initial amount for the selected currency
    final initialAmount = selectedCurrency != null
        ? _totalBudgetAmountForCurrency(analytics.budgets, selectedCurrency)
        : _totalBudgetAmount(analytics.budgets);
    String rawAmountInput = initialAmount > 0 ? formatAmount(initialAmount) : '';

    String? validationError;

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final sheetColorScheme = shadcnui.Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.updateBudget,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: sheetColorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.enterNewTotalDailyBudget,
                    style: TextStyle(
                      fontSize: 14,
                      color: sheetColorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: rawAmountInput,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: currencySymbol,
                      labelText: context.l10n.budgetAmount,
                      errorText: validationError,
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      rawAmountInput = value;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(context.l10n.cancel),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: shadcnui.PrimaryButton(
                          onPressed: () {
                            final normalizedInput = rawAmountInput.replaceAll(',', '').trim();
                            final parsed = double.tryParse(normalizedInput);

                            if (parsed == null || parsed < 0) {
                              setModalState(() {
                                validationError = context.l10n.enterValidAmountGreaterThan0;
                              });
                              return;
                            }

                            FocusScope.of(sheetContext).unfocus();
                            Navigator.of(sheetContext).pop(parsed);
                          },
                          child: Text(context.l10n.save),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    final capturedAmount = amount;

    if (capturedAmount == null) {
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogScheme = shadcnui.Theme.of(dialogContext).colorScheme;
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: dialogScheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.updatingBudget,
                    style: TextStyle(color: dialogScheme.foreground, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final payload = <String, dynamic>{
        'userId': user.uid,
        'amount': capturedAmount,
      };

      if (contact != null) {
        // Only add phone if it exists (WhatsApp connected)
        if (contact.phoneE164 != null) {
          payload['phone'] = contact.phoneE164;
        }
      }
      
      // Add currency to payload (selected currency or preferred currency)
      if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
        payload['currency'] = selectedCurrency;
      }

      final response = await supabase.functions.invoke(
        'set-budget',
        body: payload,
      );
      debugPrint('Set budget response: $response');

      final data = response.data as Map<String, dynamic>?;

      if (response.status >= 400) {
        final responseError = data?['error'] as String?;
        throw Exception(responseError ?? 'Failed with status ${response.status}');
      }

      if (data == null || data['ok'] != true) {
        final errorMessage = data?['error'] as String? ?? 'Unknown error';
        throw Exception(errorMessage);
      }

      // Update local state with currency-specific budget
      if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
        ref.read(analyticsProvider.notifier).setBudgetAmountForCurrency(selectedCurrency, capturedAmount);
      } else {
        // Fallback to old method if no currency specified
        ref.read(analyticsProvider.notifier).setBudgetAmount(capturedAmount);
      }

      // Refresh analytics data if user is logged in
      if (user.uid.isNotEmpty) {
        ref.read(analyticsProvider.notifier).loadData(user.uid);
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final replyMessage = (data['reply'] as String?)?.trim();
        _showToast(replyMessage?.isNotEmpty == true ? replyMessage! : context.l10n.budgetUpdated);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showToast('${context.l10n.failedToUpdateBudget}: ${e.toString()}');
      }
    }
  }

  void _showToast(String message) {
    AppToast.info(message);
  }

  double _totalBudgetAmount(List<DailyBudgetEntry> budgets) {
    return budgets.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  double _totalBudgetAmountForCurrency(List<DailyBudgetEntry> budgets, String currencyCode) {
    final code = currencyCode.toUpperCase();
    return budgets
        .where((b) => (b.currency ?? '').toUpperCase() == code)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);
    final filterState = ref.watch(homeFilterProvider);
    final filteredExpenses = ref.watch(homeFilteredExpensesProvider);
    final filteredBudgets = ref.watch(homeFilteredBudgetsProvider);
    final user = ref.watch(authProvider);
    final viewMode = ref.watch(viewModeProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));

    // Listen for date filter changes and reload analytics with date filters
    ref.listen<HomeFilterState>(homeFilterProvider, (previous, next) {
      if (previous?.dateRangeFilter != next.dateRangeFilter) {
        debugPrint('🔄 Date filter changed: ${previous?.dateRangeFilter} → ${next.dateRangeFilter}');
        
        final dateRange = _getDateRangeFromFilter();
        final startDate = dateRange['startDate'];
        final endDate = dateRange['endDate'];
        
        debugPrint('🔄 Reloading analytics with date range: $startDate to $endDate');
        ref.read(analyticsProvider.notifier).loadData(
          user.uid,
          startDate: startDate,
          endDate: endDate,
        );
      }
    });

    // Only show loading indicator if we've never loaded before
    // If we have data already, show it even if a refresh is in progress
    if (analyticsData.isLoading && !(analyticsData.hasLoadedOnce ?? false)) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (analyticsData.error != null) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.destructive),
                const SizedBox(height: 16),
                Text(
                  analyticsData.error!,
                  style: TextStyle(color: colorScheme.foreground),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                shadcnui.PrimaryButton(
                  onPressed: () {
                    final dateRange = _getDateRangeFromFilter();
                    ref.read(analyticsProvider.notifier).refresh(
                      user.uid,
                      startDate: dateRange['startDate'],
                      endDate: dateRange['endDate'],
                    );
                  },
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh based on current view mode
                if (viewMode.mode == ViewMode.household) {
                  // In household mode: invalidate ALL household-related providers
                  debugPrint('🔄 Pull-to-refresh: Refreshing household data');
                  ref.invalidate(userHouseholdsProvider(user.uid));
                  ref.invalidate(householdExpensesProvider);
                  ref.invalidate(householdSplitsProvider);
                  ref.invalidate(householdBudgetsProvider);
                  ref.invalidate(householdSummaryProvider);
                  ref.invalidate(householdMembersProvider); // FIXED: Added member info refresh
                  debugPrint('✅ Invalidated: households, expenses, splits, budgets, summary, members');
                } else {
                  // In personal mode: refresh analytics with current date filters
                  final dateRange = _getDateRangeFromFilter();
                  ref.read(analyticsProvider.notifier).refresh(
                    user.uid,
                    startDate: dateRange['startDate'],
                    endDate: dateRange['endDate'],
                  );
                }
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.overview,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                          // Account Type Switch (always visible)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.muted,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Single
                                GestureDetector(
                                  onTap: viewMode.mode == ViewMode.personal
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          SystemSound.play(SystemSoundType.click);
                                          ref.read(viewModeProvider.notifier).setPersonalMode();
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: viewMode.mode == ViewMode.personal
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      context.l10n.forMe,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: viewMode.mode == ViewMode.personal
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: viewMode.mode == ViewMode.personal
                                            ? colorScheme.buttonText
                                            : colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ),
                                // Joint
                                GestureDetector(
                                  onTap: viewMode.mode == ViewMode.household
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          SystemSound.play(SystemSoundType.click);
                                          _showJointAccountModal();
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: viewMode.mode == ViewMode.household
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      context.l10n.forUs,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: viewMode.mode == ViewMode.household
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: viewMode.mode == ViewMode.household
                                            ? colorScheme.buttonText
                                            : colorScheme.mutedForeground,
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
                  ),

                  // Period Selector with Currency Button (shown in both modes; filters household content too)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side:  Currency Button
                          const CurrencyDropdownButton(),
                          // Right side: Date filter
                          GestureDetector(
                            onTap: _showDateRangeFilter,
                            child: Row(
                              children: [
                                Text(
                                  filterState.dateRangeFilter.getLabel(context),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                               
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Switch between Personal and Household content
                  if (viewMode.mode == ViewMode.household)
                    const HouseholdHomeContent()
                  else ...[
                    // Personal mode - show analytics content
                    // Spending Card with Line Chart
                    SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: buildSpendingCard(
                        context,
                        colorScheme, 
                        filteredExpenses, 
                        analyticsData.contact, 
                        filterState.dateRangeFilter,
                        selectedCurrency: filterState.selectedCurrency,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Budget and Net Cashflow Cards (Horizontal Scroll)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        children: [
                          SizedBox(
                            width: 200,
                            child: buildBudgetCard(
                              context,
                              colorScheme,
                              filteredBudgets,
                              filteredExpenses,
                              analyticsData.contact,
                              filterState.dateRangeFilter,
                              onTap: _showBudgetUpdateSheet,
                              selectedCurrency: filterState.selectedCurrency,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 200,
                            child: buildNetCashflowCard(
                              context,
                              colorScheme, 
                              filteredBudgets, 
                              ref.watch(homeFilteredTransactionsProvider), 
                              analyticsData.contact,
                              filterState.dateRangeFilter,
                              selectedCurrency: filterState.selectedCurrency,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // TODO: Add CashflowSparklineCard
                          // const SizedBox(
                          //   width: 200,
                          //   child: CashflowSparklineCard(),
                          // ),
                          // const SizedBox(width: 12),
                          const SizedBox(
                            width: 200,
                            child:  MoMTrendBar(),
                          ),
                          // const SizedBox(width: 12),
                          // const SizedBox(
                          //   width: 200,
                          //   child: SavingsRateTile(),
                          // ),
                          // const SizedBox(width: 12),
                          // const SizedBox(
                          //   width: 200,
                          //   child: RunwayGauge(),
                          // ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),            

                  // Category Breakdown
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TransactionsPage(),
                            ),
                          );
                        },
                        child: buildCategoryBreakdownCard(
                          context, 
                          colorScheme, 
                          ref.watch(homeFilteredTransactionsProvider), 
                          analyticsData.contact,
                          selectedCurrency: filterState.selectedCurrency,
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: buildSpendingBreakdownChart(
                        context,
                        colorScheme, 
                        filteredExpenses,
                        filteredBudgets,
                        analyticsData.contact, 
                        filterState.dateRangeFilter,
                        selectedCurrency: filterState.selectedCurrency,
                      ),
                    ),
                  ),



                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ], // end of else block for Personal mode
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _shouldShowFAB(viewMode, householdsAsync)
          ? _buildExpandableFAB(colorScheme)
          : null,
    );
  }

  /// Determine if FAB should be shown
  /// Hide FAB when in household mode with no households (showing onboarding)
  bool _shouldShowFAB(ViewModeState viewMode, AsyncValue<List<Household>> householdsAsync) {
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

  Widget _buildExpandableFAB(shadcnui.ColorScheme colorScheme) {
    return ExpandableFab(
      key: _fabKey,
      distance: 90,
      children: [
        ActionButton(
          onPressed: () {
            _fabKey.currentState?.close();
            _showTextInputDrawer();
          },
          icon: const Icon(Icons.text_fields),
          label: context.l10n.freeFormText,
        ),
        ActionButton(
          onPressed: () {
            _fabKey.currentState?.close();
            _handleCameraCapture();
          },
          icon: const Icon(Icons.camera_alt),
          label: context.l10n.takePhoto,
        ),
      ],
    );
  }
}
