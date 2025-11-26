import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class BlockingProcessingDialog extends StatelessWidget {
  const BlockingProcessingDialog({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colorScheme.appBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/gifs/loading-anim.gif',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showBlockingProcessingDialog({
  required BuildContext context,
  required String message,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: BlockingProcessingDialog(message: message),
    ),
  );
}
