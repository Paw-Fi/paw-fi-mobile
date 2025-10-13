import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  void initState() {
    super.initState();

    // Load data on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider);
      final analyticsData = ref.read(analyticsProvider);

      // Only load if not already loaded or if there's an error
      if (analyticsData.isLoading || analyticsData.error != null ||
          (analyticsData.contact == null && analyticsData.expenses.isEmpty)) {
        ref.read(analyticsProvider.notifier).loadData(user.uid);
      }
    });
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
        final user = ref.read(authProvider);
        final contact = ref.read(analyticsProvider).contact;

        if (contact == null) {
          _showToast('No contact found. Please link your WhatsApp first.');
          return;
        }

        // Show processing toast
        _showProcessingToast('Processing receipt...');

        try {
          debugPrint('=== STARTING IMAGE PROCESSING ===');
          await ref.read(expenseProcessingProvider.notifier).processImage(
            File(photo.path),
            contact.phoneE164,
          );
          debugPrint('=== IMAGE PROCESSING COMPLETED ===');

          // Hide processing toast
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }

          // Show success toast with View link
          final processingState = ref.read(expenseProcessingProvider);
          debugPrint('=== PROCESSING STATE: createdExpense is ${processingState.createdExpense != null ? "NOT NULL" : "NULL"} ===');

          if (processingState.createdExpense != null && mounted) {
            debugPrint('=== SHOWING SUCCESS TOAST ===');
            _showSuccessToast(processingState.createdExpense!, contact, localImagePath: processingState.localImagePath);
          }

          // Refresh analytics data immediately
          final userId = user.uid;
          if (userId.isNotEmpty) {
            debugPrint('=== REFRESHING ANALYTICS DATA FOR USER: $userId ===');
            await ref.read(analyticsProvider.notifier).loadData(userId);
            debugPrint('=== ANALYTICS DATA REFRESH COMPLETED ===');
          } else {
            debugPrint('=== ERROR: User ID is null or empty, cannot refresh analytics ===');
          }
        } catch (e) {
          debugPrint('=== ERROR IN IMAGE PROCESSING: $e ===');
          // Hide processing toast
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _showToast('Failed to process receipt. Please try again.');
          }
        }
      } else if (photo == null) {
        debugPrint('🎥 User cancelled or permission denied');
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to capture photo: ${e.toString()}');
      }
    }
  }

  void _showTextInputDrawer() {
    showTextInputDrawer(context, _textController);
  }

  void _showJointAccountModal() {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    showJointAccountModal(context, colorScheme);
  }

  void _showDateRangeFilter() {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final user = ref.read(authProvider);
    showDateRangeFilter(context, colorScheme, user.uid);
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

  void _showProcessingToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(minutes: 5), // Long duration, will be dismissed manually
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPermissionDeniedToast() {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                'Camera permission is required. Please enable it in Settings.',
                style: TextStyle(color: colorScheme.primaryForeground),
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                openAppSettings();
              },
              child: Text(
                'Settings',
                style: TextStyle(
                  color: colorScheme.primaryForeground,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.destructive,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                style: TextStyle(color: colorScheme.primaryForeground),
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
                  color: colorScheme.primaryForeground,
                  decoration: TextDecoration.underline,
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
    final user = ref.watch(authProvider);

    if (analyticsData.isLoading) {
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

    // Check if user has EVER logged expenses (not just in current filter)
    // We only show the empty state if they have absolutely no historical data
    final hasHistoricalData = analyticsData.contact != null;
    final hasExpensesInCurrentFilter = analyticsData.expenses.isNotEmpty;

    // Show empty state ONLY if user has never logged any expenses
    if (!hasHistoricalData || (hasHistoricalData && !hasExpensesInCurrentFilter && analyticsData.dateRangeFilter == DateRangeFilter.last30Days)) {
      // This is the first-time user experience
      if (analyticsData.expenses.isEmpty && analyticsData.dateRangeFilter == DateRangeFilter.last30Days) {
        return Scaffold(
          backgroundColor: colorScheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: colorScheme.mutedForeground,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Expenses Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start logging your expenses to see your analytics here.',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: _buildExpandableFAB(colorScheme),
        );
      }
    }

    // Listen for processing state changes and show toasts
    ref.listen<ProcessingState>(expenseProcessingProvider, (previous, next) {
      if (previous?.message != next.message && next.message != null) {
        _showToast(next.message!);
        // Clear message after showing
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ref.read(expenseProcessingProvider.notifier).clearMessage();
          }
        });
      }
    });

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
                          // Account Type Switch
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.muted,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Single (Active)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'Single',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                // Joint (Inactive - clickable)
                                GestureDetector(
                                  onTap: _showJointAccountModal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Text(
                                      'Joint',
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
                        ],
                      ),
                    ),
                  ),

                  // Period Selector
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Personal',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.foreground,
                            ),
                          ),
                          GestureDetector(
                            onTap: _showDateRangeFilter,
                            child: Row(
                              children: [
                                Text(
                                  analyticsData.dateRangeFilter.label,
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

                  // Spending Card with Line Chart
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: buildSpendingCard(colorScheme, analyticsData.expenses, analyticsData.contact, analyticsData.dateRangeFilter),
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
                            child: buildBudgetCard(colorScheme, analyticsData.budgets, analyticsData.expenses, analyticsData.contact),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 200,
                            child: buildNetCashflowCard(colorScheme, analyticsData.budgets, analyticsData.expenses, analyticsData.contact),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Overview Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Category Breakdown
                  if (_getCategorySummaries(analyticsData.expenses).isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: buildCategoryBreakdownCard(context, colorScheme, analyticsData.expenses, analyticsData.contact),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (_getCategorySummaries(analyticsData.expenses).isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: buildSpendingBreakdownChart(colorScheme, analyticsData.expenses, analyticsData.contact),
                      ),
                    ),

                 

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildExpandableFAB(colorScheme),
    );
  }

  List<CategorySummary> _getCategorySummaries(List<ExpenseEntry> expenses) {
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};

    for (final expense in expenses) {
      if (expense.amountCents > 0) {
        final cat = (expense.category ?? 'uncategorized').toLowerCase();
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount;
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
    }

    return categoryTotals.entries.map((e) {
      return CategorySummary(
        category: e.key,
        amount: e.value,
        transactionCount: categoryCounts[e.key] ?? 0,
        color: getCategoryColor(e.key),
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  Widget _buildExpandableFAB(shadcnui.ColorScheme colorScheme) {
    return ExpandableFab(
      distance: 90,
      children: [
        ActionButton(
          onPressed: _showTextInputDrawer,
          icon: const Icon(Icons.text_fields),
          label: 'Free form text',
        ),
        ActionButton(
          onPressed: _handleCameraCapture,
          icon: const Icon(Icons.camera_alt),
          label: 'Take photo',
        ),
      ],
    );
  }
}
