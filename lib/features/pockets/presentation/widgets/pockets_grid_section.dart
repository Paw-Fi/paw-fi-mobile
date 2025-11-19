import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';

class PocketsGridSection extends HookConsumerWidget {
  const PocketsGridSection({
    super.key,
    required this.scopeParams,
    required this.colorScheme,
    required this.isPersonalMode,
  });

  final PocketsScopeParams scopeParams;
  final ColorScheme colorScheme;
  final bool isPersonalMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);
    final filter = ref.watch(homeFilterProvider);
    final selectedCurrency = filter.selectedCurrency ?? 'USD';

    // Local state for Envelope Mode
    final envelopeMode = useState(true);

    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      );
    }

    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.destructive,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final totalBudget = state.totalBudget;
    final totalSpent = state.totalSpent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _PocketsHeaderCard(
          totalBudget: totalBudget,
          totalSpent: totalSpent,
          colorScheme: colorScheme,
          onTotalChanged: notifier.updateTotalBudget,
          envelopeMode: envelopeMode.value,
          onEnvelopeModeChanged: (value) => envelopeMode.value = value,
          currency: selectedCurrency,
        ),
        if (state.unallocatedSpend > 0) ...[
          const SizedBox(height: 16),
          _UnallocatedSpendCard(
            amount: state.unallocatedSpend,
            currency: selectedCurrency,
            colorScheme: colorScheme,
          ),
        ],
        const SizedBox(height: 24),

        // Mode-Specific Content
        if (envelopeMode.value) ...[
          Row(
            children: [
              Text(
                'Your Pockets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: colorScheme.foreground,
                ),
              ),
              const Spacer(),
              if (state.editing.isNotEmpty)
                Text(
                  '${state.editing.length} active',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: state.editing.length + 1,
            itemBuilder: (context, index) {
              final isAddTile = index == state.editing.length;
              if (isAddTile) {
                return _AddEnvelopeCard(
                  colorScheme: colorScheme,
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) {
                        return EditPocketEnvelopeSheet(
                          scopeParams: scopeParams,
                        );
                      },
                    );
                  },
                );
              }

              final pocket = state.editing[index];
              return _PocketCard(
                pocket: pocket,
                colorScheme: colorScheme,
                maxBudget: totalBudget > 0 ? totalBudget : pocket.limit,
                envelopeMode: true,
                onLimitChanged: (value) =>
                    notifier.updatePocketLimit(pocket.id, value),
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) {
                      return EditPocketEnvelopeSheet(
                        scopeParams: scopeParams,
                        existingEnvelope: pocket,
                      );
                    },
                  );
                },
              );
            },
          ),
        ] else ...[
          // Simple Mode: Spending Breakdown List
          Row(
            children: [
              Text(
                'Spending Breakdown',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: colorScheme.foreground,
                ),
              ),
              const Spacer(),
              Text(
                'By Category',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SimpleSpendingList(
            pockets: state.editing,
            totalSpent: totalSpent,
            colorScheme: colorScheme,
            currency: selectedCurrency,
          ),
        ],
      ],
    );
  }
}

class _SimpleSpendingList extends StatelessWidget {
  const _SimpleSpendingList({
    required this.pockets,
    required this.totalSpent,
    required this.colorScheme,
    required this.currency,
  });

