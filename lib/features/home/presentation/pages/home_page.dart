import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_detail_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

/// Represents user contact info from user_contacts table
class UserContact {
  final String id;
  final String? userId;
  final String phoneE164;
  final bool verified;
  final String? preferredCurrency;

  UserContact({
    required this.id,
    this.userId,
    required this.phoneE164,
    required this.verified,
    this.preferredCurrency,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) {
    return UserContact(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      phoneE164: json['phone_e164'] as String,
      verified: json['verified'] as bool,
      preferredCurrency: json['preferred_currency'] as String?,
    );
  }
}

/// Represents a single spending entry from expenses table
class ExpenseEntry {
  final String id;
  final String contactId;
  final DateTime date;
  final int amountCents;
  final String? currency;
  final String? category;
  final DateTime createdAt;
  final String? rawText;
  final String? receiptImageUrl;

  ExpenseEntry({
    required this.id,
    required this.contactId,
    required this.date,
    required this.amountCents,
    this.currency,
    this.category,
    required this.createdAt,
    this.rawText,
    this.receiptImageUrl,
  });

  double get amount => amountCents / 100.0;

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      date: DateTime.parse(json['date'] as String),
      amountCents: json['amount_cents'] as int,
      currency: json['currency'] as String?,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      rawText: json['raw_text'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
    );
  }
}

/// Represents a daily budget entry from daily_budgets table
class DailyBudgetEntry {
  final String id;
  final String contactId;
  final DateTime date;
  final int amountCents;
  final String? currency;

  DailyBudgetEntry({
    required this.id,
    required this.contactId,
    required this.date,
    required this.amountCents,
    this.currency,
  });

  double get amount => amountCents / 100.0;

  factory DailyBudgetEntry.fromJson(Map<String, dynamic> json) {
    return DailyBudgetEntry(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      date: DateTime.parse(json['date'] as String),
      amountCents: json['amount_cents'] as int,
      currency: json['currency'] as String?,
    );
  }
}

/// Category summary for charts
class CategorySummary {
  final String category;
  final double amount;
  final int transactionCount;
  final Color color;

  CategorySummary({
    required this.category,
    required this.amount,
    required this.transactionCount,
    required this.color,
  });

  double getPercentage(double total) => total > 0 ? (amount / total) * 100 : 0;
}

// ============================================================================
// CATEGORY COLORS
// ============================================================================

final Map<String, Color> categoryColors = {
  'transfers': const Color(0xFF8B5CF6),
  'shopping': const Color(0xFFEC4899),
  'utilities': const Color(0xFF3B82F6),
  'entertainment': const Color(0xFFF59E0B),
  'restaurants': const Color(0xFF10B981),
  'groceries': const Color(0xFF06B6D4),
  'transport': const Color(0xFFEF4444),
  'health': const Color(0xFF14B8A6),
  'uncategorized': Colors.grey,
};

Color getCategoryColor(String? category) {
  final key = (category ?? 'uncategorized').toLowerCase();
  return categoryColors[key] ?? Colors.grey;
}

IconData getCategoryIcon(String? category) {
  final key = (category ?? 'uncategorized').toLowerCase();
  switch (key) {
    case 'transfers':
      return Icons.swap_horiz;
    case 'shopping':
      return Icons.shopping_bag;
    case 'utilities':
      return Icons.home;
    case 'entertainment':
      return Icons.sports_esports;
    case 'restaurants':
      return Icons.restaurant;
    case 'groceries':
      return Icons.shopping_cart;
    case 'transport':
      return Icons.directions_car;
    case 'health':
      return Icons.favorite;
    default:
      return Icons.category;
  }
}

// ============================================================================
// RIVERPOD STATE MANAGEMENT
// ============================================================================

/// Date range filter options
enum DateRangeFilter {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  last30Days,
  custom,
}

extension DateRangeFilterExtension on DateRangeFilter {
  String get label {
    switch (this) {
      case DateRangeFilter.today:
        return 'Today';
      case DateRangeFilter.yesterday:
        return 'Yesterday';
      case DateRangeFilter.thisWeek:
        return 'This week';
      case DateRangeFilter.lastWeek:
        return 'Last week';
      case DateRangeFilter.thisMonth:
        return 'This month';
      case DateRangeFilter.last30Days:
        return 'Last 30 days';
      case DateRangeFilter.custom:
        return 'Custom range';
    }
  }

