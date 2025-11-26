import 'package:flutter/material.dart';
import 'package:moneko/features/chat/domain/models/chat_message.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? Radius.zero : null,
            bottomLeft: !isUser ? Radius.zero : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachments != null && message.attachments!.isNotEmpty)
              ...message.attachments!.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Image.network(url,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.broken_image)),
                  )),
            MarkdownBlock(
              data: message.content,
              config: MarkdownConfig(
                configs: [
                  PConfig(textStyle: TextStyle(color: textColor)),
                  H1Config(
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  H2Config(
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  H3Config(
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  CodeConfig(
                      style: TextStyle(
                          backgroundColor: Colors.black12,
                          fontFamily: 'monospace',
                          color: textColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
