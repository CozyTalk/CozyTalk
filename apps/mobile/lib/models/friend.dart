class Friend {
  final String name; // friend's original display name (set by them)
  final String username; // their actual account username
  String? note; // nickname you set for this friend (null = not set)
  final String lastMessage;
  final bool isOnline;
  int unreadCount;
  final bool isInRoom;
  final String avatar;
  final String interest;

  Friend({
    required this.name,
    required this.username,
    this.note,
    required this.lastMessage,
    required this.isOnline,
    this.unreadCount = 0,
    required this.isInRoom,
    this.avatar = '',
    this.interest = '',
  });

  Friend copyWith({
    String? name,
    String? username,
    Object? note = _sentinel,
    String? lastMessage,
    bool? isOnline,
    int? unreadCount,
    bool? isInRoom,
    String? avatar,
    String? interest,
  }) => Friend(
    name: name ?? this.name,
    username: username ?? this.username,
    note: note == _sentinel ? this.note : note as String?,
    lastMessage: lastMessage ?? this.lastMessage,
    isOnline: isOnline ?? this.isOnline,
    unreadCount: unreadCount ?? this.unreadCount,
    isInRoom: isInRoom ?? this.isInRoom,
    avatar: avatar ?? this.avatar,
    interest: interest ?? this.interest,
  );

  // ชื่อที่แสดงผล: ถ้าตั้ง note ไว้ใช้ note, ไม่งั้นใช้ username
  String get displayName =>
      (note != null && note!.isNotEmpty) ? note! : username;
}

const _sentinel = Object();

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
