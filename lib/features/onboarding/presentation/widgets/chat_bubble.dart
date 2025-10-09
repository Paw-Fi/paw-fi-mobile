import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: shadcnui.Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: shadcnui.Theme.of(context).colorScheme.primaryForeground,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? shadcnui.Theme.of(context).colorScheme.primary
                        : shadcnui.Theme.of(context).colorScheme.muted,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      topLeft: isUser ? null : const Radius.circular(4),
                      topRight: isUser ? const Radius.circular(4) : null,
                    ),
                  ),
                  child: Text(
                    message,
                    style: shadcnui.Theme.of(context).typography.small.copyWith(
                      color: isUser
                          ? shadcnui.Theme.of(context).colorScheme.primaryForeground
                          : shadcnui.Theme.of(context).colorScheme.foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(timestamp),
                  style: shadcnui.Theme.of(context).typography.textMuted.copyWith(
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            // User avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: shadcnui.Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 18,
                color: shadcnui.Theme.of(context).colorScheme.secondaryForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
