import 'dart:ui' as ui;
import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/features/pockets/presentation/widgets/liquid_pocket.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final hasSeenEnvelopeModeHelp = useState(false);

    useEffect(() {
      SharedPreferences.getInstance().then((prefs) {
        hasSeenEnvelopeModeHelp.value =
            prefs.getBool('has_seen_envelope_mode_help') ?? false;
      });
      return null;
    }, []);

    void markHelpAsSeen() {
      hasSeenEnvelopeModeHelp.value = true;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('has_seen_envelope_mode_help', true);
      });
    }

    void resetHelpSeen() {
      hasSeenEnvelopeModeHelp.value = false;
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('has_seen_envelope_mode_help');
      });
    }

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
          totalAllocated: state.editing
              .fold(0.0, (sum, e) => sum + e.getLimit(totalBudget)),
          totalSpent: totalSpent,
          colorScheme: colorScheme,
          onTotalChanged: notifier.updateTotalBudget,
          envelopeMode: envelopeMode.value,
          onEnvelopeModeChanged: (value) => envelopeMode.value = value,
          currency: selectedCurrency,
          hasSeenHelp: hasSeenEnvelopeModeHelp.value,
          onHelpSeen: markHelpAsSeen,
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
            padding: const EdgeInsets.only(bottom: 100),
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
                    if (totalBudget <= 0) {
                      AppToast.info(
                          context, 'Please set a monthly budget first');
                      // Optionally scroll to top or highlight budget slider
                      return;
                    }
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) {
                        return EditPocketEnvelopeSheet(
                          scopeParams: scopeParams,
                          totalBudget: totalBudget,
                          unallocatedBudget: state.unallocatedSpend,
                          allPockets: state.editing,
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
                totalBudget: totalBudget,
                envelopeMode: true,
                onPercentageChanged: (value) =>
                    notifier.updatePocketPercentage(pocket.id, value),
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) {
                      return EditPocketEnvelopeSheet(
                        scopeParams: scopeParams,
                        existingEnvelope: pocket,
                        totalBudget: totalBudget,
                        unallocatedBudget: state.unallocatedSpend,
                        allPockets: state.editing,
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
                color: colorScheme.shadow.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
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
    required this.totalAllocated,
    required this.totalSpent,
    required this.colorScheme,
    required this.onTotalChanged,
    required this.envelopeMode,
    required this.onEnvelopeModeChanged,
    required this.currency,
    required this.hasSeenHelp,
    required this.onHelpSeen,
  });

  final double totalBudget;
  final double totalAllocated;
  final double totalSpent;
  final ColorScheme colorScheme;
  final ValueChanged<double> onTotalChanged;
  final bool envelopeMode;
  final ValueChanged<bool> onEnvelopeModeChanged;
  final String currency;
  final bool hasSeenHelp;
  final VoidCallback onHelpSeen;

  @override
  Widget build(BuildContext context) {
    final effectiveBudget = totalBudget > 0 ? totalBudget : 0.0;
    final sliderMin = 100.0;
    final sliderMax = 10000.0;
    final sliderValue = effectiveBudget.clamp(sliderMin, sliderMax).toDouble();

    final isOverBudget = totalSpent > effectiveBudget;
    final remaining = effectiveBudget - totalSpent;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            color: envelopeMode
                                ? colorScheme.primary.withOpacity(0.1)
                                : colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: envelopeMode
                                  ? colorScheme.primary.withOpacity(0.2)
                                  : colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _showEnvelopeModeSettingsModal(
                              context,
                              colorScheme,
                              envelopeMode,
                              onEnvelopeModeChanged,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                'Envelope Mode',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: envelopeMode
                                      ? colorScheme.primary
                                      : colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!hasSeenHelp) ...[
                        IconButton(
                          onPressed: () {
                            onHelpSeen();
                            _showEnvelopeModeSettingsModal(
                              context,
                              colorScheme,
                              envelopeMode,
                              onEnvelopeModeChanged,
                            );
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(24, 24),
                          ),
                          icon: Icon(
                            Icons.help_outline_rounded,
                            size: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      final controller = TextEditingController(
                          text: effectiveBudget.toStringAsFixed(0));
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
                              color: colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Set Monthly Budget',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        icon: Icon(Icons.close,
                                            color: colorScheme.mutedForeground),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  CustomTextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    autofocus: true,
                                    placeholder: '0',
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: PrimaryAdaptiveButton(
                                      onPressed: () {
                                        final val =
                                            double.tryParse(controller.text);
                                        if (val != null && val >= 0) {
                                          onTotalChanged(val.roundToDouble());
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatCurrency(effectiveBudget, currency),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            color: colorScheme.foreground,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/m',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.mutedForeground,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.surfaceContainerHighest,
                thumbColor: colorScheme.surface,
                overlayColor: colorScheme.primary.withOpacity(0.1),
                thumbShape: const _PremiumThumbShape(thumbRadius: 14),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              ),
              child: Slider(
                value: sliderValue,
                min: sliderMin,
                max: sliderMax,
                onChanged: (value) => onTotalChanged(value.roundToDouble()),
                divisions: ((sliderMax - sliderMin) / 10).round(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatCurrency(sliderMin, currency),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formatCurrency(sliderMax, currency),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumThumbShape extends SliderComponentShape {
  final double thumbRadius;

  const _PremiumThumbShape({this.thumbRadius = 14});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 4);

    canvas.drawCircle(center.translate(0, 2), thumbRadius, shadowPaint);

    final Paint fillPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, thumbRadius, fillPaint);

    final Paint borderPaint = Paint()
      ..color = sliderTheme.activeTrackColor!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, thumbRadius, borderPaint);
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
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withOpacity(0.08),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Pocket',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
    required this.totalBudget,
    required this.envelopeMode,
    required this.onPercentageChanged,
    this.onTap,
  });

  final PocketEnvelope pocket;
  final ColorScheme colorScheme;
  final double totalBudget;
  final bool envelopeMode;
  final ValueChanged<double> onPercentageChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final limit = pocket.getLimit(totalBudget);
    final progress = limit > 0 ? (pocket.spent / limit) : 0.0;
    final isOverBudget = pocket.isOverBudget(totalBudget);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine base color
    Color baseColor = _getColor(pocket.color, colorScheme.primary);
    if (isDarkMode && pocket.color != null) {
      final hsl = HSLColor.fromColor(baseColor);
      baseColor =
          hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    }

    final Color fillColor;
    if (isOverBudget) {
      fillColor = colorScheme.error;
    } else if (progress > 0.9) {
      fillColor = Colors.orange;
    } else {
      fillColor = baseColor;
    }

    final iconData = _getIconData(pocket.icon);

    // Calculate text color based on fill level for contrast
    // Since we are using a liquid fill, the text might be over the liquid or the background.
    // For simplicity and readability in this premium design, we'll use a glassmorphism card
    // with the liquid in the background, and text on top with a slight shadow or background.

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Liquid Animation
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return LiquidPocket(
                    fillLevel: value,
                    color: fillColor,
                  );
                },
              ),
            ),

            // Content Overlay
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              iconData,
                              size: 18,
                              color: baseColor,
                            ),
                          ),
                          if (isOverBudget)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.priority_high_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pocket.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  formatCurrency(pocket.spent, pocket.currency),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isOverBudget
                                        ? Colors.red.shade700
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  ' / ${formatCurrency(limit, pocket.currency)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 4,
                                width: double.infinity,
                                color: Colors.black.withOpacity(0.1),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: _getProgressGradient(
                                          baseColor,
                                          progress,
                                          isOverBudget,
                                          isDarkMode,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (envelopeMode) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 20,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
                              thumbColor: Colors.white,
                              thumbShape:
                                  const _PremiumThumbShape(thumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16),
                              overlayColor: Colors.white.withOpacity(0.2),
                            ),
                            child: Slider(
                              value: pocket.percentage.clamp(0, 100).toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 100,
                              onChanged: (value) => onPercentageChanged(value),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Color> _getProgressGradient(
  Color baseColor,
  double progress,
  bool isOverBudget,
  bool isDarkMode,
) {
  final hsl = HSLColor.fromColor(baseColor);

  if (isOverBudget) {
    // Over budget: Use red tones
    final errorColor = isDarkMode
        ? HSLColor.fromAHSL(1.0, 0, 0.7, 0.5) // Bright red for dark mode
        : HSLColor.fromAHSL(1.0, 0, 0.7, 0.45); // Deep red for light mode
    return [
      errorColor.toColor(),
      errorColor
          .withLightness((errorColor.lightness - 0.1).clamp(0.0, 1.0))
          .toColor(),
    ];
  } else if (progress > 0.9) {
    // Warning state (90-100%): Use orange/amber tones
    final warningColor = isDarkMode
        ? HSLColor.fromAHSL(1.0, 30, 0.8, 0.55) // Bright orange for dark mode
        : HSLColor.fromAHSL(1.0, 30, 0.8, 0.5); // Deep orange for light mode
    return [
      warningColor.toColor(),
      warningColor
          .withLightness((warningColor.lightness - 0.1).clamp(0.0, 1.0))
          .toColor(),
    ];
  } else {
    // Normal state: Use pocket's custom color with appropriate shading
    if (isDarkMode) {
      // Dark mode: Brighten the base color for visibility
      final brightened =
          hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0));
      return [
        brightened.toColor(),
        brightened
            .withLightness((brightened.lightness - 0.15).clamp(0.0, 1.0))
            .toColor(),
      ];
    } else {
      // Light mode: Use base color with slight darkening for gradient
      return [
        baseColor,
        hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor(),
      ];
    }
  }
}

void _showEnvelopeModeSettingsModal(
  BuildContext context,
  ColorScheme colorScheme,
  bool envelopeMode,
  ValueChanged<bool> onEnvelopeModeChanged,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'View Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.border.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mail_outline_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Envelope Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Allocate budget to individual pockets',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: envelopeMode,
                    onChanged: (value) {
                      onEnvelopeModeChanged(value);
                      Navigator.pop(context);
                    },
                    activeColor: colorScheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'How it works',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Allocate your income',
              description:
                  'Divide your total monthly budget into specific categories or "pockets".',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.track_changes_rounded,
              title: 'Track spending',
              description:
                  'See exactly how much you have left in each pocket as you spend.',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.warning_amber_rounded,
              title: 'Avoid overspending',
              description:
                  'Get visual alerts when a pocket is running low or over budget.',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
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
                  '${formatCurrency(amount, currency)} uncategorized',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These transactions are not covered by any pocket.',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.mutedForeground.withOpacity(0.7),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
