import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/subscription/data/subscription_cancel_reason_repository.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class CancelReasonSheet extends StatefulWidget {
  const CancelReasonSheet({super.key});

  static Future<CancelReasonSubmission?> show(BuildContext context) {
    return MonekoBottomSheet.show<CancelReasonSubmission>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CancelReasonSheet(),
    );
  }

  @override
  State<CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<CancelReasonSheet> {
  CancelReasonId? _selected;
  late final TextEditingController _detailController;

  @override
  void initState() {
    super.initState();
    _detailController = TextEditingController();
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  String _labelFor(BuildContext context, CancelReasonId reason) {
    final l10n = context.l10n;
    return switch (reason) {
      CancelReasonId.tooExpensive => l10n.cancelReasonTooExpensive,
      CancelReasonId.foundAlternative => l10n.cancelReasonFoundAlternative,
      CancelReasonId.notUsingEnough => l10n.cancelReasonNotUsingEnough,
      CancelReasonId.appIssue => l10n.cancelReasonAppIssue,
      CancelReasonId.missingSpecificFeature =>
        l10n.cancelReasonMissingSpecificFeature,
      CancelReasonId.other => l10n.cancelReasonOther,
    };
  }

  String? _detailPlaceholderFor(BuildContext context, CancelReasonId reason) {
    final l10n = context.l10n;
    return switch (reason) {
      CancelReasonId.appIssue => l10n.cancelReasonAppIssuePlaceholder,
      CancelReasonId.missingSpecificFeature =>
        l10n.cancelReasonMissingSpecificFeaturePlaceholder,
      CancelReasonId.other => l10n.cancelReasonOtherPlaceholder,
      _ => null,
    };
  }

  bool get _canContinue {
    final selected = _selected;
    if (selected == null) return false;
    if (selected.requiresDetail) {
      return _detailController.text.trim().isNotEmpty;
    }
    return true;
  }

  void _handleContinue() {
    final selected = _selected;
    if (selected == null) return;
    if (selected.requiresDetail && _detailController.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      CancelReasonSubmission(
        reason: selected,
        reasonLabel: _labelFor(context, selected),
        detailText:
            selected.requiresDetail ? _detailController.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const reasons = CancelReasonId.values;
    final selectedRequiresDetail = _selected?.requiresDetail ?? false;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cancelReasonTitle,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.cancelReasonSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: reasons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final reason = reasons[index];
                  return _CancelReasonTile(
                    reason: reason,
                    label: _labelFor(context, reason),
                    isSelected: _selected == reason,
                    onTap: () => setState(() {
                      _selected = reason;
                      if (!reason.requiresDetail) {
                        _detailController.clear();
                      }
                    }),
                  );
                },
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: selectedRequiresDetail
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AdaptiveTextField(
                        controller: _detailController,
                        placeholder:
                            _detailPlaceholderFor(context, _selected!) ?? '',
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _canContinue ? 1.0 : 0.5,
              child: PrimaryAdaptiveButton(
                onPressed: _canContinue ? _handleContinue : null,
                child: Text(l10n.cancelReasonContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelReasonTile extends StatelessWidget {
  const _CancelReasonTile({
    required this.reason,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final CancelReasonId reason;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: isSelected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _RadioDot(isSelected: isSelected),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.mutedForeground.withValues(alpha: 0.5),
          width: isSelected ? 6 : 2,
        ),
      ),
    );
  }
}
