
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';

import 'package:intl/intl.dart';
import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';

class PocketDetailsPage extends HookConsumerWidget {
  const PocketDetailsPage({
    super.key,
    required this.pocketId,
    required this.scopeParams,
  });

  final String pocketId;
  final PocketsScopeParams scopeParams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final colorScheme = Theme.of(context).colorScheme;

    // If state is loading (e.g., after invalidation), show loading indicator
    if (state.isLoading && state.editing.isEmpty && state.saved.isEmpty) {
      return AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: context.l10n.loading),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      );
    }

    // Try to find the pocket in editing or saved lists
    final pocket = _findPocket(state, pocketId);

    // If pocket not found, show error screen
    if (pocket == null) {
      return AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: context.l10n.pocketNotFound),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.pocketNotFound,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.pocketNotFoundDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.goBack),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalBudget = state.totalBudget;
    final limit = pocket.getLimit(totalBudget);
    final progress = pocket.getProgress(totalBudget);

    // Calculate unallocated budget for the edit sheet
    final totalPercentage =
        state.editing.fold<double>(0, (sum, p) => sum + p.percentage);
    final unallocatedBudget = totalBudget * ((100 - totalPercentage) / 100);

    final pocketColor = pocket.color != null
        ? Color(int.parse(pocket.color!.replaceAll('#', '0xff')))
        : colorScheme.primary;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = _generateGradientColors(pocketColor, isDarkMode);

    // Determine text color based on background luminance
    final isBackgroundLight = gradientColors.first.computeLuminance() > 0.5;
    final textColor = isBackgroundLight ? Colors.black87 : Colors.white;
    final secondaryTextColor =
        isBackgroundLight ? Colors.black54 : Colors.white70;

    return Scaffold(
      backgroundColor: gradientColors.first,
      body: Stack(
        children: [
          // 1. Full-bleed Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
              ),
            ),
          ),
          // 2. Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.edit, color: textColor),
                    onPressed: () {
                      final rootNavigator = Navigator.of(context);
                      // Combine both saved and editing pockets for complete rebalancing
                      final seenIds = <String>{};
                      final allPockets = <PocketEnvelope>[
                        ...state.editing.where((p) {
                          if (seenIds.contains(p.id)) return false;
                          seenIds.add(p.id);
                          return true;
                        }),
                        ...state.saved.where((p) {
                          if (seenIds.contains(p.id)) return false;
                          seenIds.add(p.id);
                          return true;
                        }),
                      ];

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (sheetContext) => EditPocketEnvelopeSheet(
                          scopeParams: scopeParams,
                          existingEnvelope: pocket,
                          totalBudget: totalBudget,
                          unallocatedBudget: unallocatedBudget,
                          budgetId: state.budgetId,
                          allPockets: allPockets,
                          onDeleteCompleted: () {
                            rootNavigator.pop();
                          },
                        ),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Icon & Name
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (pocket.icon != null) ...[
                                Icon(
                                  getPocketIconData(pocket.icon),
                                  size: 28,
                                  color: textColor,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Flexible(
                                child: Text(
                                  pocket.name,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.monthlyBudget,
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Big Amount (Remaining)
                          Text(
                            _formatLocalizedCurrency(
                              context,
                              limit - pocket.spent,
                              pocket.currency,
                            ),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Allocated
                          Text(
                            '${_formatLocalizedCurrency(context, limit, pocket.currency)} allocated',
                            style: TextStyle(
                              fontSize: 16,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor:
                                  textColor.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final detailsAsync = ref.watch(
                          pocketDetailsProvider(
                            PocketTransactionsParams(
                              pocketId: pocketId,
                              scopeParams: scopeParams,
                            ),
                          ),
                        );

                        return detailsAsync.when(
                          data: (data) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  context.l10n.keyInsights,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // 1. Stats Grid
                                _StatsGrid(
                                  spent: pocket.spent,
                                  dailyAverage: data.dailyAverage,
                                  allowance: limit,
                                  currency: pocket.currency,
                                ),
                                const SizedBox(height: 24),

                                // 3. Spending Breakdown
                                if (data.categorySpending.isNotEmpty) ...[
                                  _SpendingBreakdownCard(
                                    categorySpending: data.categorySpending,
                                    currency: pocket.currency,
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // 4. Recent Transactions
                                _TransactionsListCard(
                                  transactions: data.transactions,
                                  currency: pocket.currency,
                                ),
                                // Add extra padding at bottom for scrolling
                                const SizedBox(height: 40),
                              ],
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (err, stack) => Center(
                            child: Text(context.l10n.error(err.toString())),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper function to find a pocket by ID in either editing or saved lists
PocketEnvelope? _findPocket(PocketsState state, String pocketId) {
  try {
    return state.editing.firstWhere((p) => p.id == pocketId);
  } catch (_) {
    try {
      return state.saved.firstWhere((p) => p.id == pocketId);
    } catch (_) {
      return null;
    }
  }
}

String _formatLocalizedCurrency(
  BuildContext context,
  double amount,
  String currency,
) {
  final normalized = double.parse(formatAmount(amount));
  final symbol = resolveCurrencySymbol(currency);
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.spent,
    required this.dailyAverage,
    required this.allowance,
    required this.currency,
  });

  final double spent;
  final double dailyAverage;
  final double allowance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: context.l10n.spentThisMonth,
            value: _formatLocalizedCurrency(context, spent, currency),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.l10n.avgDaily,
            value: _formatLocalizedCurrency(context, dailyAverage, currency),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.l10n.allowance,
            value: _formatLocalizedCurrency(context, allowance, currency),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _SpendingBreakdownCard extends StatelessWidget {
  const _SpendingBreakdownCard({
    required this.categorySpending,
    required this.currency,
  });

  final List<CategorySpend> categorySpending;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use a set of nice colors for the chart
    final colors = [
      const Color(0xFF4ADE80), // Green
      const Color(0xFFF87171), // Red
      const Color(0xFF60A5FA), // Blue
      const Color(0xFFFBBF24), // Yellow
      const Color(0xFFA78BFA), // Purple
      const Color(0xFFFB923C), // Orange
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.spendingBreakdown,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: categorySpending.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final color = colors[index % colors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getCategoryTranslation(context, item.category),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.foreground,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(item.percentage * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 30,
                      sections: categorySpending.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final color = colors[index % colors.length];
                        return PieChartSectionData(
                          color: color,
                          value: item.amount,
                          title: '',
                          radius: 30,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionsListCard extends StatelessWidget {
  const _TransactionsListCard({
    required this.transactions,
    required this.currency,
  });

  final List<Map<String, dynamic>> transactions;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.recentTransactions,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                context.l10n.noTransactionsYet,
                style: TextStyle(color: colorScheme.mutedForeground),
              ),
            )
          else
            Column(
              children:
                  transactions.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final tx = entry.value;
                final amount = (tx['amount_cents'] as num).toDouble() / 100.0;
                final date = DateTime.parse(tx['date']);
                final category = tx['category'] as String?;
                final description = tx['description'] ?? context.l10n.expense;
                final amountDisplay =
                    _formatLocalizedCurrency(context, amount, currency);

                return Column(
                  children: [
                    if (index > 0) const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            getCategoryIcon(category),
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                DateFormat('MMM d').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          amountDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

List<Color> _generateGradientColors(Color baseColor, bool isDarkMode) {
  final hsl = HSLColor.fromColor(baseColor);

  if (isDarkMode) {
    // Dark Mode: Rich, deep gradient with high contrast
    // Top: Vibrant base color
    final top = hsl
        .withLightness((hsl.lightness * 1.0).clamp(0.3, 0.6))
        .withSaturation((hsl.saturation * 0.9).clamp(0.5, 1.0));
    // Bottom: Much darker and hue-shifted for dramatic depth
    final bottom = hsl
        .withLightness(0.12)
        .withSaturation((hsl.saturation * 0.7).clamp(0.4, 1.0))
        .withHue((hsl.hue + 20) % 360);
    return [top.toColor(), bottom.toColor()];
  } else {
    // Light Mode: Vibrant gradient with strong contrast
    // Top: Bright, saturated version
    final top = hsl
        .withLightness(0.75)
        .withSaturation((hsl.saturation * 1.0).clamp(0.6, 1.0))
        .withHue((hsl.hue - 15) % 360);
    // Bottom: Much richer and more saturated
    final bottom = hsl
        .withLightness(0.45)
        .withSaturation((hsl.saturation * 1.1).clamp(0.7, 1.0))
        .withHue((hsl.hue + 10) % 360);
    return [top.toColor(), bottom.toColor()];
  }
}
