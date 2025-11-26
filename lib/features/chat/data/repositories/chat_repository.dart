import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/features/chat/domain/models/chat_message.dart';
import 'package:moneko/features/chat/domain/models/chat_session.dart';

class ChatRepository {
  Future<List<ChatSession>> getSessions() async {
    final response = await supabase
        .from('chat_sessions')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((e) => ChatSession.fromJson(e)).toList();
  }

  Future<ChatSession> createSession({String? title}) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await supabase
        .from('chat_sessions')
        .insert({
          'user_id': user.id,
          'title': title ?? 'New Chat',
        })
        .select()
        .single();

    return ChatSession.fromJson(response);
  }

  Future<List<ChatMessage>> getMessages(String sessionId,
      {int limit = 50, DateTime? before}) async {
    var query =
        supabase.from('chat_messages').select().eq('session_id', sessionId);

    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final response =
        await query.order('created_at', ascending: false).limit(limit);
    return (response as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<void> sendMessage({
    required String sessionId,
    required String message,
    List<String> attachments = const [],
    String? language,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Call the Edge Function
    final response = await supabase.functions.invoke(
      'twilio-whatsapp-ai-bot',
      body: {
        'session_id': sessionId,
        'message': message,
        'attachments': attachments,
        'language': language,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to send message: ${response.status}');
    }
  }

  Stream<List<ChatMessage>> subscribeToNewMessages(String sessionId) {
    return supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at', ascending: false)
        .limit(1)
        .map((maps) => maps.map((e) => ChatMessage.fromJson(e)).toList());
  }
}
