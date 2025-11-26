import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/chat/presentation/state/chat_providers.dart';
import 'package:moneko/features/chat/presentation/widgets/chat_session_list.dart';
import 'package:moneko/features/chat/presentation/widgets/chat_window.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    if (isLargeScreen) {
      return const _ChatPageTablet();
    } else {
      return const _ChatPageMobile();
    }
  }
}

class _ChatPageMobile extends ConsumerWidget {
  const _ChatPageMobile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ChatSessionList(
        onSessionSelected: (sessionId) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatDetailPage(sessionId: sessionId),
            ),
          );
        },
      ),
    );
  }
}

class _ChatPageTablet extends ConsumerWidget {
  const _ChatPageTablet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSessionId = ref.watch(currentSessionIdProvider);

    return Row(
      children: [
        SizedBox(
          width: 300,
          child: ChatSessionList(
            onSessionSelected: (id) {
              ref.read(currentSessionIdProvider.notifier).state = id;
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: currentSessionId == null
              ? const Center(child: Text('Select a chat'))
              : ChatWindow(sessionId: currentSessionId),
        ),
      ],
    );
  }
}

class ChatDetailPage extends StatelessWidget {
  final String sessionId;

  const ChatDetailPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Chat'),
      body: Material(child: ChatWindow(sessionId: sessionId)),
    );
  }
}
