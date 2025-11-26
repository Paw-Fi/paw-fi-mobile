import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/chat/data/repositories/chat_repository.dart';
import 'package:moneko/features/chat/domain/models/chat_message.dart';
import 'package:moneko/features/chat/domain/models/chat_session.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getSessions();
});

final currentSessionIdProvider = StateProvider<String?>((ref) => null);

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasMore;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasMore,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final String _sessionId;

  ChatNotifier(this._repository, this._sessionId) : super(ChatState()) {
    _loadInitial();
    _subscribe();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _repository.getMessages(_sessionId, limit: 20);
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final oldestMessage =
          state.messages.last; // List is reversed (newest first)
      final moreMessages = await _repository.getMessages(
        _sessionId,
        limit: 20,
        before: oldestMessage.createdAt,
      );

      state = state.copyWith(
        messages: [...state.messages, ...moreMessages],
        isLoading: false,
        hasMore: moreMessages.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _subscribe() {
    _repository.subscribeToNewMessages(_sessionId).listen((newMessages) {
      if (newMessages.isEmpty) return;

      final newMessage = newMessages.first;

      // Check if we already have this message
      if (state.messages.any((m) => m.id == newMessage.id)) return;

      // Add to list (messages are stored new -> old)
      state = state.copyWith(
        messages: [newMessage, ...state.messages],
      );
    });
  }
}

// Revised approach:
// We will use a StreamProvider for the "live" tail of the chat (e.g. last 50 messages).
// And a FutureProvider for "history".
// OR simpler: Just use the stream. The user said "lazy loading".
// The `.stream()` method in supabase-flutter supports `limit`.
// If we use `.stream(limit: 50)`, we get the last 50.
// To get more, we'd need to increase the limit, but that re-fetches everything.
//
// Better Production Approach:
// 1. Fetch history via REST (pagination).
// 2. Listen for INSERT events via Realtime Channel.
// 3. Merge them.

final chatMessagesProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
        (ref, sessionId) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repository, sessionId);
});
