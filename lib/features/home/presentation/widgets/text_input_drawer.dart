import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary-adaptive-button.dart';

void showTextInputDrawer(
  BuildContext parentContext,
  TextEditingController textController,
  Function(String text) onSubmit,
) {
  final colorScheme = Theme.of(parentContext).colorScheme;

  showModalBottomSheet(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => _TextInputContent(
      parentContext: parentContext,
      textController: textController,
      colorScheme: colorScheme,
      onSubmit: onSubmit,
    ),
  );
}

class _TextInputContent extends ConsumerStatefulWidget {
  final BuildContext parentContext;
  final TextEditingController textController;
  final ColorScheme colorScheme;
  final Function(String text) onSubmit;

  const _TextInputContent({
    required this.parentContext,
    required this.textController,
    required this.colorScheme,
    required this.onSubmit,
  });

  @override
  ConsumerState<_TextInputContent> createState() => _TextInputContentState();
}

class _TextInputContentState extends ConsumerState<_TextInputContent> {
  bool _isProcessing = false;

  Future<void> _processExpense() async {
    final text = widget.textController.text.trim();
    if (text.isEmpty) {
      // Use AppToast to ensure message is visible above the bottom sheet
      AppToast.info(context.l10n.pleaseEnterExpenseDetails);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Close the input modal and trigger the processing in parent
    if (mounted) {
      Navigator.pop(context);
      widget.onSubmit(text);
      // Clear the text field
      widget.textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final String dynamicTitle = context.l10n.addEntry;
    final String placeholder = context.l10n.enterExpenseDetails;

    return Container(
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: bottomInset > 0 ? bottomInset : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    dynamicTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.foreground,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: scheme.mutedForeground),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Guidance text
            Text(
              context.l10n.describeYourExpense,
              style: TextStyle(
                fontSize: 14,
                color: scheme.mutedForeground,
              ),
            ),

            const SizedBox(height: 12),

            // Text area
            TextField(
              controller: widget.textController,
              autofocus: true,
              maxLines: 4,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: scheme.foreground,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: scheme.mutedForeground.withValues(alpha: 0.6),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.foreground),
                ),
              ),
            ),

            const SizedBox(height: 12),

      
            // Submit
            SizedBox(
              width: double.infinity,
              child: PrimaryAdaptiveButton(
                onPressed: _isProcessing ? null : _processExpense,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(dynamicTitle),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
