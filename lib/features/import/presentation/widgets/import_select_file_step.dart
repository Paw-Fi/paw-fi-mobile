import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/features/import/presentation/widgets/import_shared_widgets.dart';

/// The first wizard step: source selection and file pick.
class SelectFileStep extends ConsumerWidget {
  const SelectFileStep({
    super.key,
    required this.state,
    this.sourceApp,
    required this.lockPersonalTarget,
  });

  final ImportWizardState state;
  final ImportSourceApp? sourceApp;
  final bool lockPersonalTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(importWizardProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final sourceSpec =
        sourceApp == null ? null : importSourceSpecFor(sourceApp!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstructionCard(
          icon: Icons.upload_file_rounded,
          title: context.l10n.importSelectFileTitle,
          description: context.l10n.importSelectFileHint,
        ),
        if (sourceSpec != null) ...[
          const SizedBox(height: 12),
          InstructionCard(
            icon: Icons.sync_alt_rounded,
            title: 'Source: ${importSourceLabel(sourceSpec.app)}',
            description: importSourceFileRequest(sourceSpec.app),
          ),
          if (lockPersonalTarget) ...[
            const SizedBox(height: 8),
            Text(
              'Imports in this onboarding step always sync to your personal account.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.mutedForeground,
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
        GroupedSectionCard(
          title: context.l10n.file.toUpperCase(),
          children: [
            StandardTile(
              leadingIcon: Icons.description_rounded,
              title: state.fileName ?? context.l10n.noFileSelected,
              subtitle: sourceSpec == null
                  ? context.l10n.csvTxtSupported
                  : importSourceFileRequest(sourceSpec.app),
              trailing: state.isParsing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: scheme.mutedForeground.withValues(alpha: 0.6),
                    ),
              onTap: state.isParsing
                  ? null
                  : () => notifier.pickFile(
                        allowedExtensions: sourceSpec?.allowedExtensions,
                      ),
            ),
          ],
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: state.errorMessage!),
        ],
      ],
    );
  }
}
