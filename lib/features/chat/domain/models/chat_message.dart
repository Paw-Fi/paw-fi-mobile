enum ChatRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String sessionId;
  final String content;
  final ChatRole role;
  final DateTime createdAt;
  final List<String>? attachments; // URLs or paths

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.role,
    required this.createdAt,
    this.attachments,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      content: json['content'] as String,
      role: ChatRole.values.firstWhere(
        (e) => e.name == (json['role'] as String).toLowerCase(),
        orElse: () => ChatRole.user,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'content': content,
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
      'attachments': attachments,
    };
  }

  bool get isUser => role == ChatRole.user;
}
