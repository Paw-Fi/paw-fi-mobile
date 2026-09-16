import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantEntrySheetResult {
  const MerchantEntrySheetResult(this.value);

  final String value;
}

Future<MerchantEntrySheetResult?> showMerchantEntrySheet({
  required BuildContext context,
  required String title,
  required String placeholder,
  required String initialValue,
  required String saveLabel,
  required String cancelLabel,
}) {
  return showModalBottomSheet<MerchantEntrySheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.sheetBackground,
    builder: (sheetContext) => _MerchantEntrySheet(
      title: title,
      placeholder: placeholder,
      initialValue: initialValue,
      saveLabel: saveLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

Future<bool> showAnalyzedMerchantCandidateSheet({
  required BuildContext context,
  required String transactionId,
  required String query,
  required List<Map<String, String>> candidates,
}) async {
  final selected = await showModalBottomSheet<Map<String, String>>(
    context: context,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.sheetBackground,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose merchant',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Optional. Your transaction is already saved.'),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: candidates.length,
              itemBuilder: (_, index) {
                final candidate = candidates[index];
                return ListTile(
                  leading: SizedBox.square(
                    dimension: 36,
                    child: MerchantCandidateLogo(
                      domain: candidate['domain'] ?? '',
                      fallback: const Icon(Icons.storefront_outlined),
                    ),
                  ),
                  title: Text(candidate['name'] ?? ''),
                  subtitle: Text(candidate['domain'] ?? ''),
                  onTap: () => Navigator.of(sheetContext).pop(candidate),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) return false;
  final response = await Supabase.instance.client.functions.invoke(
    'merchant-user-search',
    body: {
      'action': 'select',
      'query': query,
      'transactionId': transactionId,
      'selectedName': selected['name'],
      'selectedDomain': selected['domain'],
      'selectedSource': 'logo_dev',
    },
  );
  return response.data is Map && (response.data as Map)['success'] == true;
}

class _MerchantEntrySheet extends StatefulWidget {
  const _MerchantEntrySheet({
    required this.title,
    required this.placeholder,
    required this.initialValue,
    required this.saveLabel,
    required this.cancelLabel,
  });

  final String title;
  final String placeholder;
  final String initialValue;
  final String saveLabel;
  final String cancelLabel;

  @override
  State<_MerchantEntrySheet> createState() => _MerchantEntrySheetState();
}

class _MerchantEntrySheetState extends State<_MerchantEntrySheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: colorScheme.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(hintText: widget.placeholder),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(widget.saveLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.cancelLabel),
          ),
        ],
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop(
      MerchantEntrySheetResult(_controller.text.trim()),
    );
  }
}
