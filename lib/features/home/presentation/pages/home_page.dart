import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/core/services/feature_flag_service.dart';

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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
        _showToast('Failed to capture photo: ${e.toString()}');
      }
    }
  }

  Future<void> _processExpense({String? text, String? imagePath}) async {
    final user = ref.read(authProvider);
    final contact = ref.read(analyticsProvider).contact;

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
                  imagePath != null ? 'Processing receipt...' : 'Processing expense...',
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
      Map<String, dynamic> body = {
        'userId': user.uid,
        'date': DateTime.now().toIso8601String().split('T')[0],
      };
      
      // Add phone if WhatsApp is connected (optional)
      if (contact?.phoneE164 != null) {
        body['phone'] = contact!.phoneE164;
      }
      
      // Get the currently selected currency from the UI filter
      final filterState = ref.read(homeFilterProvider);
      final selectedCurrency = filterState.selectedCurrency;

      // Send currency with proper fallback chain:
      // Priority: UI selection → Account preference → USD (BE default)
      if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
        body['currency'] = selectedCurrency.toUpperCase();
      } else if (contact?.preferredCurrency != null) {
        body['currency'] = contact!.preferredCurrency!.toUpperCase();
      }
      // Note: If both are null, backend validateCurrency() defaults to USD

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

      // Call the backend
      final response = await supabase.functions.invoke(
        'process-expenses',
        body: body,
      );

      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      // Log the response
      debugPrint('=== PROCESSING RESPONSE ===');
      debugPrint('response.data: ${response.data}');
      debugPrint('=========================');

      if (response.data != null && response.data['success'] == true) {
        final responseData = response.data['data'];
        ExpenseEntry? createdExpense;

        // Parse expense from response - check both 'expenses' and 'items' arrays
        if (responseData != null) {
          List? expensesArray = responseData['expenses'];
          List? itemsArray = responseData['items'];
          
          Map<String, dynamic>? expenseData;
          
          // Try 'expenses' array first (for full expense objects from DB)
          if (expensesArray != null && expensesArray.isNotEmpty) {
            expenseData = expensesArray[0];
          } 
          // Fall back to 'items' array (for parsed items from BE)
          else if (itemsArray != null && itemsArray.isNotEmpty) {
            expenseData = itemsArray[0];
          }

          if (expenseData != null) {
            // Create expense entry from data
            // If 'id' exists, it's from DB, otherwise it's a newly created item
            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              contactId: expenseData['contact_id'] ?? contact?.id,
              amountCents: expenseData['amount_cents'] ?? 
                          (expenseData['amount'] != null ? (expenseData['amount'] * 100).toInt() : 0),
              category: expenseData['category'] ?? 'other',
              date: DateTime.parse(expenseData['date'] ?? DateTime.now().toIso8601String()),
              createdAt: DateTime.parse(expenseData['created_at'] ?? DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'] ?? text ?? 'Receipt image',
              currency: expenseData['currency'] ?? 'USD',
              receiptImageUrl: expenseData['receipt_image_url'],
            );
          }
        }

        if (createdExpense != null) {
          // Show success toast with View link
          _showSuccessToast(
            createdExpense,
            contact,
            localImagePath: imagePath,
          );

          // Refresh analytics data
          final user = ref.read(authProvider);
          if (user.uid.isNotEmpty) {
            ref.read(analyticsProvider.notifier).loadData(user.uid);
          }
        } else {
          _showToast('Failed to process: No expense data returned');
        }
      } else {
        final error = response.data?['error'] ?? 'Failed to process';
        _showToast('Failed to process: $error');
      }
    } catch (e) {
      debugPrint('=== ERROR IN PROCESSING: $e ===');
      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      _showToast('Failed to process: ${e.toString()}');
    }
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
    final user = ref.read(authProvider);
    final householdsState = ref.read(userHouseholdsProvider(user.uid));

    if (!mounted) return;

    householdsState.when(
      data: (households) {
        // If no households, navigate to create one
        if (households.isEmpty) {
          navigateToHousehold(context, ref);
          return;
        }

        // If only one household, switch to it directly
        if (households.length == 1) {
          ref.read(viewModeProvider.notifier).setHouseholdMode(households.first.id);
          return;
        }

        // If multiple households, show selector
        _showHouseholdSelector(households);
      },
      loading: () {
        // Data is still loading, show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading households...')),
        );
      },
      error: (error, stack) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading households: $error')),
        );
      },
    );
  }

  void _showHouseholdSelector(List<Household> households) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Household',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 16),
              ...households.map((household) => ListTile(
                    leading: Text(
                      household.emoji ?? '🏠',
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(household.name),
                    onTap: () {
                      ref.read(viewModeProvider.notifier).setHouseholdMode(household.id);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.add, color: colorScheme.primary),
                title: Text(
                  'Create New Household',
                  style: TextStyle(color: colorScheme.primary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  navigateToHousehold(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateRangeFilter() {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    showDateRangeFilter(context, colorScheme);
  }

  void _showCurrencySelector() {
    showCurrencySelectorModal(context, ref);
  }

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
                    'Update budget',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: sheetColorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the new total daily budget.',
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
                      labelText: 'Budget amount',
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
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: shadcnui.PrimaryButton(
                          onPressed: () {
                            final normalizedInput = rawAmountInput.replaceAll(',', '').trim();
                            final parsed = double.tryParse(normalizedInput);

                            if (parsed == null || parsed <= 0) {
                              setModalState(() {
                                validationError = 'Enter a valid amount greater than 0';
                              });
                              return;
                            }

                            FocusScope.of(sheetContext).unfocus();
                            Navigator.of(sheetContext).pop(parsed);
                          },
                          child: const Text('Save'),
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
                    'Updating budget...',
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
      print(response);

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
        _showToast(replyMessage?.isNotEmpty == true ? replyMessage! : 'Budget updated');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showToast('Failed to update budget: ${e.toString()}');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  void _showSuccessToast(ExpenseEntry expense, UserContact? contact, {String? localImagePath}) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                'Logged successfully',
                style: TextStyle(color: colorScheme.buttonText),
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                showTransactionDetailSheet(context, expense, contact: contact, localImagePath: localImagePath);
              },
              child: Text(
                'View',
                style: TextStyle(
                  color: colorScheme.buttonText,
                  decoration: TextDecoration.underline,
                  decorationColor: colorScheme.buttonText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                  onPressed: () => ref.read(analyticsProvider.notifier).refresh(user.uid),
                  child: const Text('Retry'),
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
                ref.read(analyticsProvider.notifier).refresh(user.uid);
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
                            'Overview',
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
                                      : () => ref.read(viewModeProvider.notifier).setPersonalMode(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: viewMode.mode == ViewMode.personal
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'For me',
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
                                      : _showJointAccountModal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: viewMode.mode == ViewMode.household
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'For us',
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

                  // Period Selector with Currency Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side:  Currency Button
                          Row(
                            children: [
                            
                              // Currency selector button
                              GestureDetector(
                                onTap: _showCurrencySelector,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.muted,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        filterState.selectedCurrency ?? 'USD',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: colorScheme.foreground,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Right side: Date filter
                          GestureDetector(
                            onTap: _showDateRangeFilter,
                            child: Row(
                              children: [
                                Text(
                                  filterState.dateRangeFilter.label,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Show placeholder if in Joint mode but no household selected
                  if (viewMode.mode == ViewMode.household && viewMode.selectedHouseholdId == null)
                    SliverFillRemaining(
                      child: _buildJointPlaceholder(colorScheme),
                    )
                  else ...[
                    // Spending Card with Line Chart
                    SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: buildSpendingCard(
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
                              colorScheme, 
                              filteredBudgets, 
                              filteredExpenses, 
                              analyticsData.contact,
                              filterState.dateRangeFilter,
                              selectedCurrency: filterState.selectedCurrency,
                            ),
                          ),
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
                      child: buildCategoryBreakdownCard(
                        context, 
                        colorScheme, 
                        filteredExpenses, 
                        analyticsData.contact,
                        selectedCurrency: filterState.selectedCurrency,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: buildSpendingBreakdownChart(
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
                  ], // end of else block for Joint placeholder
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildExpandableFAB(colorScheme),
    );
  }

  Widget _buildJointPlaceholder(shadcnui.ColorScheme colorScheme) {
    final user = ref.read(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));

    return householdsAsync.when(
      data: (households) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.muted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_outline,
                    size: 60,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'No Joint Account Yet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  'Create a household to manage finances with your partner, family, or roommates.',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.mutedForeground,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Create Household Button
                shadcnui.PrimaryButton(
                  onPressed: () => navigateToHousehold(context, ref),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text('Create Household'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          'Error loading households',
          style: TextStyle(color: colorScheme.destructive),
        ),
      ),
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
          label: 'Free form text',
        ),
        ActionButton(
          onPressed: () {
            _fabKey.currentState?.close();
            _handleCameraCapture();
          },
          icon: const Icon(Icons.camera_alt),
          label: 'Take photo',
        ),
      ],
    );
  }
}
