import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'dart:math' as math;
import 'dashboard_config.dart';
import 'dashboard_state.dart';

// ============================================================================
// EDIT BUTTON
// ============================================================================

class EditDashboardButton extends ConsumerWidget {
  const EditDashboardButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(isEditModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    void toggleEditMode() {
      ref.read(isEditModeProvider.notifier).state = !isEditMode;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: isEditMode
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: toggleEditMode,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.done,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.check_rounded,
                                size: 16, color: colorScheme.onPrimary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Hold and drag to reorder widgets",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: toggleEditMode,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.editWidgets,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ============================================================================
// WIDGET WRAPPER (Handles Edit Mode UI)
// ============================================================================

class DashboardWidgetWrapper extends ConsumerStatefulWidget {
  final DashboardWidgetConfig config;
  final Widget child;
  final VoidCallback onToggleVisibility;
  final VoidCallback onEdit;

  const DashboardWidgetWrapper({
    super.key,
    required this.config,
    required this.child,
    required this.onToggleVisibility,
    required this.onEdit,
  });

  @override
  ConsumerState<DashboardWidgetWrapper> createState() =>
      _DashboardWidgetWrapperState();
}

class _DashboardWidgetWrapperState extends ConsumerState<DashboardWidgetWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _jiggleController;
  late Animation<double> _jiggleAnimation;

  @override
  void initState() {
    super.initState();
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _jiggleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _jiggleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _jiggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(isEditModeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final hasConfigOptions = widget.config.type.hasEditableOptions;

    if (isEditMode) {
      if (!_jiggleController.isAnimating) {
        _jiggleController.repeat();
      }
    } else {
      _jiggleController.reset();
    }

    // If hidden and NOT in edit mode, show nothing
    if (!widget.config.isVisible && !isEditMode) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _jiggleAnimation,
      builder: (context, child) {
        final angle =
            isEditMode ? _calculateJiggleAngle(_jiggleAnimation.value) : 0.0;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: Stack(
        children: [
          // The Widget Content
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.config.isVisible ? 1.0 : 0.4, // Dim if hidden
            child: AbsorbPointer(
              absorbing:
                  isEditMode, // Disable interaction with widget content in edit mode
              child: Container(
                child: widget.child,
              ),
            ),
          ),

          // Edit Controls Overlay
          if (isEditMode)
            Positioned(
              top: 8,
              right: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit Settings (Date Range)
                    if (widget.config.isVisible && hasConfigOptions) ...[
                      GestureDetector(
                        onTap: widget.onEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .shadow
                                    .withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_calendar,
                                  size: 18, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                widget.config.dateRange.getLabel(context),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Visibility Toggle
                    _buildCircleButton(
                      context,
                      icon: widget.config.isVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: widget.config.isVisible
                          ? colorScheme.secondary
                          : colorScheme.outline,
                      onTap: widget.onToggleVisibility,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateJiggleAngle(double t) {
    const period = 0.6;
    final cycle = (t / period) % 1.0;
    return math.sin(cycle * 2 * math.pi) * 0.01;
  }

  Widget _buildCircleButton(BuildContext context,
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ============================================================================
// DRAGGABLE LIST
// ============================================================================

class DraggableDashboardList extends ConsumerWidget {
  final List<DashboardWidgetConfig> configs;
  final Map<DashboardWidgetType,
      Widget Function(BuildContext, DashboardWidgetConfig)> widgetBuilders;
  final Function(int, int) onReorder;
  final Function(String) onToggleVisibility;
  final Function(String,
      {DateRangeFilter? dateRange,
      DashboardWidgetViewMode? viewMode,
      DateTime? start,
      DateTime? end}) onUpdateConfig;

  const DraggableDashboardList({
    super.key,
    required this.configs,
    required this.widgetBuilders,
    required this.onReorder,
    required this.onToggleVisibility,
    required this.onUpdateConfig,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(isEditModeProvider);

    return SliverReorderableList(
      itemCount: configs.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final config = configs[index];
        final builder = widgetBuilders[config.type];

        if (builder == null) {
          return const SizedBox.shrink(key: ValueKey('empty'));
        }

        if (!isEditMode && !config.isVisible) {
          return SizedBox.shrink(key: ValueKey(config.id));
        }

        return ReorderableDelayedDragStartListener(
          key: ValueKey(config.id),
          index: index,
          enabled: isEditMode,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: DashboardWidgetWrapper(
              config: config,
              onToggleVisibility: () => onToggleVisibility(config.id),
              onEdit: () => _showConfigPicker(context, config, onUpdateConfig),
              child: builder(context, config),
            ),
          ),
        );
      },
    );
  }

  void _showConfigPicker(
    BuildContext context,
    DashboardWidgetConfig config,
    Function(String,
            {DateRangeFilter? dateRange,
            DashboardWidgetViewMode? viewMode,
            DateTime? start,
            DateTime? end})
        onUpdate,
  ) {
    if (!config.type.hasEditableOptions) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
      builder: (context) => WidgetConfigurationSheet(
        config: config,
        onUpdate: (
            {DateRangeFilter? dateRange,
            DashboardWidgetViewMode? viewMode,
            DateTime? start,
            DateTime? end}) {
          onUpdate(config.id,
              dateRange: dateRange, viewMode: viewMode, start: start, end: end);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class WidgetConfigurationSheet extends StatelessWidget {
  final DashboardWidgetConfig config;
  final Function(
      {DateRangeFilter? dateRange,
      DashboardWidgetViewMode? viewMode,
      DateTime? start,
      DateTime? end}) onUpdate;

  const WidgetConfigurationSheet({
    super.key,
    required this.config,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final supportsViewMode = config.type.supportsViewMode;
    final supportsDateRange = config.type.supportsDateRange;

    if (!supportsViewMode && !supportsDateRange) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.appleGroupedBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (supportsViewMode) ...[
                  // View Mode Section Header
                  Text(
                    context.l10n.viewMode,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // View Mode Segmented Control
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildSegmentOption(
                          context,
                          label: context.l10n.viewModeMini,
                          isSelected:
                              config.viewMode == DashboardWidgetViewMode.mini,
                          isSupported: config.type.supportedViewModes
                              .contains(DashboardWidgetViewMode.mini),
                          onTap: () =>
                              onUpdate(viewMode: DashboardWidgetViewMode.mini),
                        ),
                        _buildSegmentOption(
                          context,
                          label: context.l10n.viewModeWide,
                          isSelected:
                              config.viewMode == DashboardWidgetViewMode.wide,
                          isSupported: config.type.supportedViewModes
                              .contains(DashboardWidgetViewMode.wide),
                          onTap: () =>
                              onUpdate(viewMode: DashboardWidgetViewMode.wide),
                        ),
                        _buildSegmentOption(
                          context,
                          label: context.l10n.viewModeFull,
                          isSelected:
                              config.viewMode == DashboardWidgetViewMode.full,
                          isSupported: config.type.supportedViewModes
                              .contains(DashboardWidgetViewMode.full),
                          onTap: () =>
                              onUpdate(viewMode: DashboardWidgetViewMode.full),
                        ),
                      ],
                    ),
                  ),
                  if (supportsDateRange) ...[
                    const SizedBox(height: 24),
                    Divider(
                        height: 1,
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.2)),
                  ],
                ],
                if (!supportsViewMode && supportsDateRange)
                  const SizedBox(height: 8),
                if (supportsDateRange) ...[
                  // Date Range Section Header
                  Text(
                    context.l10n.dateRange,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  MonekoInput(
                    child: Column(
                      children: [
                        ...DateRangeFilter.values.map((range) {
                          final isSelected = range == config.dateRange;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(32),
                              onTap: () async {
                                if (range == DateRangeFilter.custom) {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: colorScheme,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    onUpdate(
                                        dateRange: range,
                                        start: picked.start,
                                        end: picked.end);
                                  }
                                } else {
                                  onUpdate(dateRange: range);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      range.getLabel(context),
                                      style: TextStyle(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        color: colorScheme.primary,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentOption(BuildContext context,
      {required String label,
      required bool isSelected,
      required bool isSupported,
      required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: isSupported ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSupported
                  ? (isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant)
                  : colorScheme.outline.withValues(alpha: 0.5),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
