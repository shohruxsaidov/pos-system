class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool isError;
  final DateTime createdAt;

  ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == 'user';

  /// Wire format for POST /api/ai/chat — errors never go back to the model.
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
