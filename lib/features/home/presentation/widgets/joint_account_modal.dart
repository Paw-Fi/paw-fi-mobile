import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

void showJointAccountModal(BuildContext context, shadcnui.ColorScheme colorScheme) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with emoji
            Row(
              children: [
                Text('💡', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Joint Accounts Coming Soon!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            Text(
              'In the next phase, you\'ll be able to invite your family, partner, or friends to create a shared budget and manage money together — all in one place.',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stay tuned, it\'s going to make teamwork with finances effortless!',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),

            const SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: shadcnui.PrimaryButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