  String get spentLabel {
    switch (this) {
      case DateRangeFilter.today:
        return 'Spent today';
      case DateRangeFilter.yesterday:
        return 'Spent yesterday';
      case DateRangeFilter.thisWeek:
        return 'Spent this week';
      case DateRangeFilter.lastWeek:
        return 'Spent last week';
      case DateRangeFilter.thisMonth:
        return 'Spent this month';
      case DateRangeFilter.last30Days:
        return 'Spent (last 30 days)';
      case DateRangeFilter.custom:
        return 'Spent (custom)';
    }
  }
}

/// Analytics data state
class AnalyticsData {
  final UserContact? contact;
  final List<ExpenseEntry> expenses;
  final List<DailyBudgetEntry> budgets;
  final bool isLoading;
  final String? error;
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  AnalyticsData({
    this.contact,
    this.expenses = const [],
    this.budgets = const [],
    this.isLoading = true,
    this.error,
    this.dateRangeFilter = DateRangeFilter.last30Days,
    this.customStartDate,
    this.customEndDate,
  });

  AnalyticsData copyWith({
    UserContact? contact,
    List<ExpenseEntry>? expenses,
    List<DailyBudgetEntry>? budgets,
    bool? isLoading,
    String? error,
    DateRangeFilter? dateRangeFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearError = false,
    bool updateDateRange = false,
  }) {
    return AnalyticsData(
      contact: contact ?? this.contact,
      expenses: expenses ?? this.expenses,
      budgets: budgets ?? this.budgets,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      dateRangeFilter: updateDateRange && dateRangeFilter != null ? dateRangeFilter : this.dateRangeFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
    );
  }
}

/// Analytics data provider
class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  AnalyticsNotifier() : super(AnalyticsData());

  Future<void> loadData(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (userId.isEmpty) {
        state = state.copyWith(
          error: 'Please log in to view analytics',
          isLoading: false,
        );
        return;
      }

      // Fetch user contact
      final contactResponse = await supabase
          .from('user_contacts')
          .select('id,user_id,phone_e164,verified,preferred_currency')
          .eq('user_id', userId)
          .eq('verified', true)
          .maybeSingle();

      if (contactResponse == null) {
        state = state.copyWith(
          contact: null,
          isLoading: false,
        );
        return;
      }

      final fetchedContact = UserContact.fromJson(contactResponse);
      
      // Calculate date range based on filter
      final dateRange = _getDateRange(state.dateRangeFilter, state.customStartDate, state.customEndDate);
      final from = dateRange['from']!;
      final to = dateRange['to']!;
      
      final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final toStr = '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';

      // Fetch expenses
      final expensesResponse = await supabase
          .from('expenses')
          .select('id,contact_id,date,amount_cents,currency,category,created_at,raw_text,receipt_image_url')
          .eq('contact_id', fetchedContact.id)
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true);

      // Fetch budgets
      final budgetsResponse = await supabase
          .from('daily_budgets')
          .select('id,contact_id,date,amount_cents,currency')
          .eq('contact_id', fetchedContact.id)
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true);

      state = state.copyWith(
        contact: fetchedContact,
        expenses: (expensesResponse as List)
            .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        budgets: (budgetsResponse as List)
            .map((b) => DailyBudgetEntry.fromJson(b as Map<String, dynamic>))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load data: $e',
        isLoading: false,
      );
    }
  }

  void refresh(String userId) {
    loadData(userId);
  }

  void setDateRangeFilter(DateRangeFilter filter, String userId, {DateTime? startDate, DateTime? endDate}) {
    state = state.copyWith(
      dateRangeFilter: filter,
      customStartDate: startDate,
      customEndDate: endDate,
      updateDateRange: true,
    );
    loadData(userId);
  }

  Map<String, DateTime> _getDateRange(DateRangeFilter filter, DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (filter) {
      case DateRangeFilter.today:
        return {'from': today, 'to': today};
      
      case DateRangeFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return {'from': yesterday, 'to': yesterday};
      
      case DateRangeFilter.thisWeek:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return {'from': weekStart, 'to': today};
      
      case DateRangeFilter.lastWeek:
        final lastWeekEnd = today.subtract(Duration(days: today.weekday));
        final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
        return {'from': lastWeekStart, 'to': lastWeekEnd};
      
      case DateRangeFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return {'from': monthStart, 'to': today};
      
      case DateRangeFilter.last30Days:
        final from = today.subtract(const Duration(days: 29));
        return {'from': from, 'to': today};
      
      case DateRangeFilter.custom:
        if (customStart != null && customEnd != null) {
          return {'from': customStart, 'to': customEnd};
        }
        // Fallback to last 30 days if custom dates not set
        final from = today.subtract(const Duration(days: 29));
        return {'from': from, 'to': today};
    }
  }
}

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, AnalyticsData>((ref) {
  return AnalyticsNotifier();
});

