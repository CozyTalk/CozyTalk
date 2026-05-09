class ChatMessage {
  final String id;
  final String senderId;
  final String displayName;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.displayName,
    required this.text,
    required this.timestamp,
  });
}
