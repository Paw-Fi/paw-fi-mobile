import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/core/l10n/l10n.dart';

void showTextInputDrawer(
  BuildContext parentContext,
  TextEditingController textController,
  Function(String text) onSubmit,
) {
  final colorScheme = shadcnui.Theme.of(parentContext).colorScheme;

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
  final shadcnui.ColorScheme colorScheme;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.pleaseEnterExpenseDetails),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.addExpense,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.colorScheme.foreground,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.colorScheme.foreground),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.describeYourExpense,
              style: TextStyle(
                fontSize: 14,
                color: widget.colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.textController,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.l10n.enterExpenseDetails,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.colorScheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.colorScheme.primary, width: 2),
                ),
              ),
              style: TextStyle(color: widget.colorScheme.foreground),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: shadcnui.PrimaryButton(
                onPressed: _isProcessing ? null : _processExpense,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(context.l10n.addExpense),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