// ============================================================================
// EXPENSE PROCESSING SERVICE
// ============================================================================

/// Loading state for expense processing
class ProcessingState {
  final bool isProcessing;
  final String? message;
  final double? progress;
  final ExpenseEntry? createdExpense;
  final String? localImagePath; // For showing local photo instead of waiting for upload

  ProcessingState({
    this.isProcessing = false,
    this.message,
    this.progress,
    this.createdExpense,
    this.localImagePath,
  });

  ProcessingState copyWith({
    bool? isProcessing,
    String? message,
    double? progress,
    ExpenseEntry? createdExpense,
    String? localImagePath,
    bool clearMessage = false,
    bool clearExpense = false,
  }) {
    return ProcessingState(
      isProcessing: isProcessing ?? this.isProcessing,
      message: clearMessage ? null : (message ?? this.message),
      progress: progress ?? this.progress,
      createdExpense: clearExpense ? null : (createdExpense ?? this.createdExpense),
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}

/// Expense processing notifier
class ExpenseProcessingNotifier extends StateNotifier<ProcessingState> {
  ExpenseProcessingNotifier() : super(ProcessingState());

  Future<void> _simulateProgress() async {
    // Fast initial progress
    await Future.delayed(const Duration(milliseconds: 100));
    state = state.copyWith(progress: 0.3);

    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(progress: 0.5);

    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(progress: 0.65);

    // Slower as it approaches the end
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(progress: 0.75);

    await Future.delayed(const Duration(milliseconds: 800));
    state = state.copyWith(progress: 0.82);

    await Future.delayed(const Duration(milliseconds: 1000));
    state = state.copyWith(progress: 0.88);

    // Very slow near completion
    await Future.delayed(const Duration(milliseconds: 1500));
    state = state.copyWith(progress: 0.92);
  }

  Future<void> processText(String text, String phone) async {
    state = state.copyWith(isProcessing: true, message: 'Processing expense...', progress: 0.1, clearExpense: true);

    // Start fake progress simulation
    _simulateProgress();

    try {
      final response = await supabase.functions.invoke(
        'process-expenses',
        body: {
          'phone': phone,
          'text': text,
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );

      if (response.data != null && response.data['success'] == true) {
        final responseData = response.data['data'];
        ExpenseEntry? createdExpense;

        // The response structure is: {success: true, data: {type: 'expense', items: [...], expenses: [...]}}
        // We need the 'expenses' array which has the actual DB records
        if (responseData != null && responseData['expenses'] != null && responseData['expenses'].isNotEmpty) {
          try {
            final expenseData = responseData['expenses'][0]; // Get first expense from DB
            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? '',
              contactId: expenseData['contact_id'] ?? '',
              amountCents: expenseData['amount_cents'] ?? 0,
              category: expenseData['category'],
              date: DateTime.parse(expenseData['date'] ?? DateTime.now().toIso8601String()),
              createdAt: DateTime.parse(expenseData['created_at'] ?? DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
          } catch (parseError) {
            print('Error parsing expense data: $parseError');
          }
        } else if (responseData != null && responseData['items'] != null && responseData['items'].isNotEmpty) {
          // Fallback: If 'expenses' array is missing, create from 'items' (Gemini parsed data)
          try {
            final item = responseData['items'][0];
            final amountCents = ((item['amount'] ?? 0.0) * 100).round();
            createdExpense = ExpenseEntry(
              id: '', // No ID from items
              contactId: '',
              amountCents: amountCents,
              category: item['category'] ?? 'uncategorized',
              date: DateTime.parse(item['date'] ?? DateTime.now().toIso8601String().split('T')[0]),
              createdAt: DateTime.now(),
              rawText: text,
              currency: item['currency'] ?? 'USD',
              receiptImageUrl: null,
            );
          } catch (parseError) {
            print('Error parsing items data: $parseError');
          }
        }

        // Jump to 100% on success
        state = state.copyWith(progress: 1.0, createdExpense: createdExpense);
        // Very short delay to show completion, then hide to allow toast to show immediately
        await Future.delayed(const Duration(milliseconds: 50));
        state = state.copyWith(isProcessing: false, clearMessage: true);
      } else {
        final error = response.data?['error'] ?? 'Failed to process expense';
        throw Exception(error);
      }
    } catch (e) {
      state = state.copyWith(isProcessing: false, message: 'Error: ${e.toString()}', clearMessage: false);
      rethrow;
    }
  }

  Future<void> processImage(File imageFile, String phone) async {
    state = state.copyWith(isProcessing: true, message: 'Processing receipt image...', progress: 0.1, clearExpense: true, localImagePath: imageFile.path);

    // Start fake progress simulation
    _simulateProgress();

    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      final extension = imageFile.path.split('.').last.toLowerCase();
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'heic') {
        contentType = 'image/heic';
      }

      final response = await supabase.functions.invoke(
        'process-expenses',
        body: {
          'phone': phone,
          'image': {
            'data': base64Image,
            'contentType': contentType,
          },
          'date': DateTime.now().toIso8601String().split('T')[0],
        },
      );

      if (response.data != null && response.data['success'] == true) {
        // DEBUG: Log the full response structure
        print('=== FULL RESPONSE ===');
        print(response.data);

        // Parse expense data from response - it's nested in data.expenses array
        final responseData = response.data['data'];
        print('=== RESPONSE DATA ===');
        print(responseData);

        ExpenseEntry? createdExpense;

        if (responseData != null && responseData['expenses'] != null && responseData['expenses'].isNotEmpty) {
          try {
            print('=== EXPENSES ARRAY ===');
            print(responseData['expenses']);

            final expenseData = responseData['expenses'][0]; // Get first expense
            print('=== FIRST EXPENSE ===');
            print(expenseData);

            createdExpense = ExpenseEntry(
              id: expenseData['id'] ?? '',
              contactId: expenseData['contact_id'] ?? '',
              amountCents: expenseData['amount_cents'] ?? 0,
              category: expenseData['category'],
              date: DateTime.parse(expenseData['date'] ?? DateTime.now().toIso8601String()),
              createdAt: DateTime.parse(expenseData['created_at'] ?? DateTime.now().toIso8601String()),
              rawText: expenseData['raw_text'],
              currency: expenseData['currency'],
              receiptImageUrl: expenseData['receipt_image_url'],
            );
            print('=== CREATED EXPENSE ENTRY ===');
            print('Category: ${createdExpense.category}, Amount: ${createdExpense.amount}');
          } catch (parseError) {
            print('Error parsing expense data: $parseError');
          }
        } else {
          print('=== NO EXPENSES FOUND ===');
          print('responseData is null: ${responseData == null}');
          print('expenses is null: ${responseData?['expenses'] == null}');
          print('expenses isEmpty: ${responseData?['expenses']?.isEmpty}');
        }

        // Jump to 100% on success
        state = state.copyWith(progress: 1.0, createdExpense: createdExpense);
        // Very short delay to show completion, then hide to allow toast to show immediately
        await Future.delayed(const Duration(milliseconds: 50));
        state = state.copyWith(isProcessing: false, clearMessage: true);
      } else {
        final error = response.data?['error'] ?? 'Failed to process receipt';
        throw Exception(error);
      }
    } catch (e) {
      state = state.copyWith(isProcessing: false, message: 'Error: ${e.toString()}', clearMessage: false);
      rethrow;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }
}

final expenseProcessingProvider = StateNotifierProvider<ExpenseProcessingNotifier, ProcessingState>((ref) {
  return ExpenseProcessingNotifier();
});

// ============================================================================
// EXPANDABLE FAB COMPONENTS (Official Flutter Pattern)
// ============================================================================

@immutable
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    this.initialOpen,
    required this.distance,
    required this.children,
  });

