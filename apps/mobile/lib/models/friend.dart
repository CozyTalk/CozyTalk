class Friend {
  String name;
  final String username;
  final String lastMessage;
  final bool isOnline;
  int unreadCount;
  final bool isInRoom;
  final String avatar;
  final String interest;

  Friend({
    required this.name,
    required this.username,
    required this.lastMessage,
    required this.isOnline,
    required this.unreadCount,
    required this.isInRoom,
    this.avatar = '',
    this.interest = '',
  });
}

class ChatMessage {
  final String text;
  final bool isMe;
  final String time;

  const ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });
}
