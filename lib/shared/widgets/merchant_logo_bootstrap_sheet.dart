import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showMerchantLogoBootstrapSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.sheetBackground,
      builder: (_) => const _MerchantLogoBootstrapSheet(),
    );

class _MerchantLogoBootstrapSheet extends StatefulWidget {
  const _MerchantLogoBootstrapSheet();

  @override
  State<_MerchantLogoBootstrapSheet> createState() =>
      _MerchantLogoBootstrapSheetState();
}

class _MerchantLogoBootstrapSheetState
    extends State<_MerchantLogoBootstrapSheet> {
  String? _runId;
  bool _loading = false;
  String? _error;
  int _total = 0;
  int _processed = 0;
  int _resolved = 0;
  int _ambiguous = 0;
  int _skipped = 0;
  int _remaining = 0;
  bool _quotaExhausted = false;
  List<Map<String, dynamic>> _groups = const [];

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await Supabase.instance.client.functions.invoke(
      'merchant-logo-bootstrap',
      body: body,
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (data['success'] != true) {
      throw StateError(data['error']?.toString() ?? 'Merchant scan failed');
    }
    return data;
  }

  Future<void> _start() async {
    await _run(() async {
      final started = await _invoke({'action': 'start'});
      _runId = started['runId']?.toString();
      _total = (started['totalGroups'] as num?)?.toInt() ?? 0;
      await _loadNext();
    });
  }

  Future<void> _loadNext() async {
    final runId = _runId;
    if (runId == null) return;
    final data = await _invoke({'action': 'next', 'runId': runId});
    _applyProgress(data);
  }

  Future<void> _continue() => _run(_loadNext);

  Future<void> _select(
    Map<String, dynamic> group,
    Map<String, dynamic> candidate,
  ) =>
      _run(() async {
        final data = await _invoke({
          'action': 'select',
          'runId': _runId,
          'groupId': group['id'],
          'selectedName': candidate['name'],
          'selectedDomain': candidate['domain'],
        });
        _applyProgress(data);
      });

  Future<void> _skip(Map<String, dynamic> group) => _run(() async {
        final data = await _invoke({
          'action': 'skip',
          'runId': _runId,
          'groupId': group['id'],
        });
        _applyProgress(data);
      });

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) _error = context.l10n.merchantLogoScanError;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProgress(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _total = (data['totalGroups'] as num?)?.toInt() ?? _total;
      _processed = (data['processedGroups'] as num?)?.toInt() ?? _processed;
      _resolved = (data['resolvedGroups'] as num?)?.toInt() ?? _resolved;
      _ambiguous = (data['ambiguousGroups'] as num?)?.toInt() ?? _ambiguous;
      _skipped = (data['skippedGroups'] as num?)?.toInt() ?? _skipped;
      _remaining = (data['remainingGroups'] as num?)?.toInt() ?? _remaining;
      _quotaExhausted = data['quotaExhausted'] == true;
      _groups = (data['groups'] as List? ?? const [])
          .whereType<Map>()
          .map((group) => Map<String, dynamic>.from(group))
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _runId == null
            ? Column(
                key: const ValueKey('start'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.findMerchantLogos,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(l10n.findMerchantLogosDescription),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _start,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.start),
                  ),
                  if (_error != null) Text(_error!),
                ],
              )
            : Flexible(
                key: const ValueKey('progress'),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(l10n.findMerchantLogos,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _total == 0 ? 1 : _processed / _total,
                    ),
                    const SizedBox(height: 8),
                    Text('$_processed / $_total'),
                    Text('${l10n.resolved}: $_resolved  '
                        '${l10n.needsReview}: $_ambiguous  '
                        '${l10n.skipped}: $_skipped'),
                    if (_quotaExhausted)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l10n.merchantLogoQuotaReached),
                      ),
                    if (_error != null) Text(_error!),
                    for (final group in _groups) ...[
                      const SizedBox(height: 16),
                      Text(group['display_name']?.toString() ?? '',
                          style: Theme.of(context).textTheme.titleMedium),
                      for (final candidate
                          in (group['candidates'] as List? ?? const [])
                              .whereType<Map>())
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox.square(
                            dimension: 40,
                            child: MerchantCandidateLogo(
                              domain: candidate['domain']?.toString() ?? '',
                              fallback: const Icon(Icons.storefront_outlined),
                            ),
                          ),
                          title: Text(candidate['name']?.toString() ?? ''),
                          subtitle: Text(candidate['domain']?.toString() ?? ''),
                          onTap: _loading
                              ? null
                              : () => _select(
                                    group,
                                    Map<String, dynamic>.from(candidate),
                                  ),
                        ),
                      TextButton(
                        onPressed: _loading ? null : () => _skip(group),
                        child: Text(l10n.skip),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading || _remaining == 0 ? null : _continue,
                      child: Text(_quotaExhausted
                          ? l10n.tryAgain
                          : l10n.continueAction),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.close),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
