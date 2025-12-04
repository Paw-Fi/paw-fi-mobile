import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'dashboard_config.dart';
import 'dashboard_state.dart';
import 'package:moneko/core/theme/app_theme.dart';

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
                      color: colorScheme.mutedForeground
                          .withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: toggleEditMode,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 1,
                      color: colorScheme.mutedForeground
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.editWidgets,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 1,
                      color: colorScheme.mutedForeground
                          .withValues(alpha: 0.3),
                    ),
                  ],
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
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(isEditModeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final hasConfigOptions = widget.config.type.hasEditableOptions;

    if (isEditMode) {
      if (!_shakeController.isAnimating) {
        _shakeController.repeat(reverse: true);
      }
    } else {
      _shakeController.reset();
    }

    // If hidden and NOT in edit mode, show nothing
    if (!widget.config.isVisible && !isEditMode) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        return child!;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
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
                      _buildCircleButton(
                        context,
                        icon: Icons.edit,
                        color: colorScheme.primary,
                        onTap: widget.onEdit,
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
              color: Colors.black.withValues(alpha: 0.1),
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
      backgroundColor: Colors.transparent,
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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.l10n.configureWidget,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),

              if (supportsViewMode) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Text(
                    context.l10n.viewMode,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                ),
                if (supportsDateRange) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                ],
              ],

              if (!supportsViewMode && supportsDateRange)
                const SizedBox(height: 8),

              if (supportsDateRange) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Text(
                    context.l10n.dateRange,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                ...DateRangeFilter.values.map((range) {
                  final isSelected = range == config.dateRange;
                  return ListTile(
                    title: Text(
                      range.getLabel(context),
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: colorScheme.primary)
                        : null,
                    onTap: () async {
                      if (range == DateRangeFilter.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
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
                  );
                }),
              ],
              const SizedBox(height: 16),
            ],
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
