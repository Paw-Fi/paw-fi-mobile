import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/services/interactive_ai_analysis.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

Future<String?> showAiCorrectionSheet(
    BuildContext context, AiAnalysisQuestion question) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.sheetBackground,
    builder: (_) => AiCorrectionSheet(question: question),
  );
}

class AiCorrectionSheet extends HookWidget {
  const AiCorrectionSheet({super.key, required this.question});

  final AiAnalysisQuestion question;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    useListenable(controller);
    final scheme = Theme.of(context).colorScheme;
    final text = controller.text.trim();
    void submit(String answer) {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop(answer);
    }

    return AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: ModalSheetHandle()),
            const SizedBox(height: 20),
            Text(question.question,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(context.l10n.aiClarificationNotSaved,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.mutedForeground)),
            const SizedBox(height: 16),
            ...question.choices.map((choice) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                      onPressed: () => submit(choice),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: BorderSide(color: scheme.sheetBorder)),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(choice, textAlign: TextAlign.center))),
                )),
            const SizedBox(height: 12),
            Text(context.l10n.other,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AdaptiveTextField(
                controller: controller,
                placeholder: context.l10n.aiClarificationCustomAnswer,
                maxLines: 3),
            const SizedBox(height: 16),
            PrimaryAdaptiveButton(
                onPressed: text.isEmpty || text.length > 4000
                    ? null
                    : () => submit(text),
                child: Text(context.l10n.continueAction)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.cancel)),
          ],
        ),
      ),
    );
  }
}
