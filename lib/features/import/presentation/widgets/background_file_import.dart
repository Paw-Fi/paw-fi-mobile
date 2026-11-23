import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/import/data/file_import_jobs.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';

class BackgroundFileImport extends ConsumerStatefulWidget {
  const BackgroundFileImport(
      {super.key,
      required this.state,
      required this.personalOnly,
      this.source});
  final ImportWizardState state;
  final bool personalOnly;
  final ImportSourceApp? source;
  @override
  ConsumerState<BackgroundFileImport> createState() =>
      _BackgroundFileImportState();
}

class _BackgroundFileImportState extends ConsumerState<BackgroundFileImport> {
  bool uploading = false;
  int? uploadPercent;
  String? message;
  Future<void> pick([FileImportJob? interrupted]) async {
    if (uploading) return;
    final uid = ref.read(authProvider).uid;
    final settings = widget.state;
    final personalOnly = widget.personalOnly;
    final currency = ref.read(homeFilterProvider).selectedCurrency ??
        ref.read(analyticsProvider).preferredCurrency ??
        'USD';
    final language =
        (ref.read(localeProvider) ?? Localizations.localeOf(context))
            .toLanguageTag();
    final service = ref.read(fileImportJobsProvider);
    setState(() {
      uploading = true;
      uploadPercent = null;
      message = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: interrupted == null
              ? (widget.source == null
                  ? supportedImportExtensions
                  : importSourceSpecFor(widget.source!).allowedExtensions)
              : [interrupted['format'] as String],
          withData: kIsWeb);
      if (result == null) return;
      final file = result.files.single;
      final format = file.extension?.toLowerCase() ?? '';
      final maxMB = format == 'pdf' ? 20 : 50;
      if (file.size <= 0 || file.size > maxMB * 1024 * 1024) {
        throw FormatException('Choose a non-empty file up to $maxMB MB.');
      }
      if (!mounted || uid != ref.read(authProvider).uid) return;
      final bytes = file.bytes ?? await file.xFile.readAsBytes();
      final status = await service.upload(
          userId: uid,
          name: file.name,
          format: format,
          bytes: bytes,
          householdId: personalOnly ? null : settings.targetHouseholdId,
          portfolio: !personalOnly && settings.targetIsPortfolio,
          accountId: settings.targetAccountId,
          accountCurrency: settings.targetAccountCurrency,
          currency: currency,
          language: language,
          interrupted: interrupted,
          progress: (sent, total) {
            if (mounted && uid == ref.read(authProvider).uid) {
              setState(() => uploadPercent = (100 * sent / total).floor());
            }
          });
      if (!mounted || uid != ref.read(authProvider).uid) return;
      ref.invalidate(fileImportHistoryProvider(uid));
      AppToast.success(
          context,
          switch (status) {
            'completed' => 'This file has already been imported.',
            'failed' => 'This file needs attention. Check its status below.',
            _ => 'File accepted. You can close Moneko.'
          });
    } catch (e) {
      if (mounted && uid == ref.read(authProvider).uid) {
        setState(() => message = e is FormatException
            ? e.message
            : e is PostgrestException &&
                    e.message.startsWith('Background import is unavailable')
                ? e.message
                : 'Upload could not be confirmed. Check your connection and retry with the same file.');
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider.select((user) => user.uid));
    ref.listen(fileImportHistoryProvider(uid), (previous, next) {
      final rows = next.valueOrNull;
      final old = previous?.valueOrNull;
      if (rows != null &&
          rows.any((row) =>
              row['status'] == 'completed' &&
              !(old ?? const []).any((before) =>
                  before['id'] == row['id'] &&
                  before['status'] == 'completed'))) {
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state++;
        ref.read(dashboardRefreshSignalProvider.notifier).state++;
      }
    });
    final history = ref.watch(fileImportHistoryProvider(uid));
    final scope = ref.watch(householdScopeProvider);
    final destination =
        widget.personalOnly || widget.state.targetHouseholdId == null
            ? context.l10n.personal
            : scope.selected.household?.name ?? 'selected Space';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
          onPressed: uploading ? null : () => pick(),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(uploading
              ? (uploadPercent == null
                  ? 'Uploading file…'
                  : 'Uploading file · $uploadPercent%')
              : 'Import in background')),
      Text(
          'Use detected settings in $destination. Keep Moneko open until the upload is accepted.'),
      if (message != null)
        Text(message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ...history.when(
          data: (rows) => [
                for (final row in rows)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row['file_name'] as String),
                      subtitle: Text(switch (row['status']) {
                        'uploading' =>
                          'Upload pending. Select the same file to retry.',
                        'queued' =>
                          'Queued on the server. You can close Moneko.',
                        'processing' => row['total'] == null
                            ? 'Processing file on the server…'
                            : "Processing · ${row['processed']} of ${row['total']}",
                        'completed' =>
                          "Completed · ${row['imported']} imported · ${row['skipped']} skipped",
                        'failed' when row['files_removed'] == true =>
                          '${context.l10n.failed} · The stored file has expired. Choose Review before importing and select the original file.',
                        _ =>
                          "${context.l10n.failed} · ${row['error_message'] ?? 'Check the file and retry.'}"
                      }),
                      trailing: row['status'] == 'uploading'
                          ? TextButton(
                              onPressed: uploading ? null : () => pick(row),
                              child: Text(context.l10n.retry))
                          : row['retryable'] == true &&
                                  row['files_removed'] != true
                              ? TextButton(
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(fileImportJobsProvider)
                                          .retry(row['id'] as String);
                                      if (mounted) {
                                        ref.invalidate(
                                            fileImportHistoryProvider(uid));
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        AppToast.error(context,
                                            'Could not restart the job. Refresh and retry.');
                                      }
                                    }
                                  },
                                  child: Text(context.l10n.retry))
                              : null)
              ],
          loading: () => const <Widget>[],
          error: (_, __) => [
                TextButton(
                    onPressed: () =>
                        ref.invalidate(fileImportHistoryProvider(uid)),
                    child: const Text('Reload import history'))
              ]),
    ]);
  }
}