  final List<PocketEnvelope> pockets;
  final double totalSpent;
  final ColorScheme colorScheme;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (pockets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No spending data yet.',
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
        ),
      );
    }

    // Sort by spent amount (descending)
    final sortedPockets = [...pockets]
      ..sort((a, b) => b.spent.compareTo(a.spent));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedPockets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pocket = sortedPockets[index];
        final percentageOfTotal =
            totalSpent > 0 ? (pocket.spent / totalSpent) : 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.border.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons
                          .category_outlined, // Ideally dynamic based on category
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pocket.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(percentageOfTotal * 100).toStringAsFixed(1)}% of spending',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrency(pocket.spent, pocket.currency),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Visual Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: colorScheme.muted.withOpacity(0.1),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentageOfTotal.clamp(0.0, 1.0),
                    child: Container(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PocketsHeaderCard extends StatelessWidget {
  const _PocketsHeaderCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.colorScheme,
    required this.onTotalChanged,
    required this.envelopeMode,
    required this.onEnvelopeModeChanged,
    required this.currency,
  });

  final double totalBudget;
  final double totalSpent;
  final ColorScheme colorScheme;
  final ValueChanged<double> onTotalChanged;
  final bool envelopeMode;
  final ValueChanged<bool> onEnvelopeModeChanged;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final effectiveBudget = totalBudget > 0 ? totalBudget : 0.0;
    final sliderMin = 100.0;
    final sliderMax = 10000.0;
    final sliderValue = effectiveBudget.clamp(sliderMin, sliderMax).toDouble();

    final progress = effectiveBudget > 0
        ? (totalSpent / effectiveBudget).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = totalSpent > effectiveBudget;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colorScheme.border.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background Progress Fill (Subtle)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.05),
                          colorScheme.primary.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Envelope Mode',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.help_outline,
                              size: 16,
                              color: colorScheme.mutedForeground,
                            ),
                            onPressed: () => _showEnvelopeModeInfoModal(
                                context, colorScheme),
                          ),
                          const SizedBox(width: 8),
                          AdaptiveSwitch(
                            value: envelopeMode,
                            onChanged: onEnvelopeModeChanged,
                            activeColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          formatCurrency(effectiveBudget, currency),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            color: colorScheme.foreground,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Spent: ${formatCurrency(totalSpent, currency)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isOverBudget
                                ? colorScheme.destructive
                                : colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  AdaptiveSlider(
                    value: sliderValue,
                    min: sliderMin,
                    max: sliderMax,
                    onChanged: onTotalChanged,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatCurrency(sliderMin, currency),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.mutedForeground.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        formatCurrency(sliderMax, currency),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.mutedForeground.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEnvelopeCard extends StatelessWidget {
  const _AddEnvelopeCard({
    required this.colorScheme,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.border.withOpacity(0.5),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.add,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'New Pocket',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _getColor(String? colorHex, Color fallback) {
  if (colorHex == null) return fallback;
  try {
    return Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
  } catch (_) {
    return fallback;
  }
}

IconData _getIconData(String? iconName) {
  switch (iconName) {
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_car':
      return Icons.directions_car;
    case 'home':
      return Icons.home;
    case 'flight':
      return Icons.flight;
    case 'medical_services':
      return Icons.medical_services;
    case 'school':
      return Icons.school;
    case 'pets':
      return Icons.pets;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'local_cafe':
      return Icons.local_cafe;
    case 'local_bar':
      return Icons.local_bar;
    case 'movie':
      return Icons.movie;
    case 'music_note':
      return Icons.music_note;
    case 'savings':
      return Icons.savings;
    case 'account_balance':
      return Icons.account_balance;
    default:
      return Icons.savings_outlined;
  }
}

class _PocketCard extends StatelessWidget {
  const _PocketCard({
    required this.pocket,
    required this.colorScheme,
    required this.maxBudget,
    required this.envelopeMode,
    required this.onLimitChanged,
    this.onTap,
  });

  final PocketEnvelope pocket;
  final ColorScheme colorScheme;
  final double maxBudget;
  final bool envelopeMode;
  final ValueChanged<double> onLimitChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = pocket.limit > 0 ? (pocket.spent / pocket.limit) : 0.0;
    final isOverBudget = pocket.isOverBudget;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine base color
    Color baseColor = _getColor(pocket.color, colorScheme.primary);
    if (isDarkMode && pocket.color != null) {
      // Darken user selected color in dark mode
      final hsl = HSLColor.fromColor(baseColor);
      baseColor =
          hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    }

    final Color fillColor;
    if (isOverBudget) {
      fillColor = colorScheme.destructive;
    } else if (progress > 0.9) {
      fillColor = Colors.orange;
    } else {
      fillColor = baseColor;
    }

    final iconData = _getIconData(pocket.icon);

    // Text Contrast Colors
    final emptyTextColor = colorScheme.foreground;
    final filledTextColor =
        ThemeData.estimateBrightnessForColor(fillColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: colorScheme.border.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutQuart,
            builder: (context, animatedProgress, child) {
              return Stack(
                children: [
                  // Liquid Fill Background
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: animatedProgress,
                        widthFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: fillColor, // Full opacity
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Content with ShaderMask for contrast
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                emptyTextColor,
                                emptyTextColor,
                                filledTextColor,
                                filledTextColor
                              ],
                              stops: [
                                0.0,
                                1.0 - animatedProgress,
                                1.0 - animatedProgress,
                                1.0
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcIn,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface
                                          .withOpacity(0.2), // Translucent
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      iconData,
                                      size: 16,
                                      color: Colors
                                          .white, // Color handled by ShaderMask
                                    ),
                                  ),
                                  if (isOverBudget)
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: colorScheme
                                          .destructive, // Warning icon keeps its color?
                                      // ShaderMask will override this!
                                      // If we want warning icon to stay red, we should exclude it from ShaderMask.
                                      size: 20,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                pocket.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: formatCurrency(
                                          pocket.spent, pocket.currency),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(text: ' / '),
                                    TextSpan(
                                        text: formatCurrency(
                                            pocket.limit, pocket.currency)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Slider (Only in Envelope Mode)
                        if (envelopeMode) ...[
                          SizedBox(
                            height: 24,
                            child: AdaptiveSlider(
                              value: pocket.limit
                                  .clamp(0,
                                      maxBudget > 0 ? maxBudget : pocket.limit)
                                  .toDouble(),
                              min: 0,
                              max: maxBudget > 0
                                  ? maxBudget
                                  : pocket.limit + 1000,
                              onChanged: onLimitChanged,
                            ),
                          ),
                        ] else ...[
                          // Progress Bar for Non-Envelope Mode
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: colorScheme.muted.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: fillColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

void _showEnvelopeModeInfoModal(BuildContext context, ColorScheme colorScheme) {
  final slides = [
    _EnvelopeModeSlideData(
      title: 'What is Envelope Mode?',
      summary:
          'Envelope Mode mimics the traditional envelope budgeting method. You assign every dollar of your budget to a specific "pocket" or category.',
      points: [
        'Set specific limits for each category',
        'Prevent overspending in one area',
        'See exactly where your money goes',
      ],
    ),
    _EnvelopeModeSlideData(
      title: 'How it Works',
      summary:
          'In this mode, you can use the sliders on each pocket to allocate your total monthly budget.',
      points: [
        'Adjust individual pocket limits',
        'Total budget updates automatically',
        'Visual alerts when nearing limits',
      ],
    ),
  ];

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final controller = PageController();
      int currentPage = 0;

      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: colorScheme.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Envelope Mode Guide',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: colorScheme.mutedForeground),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: PageView.builder(
                        controller: controller,
                        itemCount: slides.length,
                        onPageChanged: (index) {
                          setState(() => currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          final slide = slides[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slide.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.foreground,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slide.summary,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ...slide.points.map(
                                (point) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded,
                                          size: 18, color: colorScheme.primary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.3,
                                            color: colorScheme.foreground,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (index) {
                        final isActive = index == currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: isActive ? 24 : 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? colorScheme.primary
                                : colorScheme.muted.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: AdaptiveButton(
                        onPressed: () {
                          if (currentPage < slides.length - 1) {
                            controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          } else {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        style: AdaptiveButtonStyle.filled,
                        label:
                            currentPage < slides.length - 1 ? 'Next' : 'Got it',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _UnallocatedSpendCard extends StatelessWidget {
  const _UnallocatedSpendCard({
    required this.amount,
    required this.currency,
    required this.colorScheme,
  });

  final double amount;
  final String currency;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unallocated Spend',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatCurrency(amount, currency)} not in any pocket',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvelopeModeSlideData {
  const _EnvelopeModeSlideData(
      {required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}
