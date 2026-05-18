enum FriendRequestStatus { pending, accepted, declined }

class FriendRequest {
  final String id;
  final String fromUid;
  final String fromDisplayName;
  final String toUid;
  final String toDisplayName;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.fromDisplayName,
    required this.toUid,
    required this.toDisplayName,
    required this.status,
    required this.createdAt,
  });
}
