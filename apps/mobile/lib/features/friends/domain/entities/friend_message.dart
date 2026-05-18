class FriendMessage {
  final String id;
  final String senderId;
  final String senderDisplayName;
  final String text;
  final DateTime timestamp;

  const FriendMessage({
    required this.id,
    required this.senderId,
    required this.senderDisplayName,
    required this.text,
    required this.timestamp,
  });
}
