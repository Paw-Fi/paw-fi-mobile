import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

/// Explains that the OS will no longer show its microphone prompt and offers
/// the only recovery path: the app's page in system Settings.
Future<void> showMicrophoneAccessSheet(BuildContext context) {
  return MonekoBottomSheet.show<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const SingleChildScrollView(
      child: _MicrophoneAccessSheetBody(),
    ),
  );
}

class _MicrophoneAccessSheetBody extends StatelessWidget {
  const _MicrophoneAccessSheetBody();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MonekoBottomSheet.horizontalPadding,
          0,
          MonekoBottomSheet.horizontalPadding,
          12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.sheetElementBackground,
                border: Border.all(color: colorScheme.sheetBorder, width: 0.5),
              ),
              child: SizedBox.square(
                dimension: 56,
                child: Icon(
                  Icons.mic_off_rounded,
                  size: 28,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.microphoneOffTitle,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.microphoneOffDescription,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: PrimaryAdaptiveButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await AppSettings.openAppSettings();
                },
                child: Text(
                  context.l10n.openSettingsAction,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 4),
            PlainAdaptiveButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.notNow),
            ),
          ],
        ),
      ),
    );
  }
}
