enum UserOnlineStatus { online, inRoom, offline }

class UserStatus {
  final String uid;
  final UserOnlineStatus status;
  final String? roomId;
  final String? roomMode;

  const UserStatus({
    required this.uid,
    required this.status,
    this.roomId,
    this.roomMode,
  });
}