  final bool? initialOpen;
  final double distance;
  final List<Widget> children;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen ?? false;
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          _buildTapToCloseFab(),
          ..._buildExpandingActionButtons(),
          _buildTapToOpenFab(),
        ],
      ),
    );
  }

  Widget _buildTapToCloseFab() {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          color: colorScheme.primary,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close,
                color: colorScheme.primaryForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTapToOpenFab() {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: _open,
      child: AnimatedContainer(
        transformAlignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          _open ? 0.7 : 1.0,
          _open ? 0.7 : 1.0,
          1.0,
        ),
        duration: const Duration(milliseconds: 250),
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        child: AnimatedOpacity(
          opacity: _open ? 0.0 : 1.0,
          curve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
          duration: const Duration(milliseconds: 250),
          child: FloatingActionButton(
            backgroundColor: colorScheme.primary,
            onPressed: _toggle,
            child: Icon(Icons.add, color: colorScheme.primaryForeground),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    final step = 90.0 / (count - 1);
    for (var i = 0, angleInDegrees = 0.0;
        i < count;
        i++, angleInDegrees += step) {
      children.add(
        _ExpandingActionButton(
          directionInDegrees: angleInDegrees,
          maxDistance: widget.distance,
          progress: _expandAnimation,
          child: widget.children[i],
        ),
      );
    }
    return children;
  }
}

@immutable
class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (pi / 180.0),
          progress.value * maxDistance,
        );
        return Positioned(
          right: 4.0 + offset.dx,
          bottom: 4.0 + offset.dy,
          child: Transform.rotate(
            angle: (1.0 - progress.value) * pi / 2,
            child: child!,
          ),
        );
      },
      child: FadeTransition(
        opacity: progress,
        child: child,
      ),
    );
  }
}

