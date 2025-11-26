class ChatSession {
  final String id;
  final String userId;
  final DateTime createdAt;
  final String? title;

  ChatSession({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.title,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'title': title,
    };
  }
}
