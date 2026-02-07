import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';
import 'package:moneko/features/home/presentation/utils/transaction_exporter.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/utils/datetime.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class HouseholdMemberDetailsPage extends HookConsumerWidget {
  final HouseholdMember member;
  final List<ExpenseEntry> transactions;
  final List<ExpenseSplitGroup>? splits;
  final String currency;
  final String? householdId;

  const HouseholdMemberDetailsPage({
    super.key,
    required this.member,
    required this.transactions,
    this.splits,
    required this.currency,
    this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final colorScheme = Theme.of(context).colorScheme;

    final range = getDateRangeFromFilter(
      DateRangeFilter.thisMonth,
      null,
      null,
    );
    final rangeFrom = range['from']!;
    final rangeTo = range['to']!;

    // Filter transactions for this member within the selected date range
    final memberTransactions = _getMemberTransactions(rangeFrom, rangeTo);
    final groupedTransactions = _groupTransactionsByDate(memberTransactions);
    final totalSpentCentsForRange = memberTransactions.fold<int>(
      0,
      (sum, entry) => sum + entry.amountCents.abs(),
    );
    final transactionCount = memberTransactions.length;
    final daysInRange = rangeTo.difference(rangeFrom).inDays + 1;
    final avgDailySpendCents =
        daysInRange > 0 ? (totalSpentCentsForRange / daysInRange).round() : 0;
    final categoryTransactions = _groupTransactionsByCategory(
      memberTransactions,
    );
    final categorySummaries = _buildCategorySummaries(categoryTransactions);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, colorScheme, memberTransactions),
          SliverToBoxAdapter(
            child: _buildHeader(
              context,
              colorScheme,
              totalSpentCentsForRange,
            ),
          ),
          SliverToBoxAdapter(
            child: _buildInsightsSection(
              context,
              colorScheme,
              transactionCount: transactionCount,
              avgDailySpendCents: avgDailySpendCents,
              totalSpentCents: totalSpentCentsForRange,
              categorySummaries: categorySummaries,
              categoryTransactions: categoryTransactions,
            ),
          ),
          if (memberTransactions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, colorScheme),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  context.l10n.recentTransactions,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = groupedTransactions.keys.elementAt(index);
                    final expenses = groupedTransactions[date]!;
                    return _buildDaySection(
                        context, colorScheme, date, expenses);
                  },
                  childCount: groupedTransactions.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    List<ExpenseEntry> exportTransactions,
  ) {
    return SliverAppBar(
      backgroundColor: colorScheme.appBackground,
      surfaceTintColor: colorScheme.surface.withValues(alpha: 0.0),
      floating: true,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: colorScheme.foreground),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon:
              Icon(Icons.file_download_rounded, color: colorScheme.foreground),
          onPressed: () => exportTransactionsAsExcelSheet(
            context,
            exportTransactions,
            fileNamePrefix: 'member_transactions',
          ),
        ),
      ],
      title: Text(
        member.userName ?? member.userEmail ?? context.l10n.unknownMember,
        style: TextStyle(
          color: colorScheme.foreground,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    int rangeTotalSpentCents,
  ) {
    final formattedTotal = formatLocalizedNumber(
      context,
      rangeTotalSpentCents / 100.0,
    );
    final symbol = resolveCurrencySymbol(currency);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.muted.withValues(alpha: 0.5),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: FutureBuilder<String?>(
                future: _getUserAvatarUrl(member.userId),
                builder: (context, snapshot) {
                  final avatarUrl = snapshot.data;
                  if (avatarUrl != null) {
                    return Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded,
                        size: 40,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.6),
                      ),
                    );
                  }
                  return Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Spending Amount
          Text(
            '$symbol$formattedTotal',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.spentThisMonth,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (householdId != null &&
              member.userId !=
                  Supabase.instance.client.auth.currentUser?.id) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReminderModal(
                  context,
                  colorScheme,
                  member.userId,
                  member.userName ?? member.userEmail ?? 'Member',
                  householdId!,
                ),
                icon: Icon(Icons.touch_app_outlined,
                    size: 20, color: colorScheme.primaryForeground),
                label: Text(
                  context.l10n.nudge,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primaryForeground,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.primaryForeground,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsSection(
    BuildContext context,
    ColorScheme colorScheme, {
    required int transactionCount,
    required int avgDailySpendCents,
    required int totalSpentCents,
    required List<_CategorySummary> categorySummaries,
    required Map<String, List<ExpenseEntry>> categoryTransactions,
  }) {
    if (transactionCount == 0) {
      return const SizedBox.shrink();
    }

    final topCategory =
        categorySummaries.isNotEmpty ? categorySummaries.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _buildMetricTile(
                      context,
                      colorScheme,
                      label: context.l10n.transactions,
                      value: transactionCount.toString(),
                      subtitle: context.l10n.thisMonth,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _buildMetricTile(
                      context,
                      colorScheme,
                      label: context.l10n.avgDailySpendLabel,
                      value: _formatCurrency(context, avgDailySpendCents),
                      subtitle: context.l10n.thisMonth,
                    ),
                  ),
                ],
              );
            },
          ),
          if (topCategory != null) ...[
            const SizedBox(height: 16),
            _buildTopCategoryCard(
              context,
              colorScheme,
              topCategory,
              totalSpentCents,
              categoryTransactions,
            ),
          ],
          if (categorySummaries.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              context.l10n.category,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.categoryTotalsForSelectedRange,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            _buildCategoryBreakdown(
              context,
              colorScheme,
              categorySummaries,
              totalSpentCents,
              categoryTransactions,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    ColorScheme colorScheme, {
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.mutedForeground.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopCategoryCard(
    BuildContext context,
    ColorScheme colorScheme,
    _CategorySummary summary,
    int totalSpentCents,
    Map<String, List<ExpenseEntry>> categoryTransactions,
  ) {
    final categoryLabel = getCategoryTranslation(context, summary.category);
    final categoryColor = getCategoryColor(summary.category);
    final percent =
        totalSpentCents > 0 ? summary.amountCents / totalSpentCents : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openCategoryDetails(
        context,
        summary.category,
        categoryTransactions[summary.category] ?? const [],
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.homeCardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                getCategoryIcon(summary.category),
                color: categoryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.topCategory,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(context, summary.amountCents),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(percent * 100).round()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(
    BuildContext context,
    ColorScheme colorScheme,
    List<_CategorySummary> summaries,
    int totalSpentCents,
    Map<String, List<ExpenseEntry>> categoryTransactions,
  ) {
    final items = summaries.take(5).toList();
    return Column(
      children: items.map((summary) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCategoryRow(
            context,
            colorScheme,
            summary,
            totalSpentCents,
            categoryTransactions,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    ColorScheme colorScheme,
    _CategorySummary summary,
    int totalSpentCents,
    Map<String, List<ExpenseEntry>> categoryTransactions,
  ) {
    final categoryLabel = getCategoryTranslation(context, summary.category);
    final categoryColor = getCategoryColor(summary.category);
    final percent =
        totalSpentCents > 0 ? summary.amountCents / totalSpentCents : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openCategoryDetails(
        context,
        summary.category,
        categoryTransactions[summary.category] ?? const [],
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.homeCardBorder,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getCategoryIcon(summary.category),
                    color: categoryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.transactionCount} ${context.l10n.transactions}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatCurrency(context, summary.amountCents),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: percent.clamp(0.0, 1.0),
                backgroundColor: colorScheme.muted,
                valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection(BuildContext context, ColorScheme colorScheme,
      DateTime date, List<ExpenseEntry> expenses) {
    final isToday = DateTime.now().difference(date).inDays == 0 &&
        DateTime.now().day == date.day;
    final dateStr =
        isToday ? context.l10n.today : DateFormat.MMMEd().format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 12),
          child: Text(
            dateStr.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground.withValues(alpha: 0.8),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.homeCardSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.homeCardBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.homeCardShadow,
                blurRadius: 32,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: expenses.mapIndexed((index, expense) {
                final isLast = index == expenses.length - 1;
                final isIncome =
                    (expense.type ?? 'expense').toLowerCase() == 'income';
                final localDisplayDateTime = combineLocalDateWithLocalTime(
                  date: expense.date,
                  timeSource: expense.createdAt,
                );
                return Column(
                  children: [
                    buildExpenseTransactionTile(
                      context: context,
                      category: expense.category,
                      rawText: expense.rawText,
                      date: localDisplayDateTime,
                      amount: expense.amount,
                      currency: expense.currency ?? currency,
                      isIncome: isIncome,
                      onTap: () => showUnifiedTransactionSheet(
                        context,
                        existingExpense: expense,
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 56,
                        color: colorScheme.border.withValues(alpha: 0.1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: colorScheme.mutedForeground.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noTransactionsFound,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.noTransactionsForPeriod,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods

  String _formatCurrency(BuildContext context, int amountCents) {
    final symbol = resolveCurrencySymbol(currency);
    final formatted = formatLocalizedNumber(context, amountCents.abs() / 100.0);
    return '$symbol$formatted';
  }

  Map<String, List<ExpenseEntry>> _groupTransactionsByCategory(
    List<ExpenseEntry> transactions,
  ) {
    final grouped = <String, List<ExpenseEntry>>{};
    for (final transaction in transactions) {
      final key = normalizeCategory(transaction.category ?? 'uncategorized');
      grouped.putIfAbsent(key, () => []).add(transaction);
    }
    return grouped;
  }

  List<_CategorySummary> _buildCategorySummaries(
    Map<String, List<ExpenseEntry>> grouped,
  ) {
    final summaries = grouped.entries.map((entry) {
      final total = entry.value.fold<int>(
        0,
        (sum, item) => sum + item.amountCents.abs(),
      );
      return _CategorySummary(
        category: entry.key,
        amountCents: total,
        transactionCount: entry.value.length,
      );
    }).toList();

    summaries.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return summaries;
  }

  void _openCategoryDetails(
    BuildContext context,
    String category,
    List<ExpenseEntry> transactions,
  ) {
    if (transactions.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HouseholdMemberCategoryDetailsPage(
          member: member,
          currency: currency,
          category: category,
          transactions: transactions,
        ),
      ),
    );
  }

  List<ExpenseEntry> _getMemberTransactions(
      DateTime rangeFrom, DateTime rangeTo) {
    // Use similar logic to the spending card to attribute expenses
    final memberTransactions = <ExpenseEntry>[];

    // Convert date range to include full days
    final startDate = DateTime(rangeFrom.year, rangeFrom.month, rangeFrom.day);
    final endDate = DateTime(rangeTo.year, rangeTo.month, rangeTo.day)
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    // Lookup map for split groups
    final byGroupId = splits != null
        ? {for (final g in splits!) g.id: g}
        : <String, ExpenseSplitGroup>{};

    for (final t in transactions) {
      if (t.date.isBefore(startDate) || t.date.isAfter(endDate)) continue;

      final isSpend = (t.type ?? 'expense').toLowerCase() != 'income';
      if (!isSpend) continue;

      final tCurrency = (t.currency ?? '').trim().toUpperCase();
      if (tCurrency.isNotEmpty && tCurrency != currency) continue;

      final splitGroupId = t.splitGroupId;

      // CASE 1: No split - attribute full amount to creator
      if (splitGroupId == null) {
        if (t.userId == member.userId) {
          memberTransactions.add(t);
        }
        continue;
      }

      // CASE 2: Has split - check if member has a share > 0
      final group = byGroupId[splitGroupId];
      if (group == null || group.splitLines == null) {
        if (t.userId == member.userId) {
          memberTransactions.add(t);
        }
        continue;
      }

      // Check if member is part of this split and has amount > 0
      final memberLine =
          group.splitLines!.firstWhereOrNull((l) => l.userId == member.userId);
      if (memberLine != null && (memberLine.amountCents ?? 0).abs() > 0) {
        // We add the original transaction but maybe we should show the split amount?
        // For the list view, showing the original transaction is cleaner,
        // but showing the split amount would be more accurate.
        // Let's create a copy with the adjusted amount for display purposes.
        memberTransactions.add(t.copyWith(
          amountCents: (memberLine.amountCents ?? 0).abs(),
        ));
      }
    }

    // Sort by date descending
    memberTransactions.sort((a, b) => b.date.compareTo(a.date));
    return memberTransactions;
  }

  Map<DateTime, List<ExpenseEntry>> _groupTransactionsByDate(
      List<ExpenseEntry> transactions) {
    final grouped = <DateTime, List<ExpenseEntry>>{};
    for (final t in transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(t);
    }
    return grouped;
  }

  Future<String?> _getUserAvatarUrl(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();

      return response?['avatar_url'] as String?;
    } catch (e) {
      debugPrint('Error fetching user avatar: $e');
      return null;
    }
  }

  // Nudge Functionality
  // Future<bool> _canSendReminder(String householdId, String targetUserId) async {
  //   try {
  //     final supabase = Supabase.instance.client;
  //     final currentUserId = supabase.auth.currentUser?.id;

  //     if (currentUserId == null) return false;

  //     // Check for existing reminder in last 24 hours
  //     final twentyFourHoursAgo =
  //         DateTime.now().subtract(const Duration(hours: 24));

  //     final response = await supabase
  //         .from('notification_events')
  //         .select('created_at')
  //         .eq('household_id', householdId)
  //         .eq('user_id', targetUserId)
  //         .eq('event_type', 'member_reminded')
  //         .gte('created_at', twentyFourHoursAgo.toIso8601String())
  //         .order('created_at', ascending: false)
  //         .limit(1)
  //         .maybeSingle();

  //     return response == null; // Can send if no recent reminder found
  //   } catch (e) {
  //     debugPrint('Error in _canSendReminder: $e');
  //     return true; // Allow on error
  //   }
  // }

  void _showReminderModal(
    BuildContext context,
    ColorScheme colorScheme,
    String targetUserId,
    String targetUserName,
    String householdId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      builder: (modalContext) {
        return _ReminderModalContent(
          colorScheme: colorScheme,
          targetUserId: targetUserId,
          targetUserName: targetUserName,
          householdId: householdId,
          parentContext: context,
        );
      },
    );
  }
}

class _CategorySummary {
  final String category;
  final int amountCents;
  final int transactionCount;

  const _CategorySummary({
    required this.category,
    required this.amountCents,
    required this.transactionCount,
  });
}

class HouseholdMemberCategoryDetailsPage extends StatelessWidget {
  final HouseholdMember member;
  final String currency;
  final String category;
  final List<ExpenseEntry> transactions;

  const HouseholdMemberCategoryDetailsPage({
    super.key,
    required this.member,
    required this.currency,
    required this.category,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryLabel = getCategoryTranslation(context, category);
    final sortedTransactions = List<ExpenseEntry>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final totalSpentCents = sortedTransactions.fold<int>(
      0,
      (sum, item) => sum + item.amountCents.abs(),
    );
    final symbol = resolveCurrencySymbol(currency);
    final formattedTotal =
        formatLocalizedNumber(context, totalSpentCents / 100.0);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        backgroundColor: colorScheme.appBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          categoryLabel,
          style: TextStyle(
            color: colorScheme.foreground,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: colorScheme.foreground),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.homeCardBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.homeCardShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: getCategoryColor(category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    getCategoryIcon(category),
                    color: getCategoryColor(category),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.totalSpent,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$symbol$formattedTotal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sortedTransactions.length} ${context.l10n.transactions}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.recentTransactions,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
          if (sortedTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.l10n.noTransactionsYet,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                ),
              ),
            )
          else
            ...sortedTransactions.map((expense) {
              return TransactionListTile(
                category: expense.category ?? category,
                title: categoryLabel,
                description: expense.rawText,
                date: expense.date,
                amount: expense.amountCents / 100.0,
                currency: expense.currency ?? currency,
                isIncome: false,
                onTap: () => showUnifiedTransactionSheet(
                  context,
                  existingExpense: expense,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ReminderModalContent extends StatefulWidget {
  final ColorScheme colorScheme;
  final String targetUserId;
  final String targetUserName;
  final String householdId;
  final BuildContext parentContext;

  const _ReminderModalContent({
    required this.colorScheme,
    required this.targetUserId,
    required this.targetUserName,
    required this.householdId,
    required this.parentContext,
  });

  @override
  State<_ReminderModalContent> createState() => _ReminderModalContentState();
}

class _ReminderModalContentState extends State<_ReminderModalContent> {
  final TextEditingController messageController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _sendReminder() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final supabase = Supabase.instance.client;

    try {
      // Check cooldown (re-implemented check here to be safe)
      // Note: In a real app this should be in a service/repository
      final twentyFourHoursAgo =
          DateTime.now().subtract(const Duration(hours: 24));
      final checkResponse = await supabase
          .from('notification_events')
          .select('created_at')
          .eq('household_id', widget.householdId)
          .eq('user_id', widget.targetUserId)
          .eq('event_type', 'member_reminded')
          .gte('created_at', twentyFourHoursAgo.toIso8601String())
          .limit(1)
          .maybeSingle();

      if (checkResponse != null) {
        if (mounted) Navigator.of(context).pop();
        if (widget.parentContext.mounted) {
          AppToast.warning(
              widget.parentContext,
              widget.parentContext.l10n
                  .pleaseWait24HoursBeforeSendingAnotherReminder(
                      widget.targetUserName));
        }
        return;
      }

      // Send reminder
      final response = await supabase.functions.invoke(
        'households-remind-member',
        body: {
          'household_id': widget.householdId,
          'target_user_id': widget.targetUserId,
          'message': messageController.text.trim(),
        },
      );

      if (mounted) Navigator.of(context).pop();

      if (response.status == 200) {
        if (widget.parentContext.mounted) {
          AppToast.success(
              widget.parentContext,
              widget.parentContext.l10n
                  .reminderSentToName(widget.targetUserName));
        }
      } else {
        throw Exception('Failed to send reminder');
      }
    } catch (e) {
      debugPrint('Error sending reminder: $e');
      if (mounted) Navigator.of(context).pop();
      if (widget.parentContext.mounted) {
        AppToast.error(widget.parentContext,
            widget.parentContext.l10n.failedToSendReminderTryAgain);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: widget.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parentContext.l10n
                              .remindUser(widget.targetUserName),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget
                              .parentContext.l10n.sendFriendlySpendingReminder,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Text(widget.parentContext.l10n.addMessageOptional,
                  style: TextStyle(
                      fontSize: 14, color: widget.colorScheme.mutedForeground)),
              const SizedBox(height: 6),

              // Message input
              TextField(
                controller: messageController,
                enabled: !isLoading,
                maxLines: 3,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: widget.parentContext.l10n.messageHintExample,
                  hintStyle: TextStyle(
                    color: widget.colorScheme.mutedForeground
                        .withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: widget.colorScheme.muted.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.colorScheme.foreground,
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: widget.colorScheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.parentContext.l10n.cancel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.colorScheme.foreground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _sendReminder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: widget.colorScheme.primary,
                        disabledBackgroundColor: widget.colorScheme.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.parentContext.l10n.sendReminder,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: widget.colorScheme.primaryForeground,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
