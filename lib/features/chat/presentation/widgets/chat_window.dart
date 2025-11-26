import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/chat/presentation/state/chat_providers.dart';
import 'package:moneko/features/chat/presentation/widgets/chat_input.dart';
import 'package:moneko/features/chat/presentation/widgets/message_bubble.dart';

class ChatWindow extends ConsumerWidget {
  final String sessionId;

  const ChatWindow({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatMessagesProvider(sessionId));
    final notifier = ref.read(chatMessagesProvider(sessionId).notifier);

    return Column(
      children: [
        Expanded(
          child: chatState.messages.isEmpty && chatState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : chatState.messages.isEmpty
                  ? _buildEmptyState(context)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (!chatState.isLoading &&
                            chatState.hasMore &&
                            scrollInfo.metrics.pixels >=
                                scrollInfo.metrics.maxScrollExtent - 200) {
                          notifier.loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatState.messages.length +
                            (chatState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == chatState.messages.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            );
                          }
                          final message = chatState.messages[index];
                          return MessageBubble(message: message);
                        },
                      ),
                    ),
        ),
        ChatInput(sessionId: sessionId),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
