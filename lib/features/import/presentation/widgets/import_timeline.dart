import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';

/// The horizontal timeline indicator at the top of the import wizard.
class ImportTimeline extends StatelessWidget {
  const ImportTimeline({super.key, required this.currentStep});

  final ImportStep currentStep;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ImportStep.selectFile,
      ImportStep.mapColumns,
      ImportStep.preview,
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: TimelineStep(
              stepIndex: i + 1,
              label: _labelForStep(context, steps[i]),
              isActive: steps[i] == currentStep,
              isCompleted: steps[i].index < currentStep.index,
              isLast: i == steps.length - 1,
            ),
          ),
          if (i < steps.length - 1) const TimelineConnector(),
        ],
      ],
    );
  }

  String _labelForStep(BuildContext context, ImportStep step) {
    switch (step) {
      case ImportStep.selectFile:
        return context.l10n.importStepSelect;
      case ImportStep.mapColumns:
        return context.l10n.importStepMap;
      case ImportStep.preview:
        return context.l10n.importStepPreview;
    }
  }
}

/// A single step circle with a label in the timeline.
class TimelineStep extends StatelessWidget {
  const TimelineStep({
    super.key,
    required this.stepIndex,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.isLast,
  });

  final int stepIndex;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final muted = scheme.mutedForeground.withValues(alpha: 0.3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive || isCompleted ? primary : muted,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: scheme.onPrimary,
                  )
                : Text(
                    '$stepIndex',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? scheme.onPrimary : muted,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? scheme.foreground : scheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// The dashed connector between timeline steps.
class TimelineConnector extends StatelessWidget {
  const TimelineConnector({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scheme = Theme.of(context).colorScheme;
          return Container(
            height: 2,
            margin: EdgeInsets.only(
                top: 13,
                left: constraints.maxWidth > 0 ? 8 : 0,
                right: constraints.maxWidth > 0 ? 8 : 0),
            color: scheme.primary.withValues(alpha: 0.5),
          );
        },
      ),
    );
  }
}
