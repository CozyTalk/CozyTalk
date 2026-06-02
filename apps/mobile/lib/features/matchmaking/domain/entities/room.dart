enum RoomType { public, custom }

enum RoomMode { oneToOne, group }

enum RoomStatus { active, padding, expired }

class Room {
  final String roomId;
  final RoomType roomType;
  final RoomMode mode;
  final RoomStatus status;
  final int maxUsers;
  final int memberCount;
  final List<String> users;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime? paddingUntil;
  final List<double>? roomInterestVector;
  final String? backgroundTheme;

  const Room({
    required this.roomId,
    required this.roomType,
    required this.mode,
    required this.status,
    required this.maxUsers,
    required this.memberCount,
    required this.users,
    required this.isLocked,
    required this.createdAt,
    this.paddingUntil,
    this.roomInterestVector,
    this.backgroundTheme,
  });

  Room copyWith({bool? isLocked}) => Room(
    roomId: roomId,
    roomType: roomType,
    mode: mode,
    status: status,
    maxUsers: maxUsers,
    memberCount: memberCount,
    users: users,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    paddingUntil: paddingUntil,
    roomInterestVector: roomInterestVector,
    backgroundTheme: backgroundTheme,
  );
}