@immutable
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label!,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          color: colorScheme.primary,
          elevation: 4,
          child: IconButton(
            onPressed: onPressed,
            icon: icon,
            color: colorScheme.primaryForeground,
          ),
        ),
      ],
    );
  }
}

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

    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        _showToast('Camera permission is required');
      }
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        final user = ref.read(authProvider);
        final contact = ref.read(analyticsProvider).contact;

        if (contact == null) {
          _showToast('No contact found. Please link your WhatsApp first.');
          return;
        }

        try {
          print('=== STARTING IMAGE PROCESSING ===');
          await ref.read(expenseProcessingProvider.notifier).processImage(
            File(photo.path),
            contact.phoneE164,
          );
          print('=== IMAGE PROCESSING COMPLETED ===');

          // Show success toast with View link
          final processingState = ref.read(expenseProcessingProvider);
          print('=== PROCESSING STATE: createdExpense is ${processingState.createdExpense != null ? "NOT NULL" : "NULL"} ===');

          if (processingState.createdExpense != null) {
            print('=== SHOWING SUCCESS TOAST ===');
            _showSuccessToast(processingState.createdExpense!, contact, localImagePath: processingState.localImagePath);
          }

          // Refresh analytics data immediately
          final userId = user?.uid;
          if (userId != null && userId.isNotEmpty) {
            print('=== REFRESHING ANALYTICS DATA FOR USER: $userId ===');
            await ref.read(analyticsProvider.notifier).loadData(userId);
            print('=== ANALYTICS DATA REFRESH COMPLETED ===');
          } else {
            print('=== ERROR: User ID is null or empty, cannot refresh analytics ===');
          }
        } catch (e) {
          print('=== ERROR IN IMAGE PROCESSING: $e ===');
          // Error is already handled in the notifier
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to capture photo: ${e.toString()}');
      }
    }
  }

  void _showTextInputDrawer() {

    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Expense',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.foreground),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Describe your expense (eg: "Spent 25 on lunch")',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter expense details...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
                style: TextStyle(color: colorScheme.foreground),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: shadcnui.PrimaryButton(
                  onPressed: () async {
                    final text = _textController.text.trim();
                    if (text.isEmpty) {
                      _showToast('Please enter expense details');
                      return;
                    }

                    Navigator.pop(context);

                    final user = ref.read(authProvider);
                    final contact = ref.read(analyticsProvider).contact;

                    if (contact == null) {
                      _showToast('No contact found. Please link your WhatsApp first.');
                      return;
                    }

                    try {
                      print('=== STARTING TEXT PROCESSING ===');
                      await ref.read(expenseProcessingProvider.notifier).processText(
                        text,
                        contact.phoneE164,
                      );
                      print('=== TEXT PROCESSING COMPLETED ===');

                      _textController.clear();

                      // Show success toast with View link
                      final processingState = ref.read(expenseProcessingProvider);
                      print('=== PROCESSING STATE: createdExpense is ${processingState.createdExpense != null ? "NOT NULL" : "NULL"} ===');

                      if (processingState.createdExpense != null) {
                        print('=== SHOWING SUCCESS TOAST ===');
                        _showSuccessToast(processingState.createdExpense!, contact);
                      }

                      // Close drawer
                      if (mounted) Navigator.pop(context);

                      // Refresh analytics data immediately
                      final userId = user?.uid;
                      if (userId != null && userId.isNotEmpty) {
                        print('=== REFRESHING ANALYTICS DATA FOR USER: $userId ===');
                        await ref.read(analyticsProvider.notifier).loadData(userId);
                        print('=== ANALYTICS DATA REFRESH COMPLETED ===');
                      } else {
                        print('=== ERROR: User ID is null or empty, cannot refresh analytics ===');
                      }
                    } catch (e) {
                      print('=== ERROR IN TEXT PROCESSING: $e ===');
                      // Error is already handled in the notifier
                    }
                  },
                  child: const Text('Add Expense'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
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

  void _showJointAccountModal(BuildContext context, shadcnui.ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with emoji
              Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Joint Accounts Coming Soon!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content
              Text(
                'In the next phase, you\'ll be able to invite your family, partner, or friends to create a shared budget and manage money together — all in one place.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Stay tuned, it\'s going to make teamwork with finances effortless!',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),

              const SizedBox(height: 24),

              // Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: shadcnui.PrimaryButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  double _getTotalSpent(List<ExpenseEntry> expenses) {
    return expenses.where((e) => e.amountCents > 0).fold(0.0, (sum, e) => sum + e.amount);
  }

  double _getTotalBudget(List<DailyBudgetEntry> budgets) {
    return budgets.fold(0.0, (sum, b) => sum + b.amount);
  }

  String _getCurrencySymbol(UserContact? contact) {
    final cur = contact?.preferredCurrency ?? 'USD';
    switch (cur.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'USD':
      default:
        return '\$';
    }
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

    final processingState = ref.watch(expenseProcessingProvider);

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
                            child: Text(
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
                            onTap: () => _showJointAccountModal(context, colorScheme),
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
                      onTap: () => _showDateRangeFilter(context, colorScheme, user.uid),
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
                child: _buildSpendingCard(colorScheme, analyticsData.expenses, analyticsData.contact, analyticsData.dateRangeFilter),
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
                      child: _buildBudgetCard(colorScheme, analyticsData.budgets, analyticsData.expenses, analyticsData.contact),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: _buildNetCashflowCard(colorScheme, analyticsData.budgets, analyticsData.expenses, analyticsData.contact),
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
                  child: _buildCategoryBreakdownCard(colorScheme, analyticsData.expenses, analyticsData.contact),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Spending Breakdown Pie Chart
            if (_getCategorySummaries(analyticsData.expenses).isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildSpendingBreakdownChart(colorScheme, analyticsData.expenses, analyticsData.contact),
                ),
              ),

            // See All Button
            if (_getCategorySummaries(analyticsData.expenses).isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TransactionsPage(),
                          ),
                        );
                      },
                      child: Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
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

  Widget _buildExpandableFAB(shadcnui.ColorScheme colorScheme) {
    return ExpandableFab(
      distance: 90,
      children: [
        ActionButton(
          onPressed: () {
            _showTextInputDrawer();
          },
          icon: const Icon(Icons.text_fields),
          label: 'Free form text',
        ),
        ActionButton(
          onPressed: () {
            _handleCameraCapture();
          },
          icon: const Icon(Icons.camera_alt),
          label: 'Take photo',
        ),
      ],
    );
  }

  Widget _buildSpendingCard(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact, DateRangeFilter dateFilter) {
    // Calculate cumulative spending by day
    final Map<DateTime, double> dailyTotals = {};
    final totalSpent = _getTotalSpent(expenses);
    final currencySymbol = _getCurrencySymbol(contact);
    
    for (final expense in expenses) {
      final dateOnly = DateTime(expense.date.year, expense.date.month, expense.date.day);
      dailyTotals[dateOnly] = (dailyTotals[dateOnly] ?? 0) + expense.amount;
    }
    
    final sortedDates = dailyTotals.keys.toList()..sort();
    
    if (sortedDates.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.border, width: 1),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Text('No spending data', style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }
    
    // Calculate cumulative spending
    double cumulative = 0;
    final cumulativeData = sortedDates.map((date) {
      cumulative += dailyTotals[date] ?? 0;
      return FlSpot(
        sortedDates.indexOf(date).toDouble(),
        cumulative,
      );
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateFilter.spentLabel,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currencySymbol${totalSpent.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: cumulative > 0 ? cumulative / 4 : 100,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: colorScheme.border.withValues(alpha: 0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: sortedDates.length > 10 ? 5 : 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= sortedDates.length) return const SizedBox();
                          final date = sortedDates[value.toInt()];
                          return Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: cumulativeData,
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.3),
                            const Color(0xFF10B981).withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: cumulative > 0 ? (cumulative * 1.2).ceilToDouble() : 100,
                ),
              ),
            ),
          ],
        ),  
    );
  }

  Widget _buildBudgetCard(shadcnui.ColorScheme colorScheme, List<DailyBudgetEntry> budgets, List<ExpenseEntry> expenses, UserContact? contact) {
    final totalBudget = _getTotalBudget(budgets);
    final currencySymbol = _getCurrencySymbol(contact);
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$currencySymbol${totalBudget.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const Spacer(),
            Text(
              '${expenses.length} transactions',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildNetCashflowCard(shadcnui.ColorScheme colorScheme, List<DailyBudgetEntry> budgets, List<ExpenseEntry> expenses, UserContact? contact) {
    final totalBudget = _getTotalBudget(budgets);
    final totalSpent = _getTotalSpent(expenses);
    final currencySymbol = _getCurrencySymbol(contact);
    final netCashflow = totalBudget - totalSpent;
    final isNegative = netCashflow < 0;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net cashflow',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${isNegative ? '-' : ''}$currencySymbol${netCashflow.abs().toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  size: 8,
                ),
                const SizedBox(width: 4),
                Text(
                  isNegative ? 'Negative' : 'Positive',
                  style: TextStyle(
                    fontSize: 12,
                    color: isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildCategoryBreakdownCard(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact) {
    final categorySummaries = _getCategorySummaries(expenses);
    final totalSpent = _getTotalSpent(expenses);
    final currencySymbol = _getCurrencySymbol(contact);
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ...categorySummaries.take(5).map((category) {
            final percentage = category.getPercentage(totalSpent);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getCategoryIcon(category.category),
                      color: category.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.category.substring(0, 1).toUpperCase() + 
                              category.category.substring(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          '${category.transactionCount} transaction${category.transactionCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '-$currencySymbol${category.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSpendingBreakdownChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact) {
    final categorySummaries = _getCategorySummaries(expenses);
    final totalSpent = _getTotalSpent(expenses);
    final currencySymbol = _getCurrencySymbol(contact);
    
    // Calculate budget remaining (using a simple calculation based on total budget)
    final totalBudget = totalSpent * 1.5; // Assume budget is 1.5x of spent for demo
    final remaining = totalBudget - totalSpent;

    if (categorySummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            'Spending Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This Year',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: categorySummaries.map((category) {
                      return PieChartSectionData(
                        color: category.color,
                        value: category.amount,
                        title: '',
                        radius: 50,
                      );
                    }).toList(),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$currencySymbol${totalSpent.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.foreground,
                        ),
                      ),
                      Text(
                        'Spent',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: categorySummaries.take(4).map((category) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.category.substring(0, 1).toUpperCase() + category.category.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.foreground,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$currencySymbol${remaining.toStringAsFixed(0)} left',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDateRangeFilter(BuildContext context, shadcnui.ColorScheme colorScheme, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.foreground),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...DateRangeFilter.values.where((f) => f != DateRangeFilter.custom).map((filter) {
                return ListTile(
                  title: Text(
                    filter.label,
                    style: TextStyle(color: colorScheme.foreground),
                  ),
                  onTap: () {
                    ref.read(analyticsProvider.notifier).setDateRangeFilter(filter, userId);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
