import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/datasources/friends_datasource.dart';
import '../../data/repositories/friends_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_room_status.dart';
import '../../domain/repositories/friends_repository.dart';
import '../../domain/usecases/accept_friend_request.dart';
import '../../domain/usecases/decline_friend_request.dart';
import '../../domain/usecases/get_unread_message_count.dart';
import '../../domain/usecases/get_users_by_ids.dart';
import '../../domain/usecases/remove_friend.dart';
import '../../domain/usecases/send_friend_request.dart';
import '../../domain/usecases/set_chat_read.dart';
import '../../domain/usecases/watch_all_users.dart';
import '../../domain/usecases/watch_chat_read.dart';
import '../../domain/usecases/watch_friend_last_message.dart';
import '../../domain/usecases/watch_friend_presence.dart';
import '../../domain/usecases/watch_friend_room.dart';
import '../../domain/usecases/watch_friends.dart';
import '../../domain/usecases/watch_incoming_requests.dart';

final friendsDatasourceProvider = Provider<FriendsDatasource>(
  (ref) => FriendsDatasourceImpl(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    FirebaseDatabase.instance,
  ),
);

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepositoryImpl(ref.watch(friendsDatasourceProvider)),
);

final _watchAllUsersProvider = Provider<WatchAllUsers>(
  (ref) => WatchAllUsers(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendsProvider = Provider<WatchFriends>(
  (ref) => WatchFriends(ref.watch(friendsRepositoryProvider)),
);

final _watchIncomingRequestsProvider = Provider<WatchIncomingRequests>(
  (ref) => WatchIncomingRequests(ref.watch(friendsRepositoryProvider)),
);

final _sendFriendRequestProvider = Provider<SendFriendRequest>(
  (ref) => SendFriendRequest(ref.watch(friendsRepositoryProvider)),
);

final _acceptFriendRequestProvider = Provider<AcceptFriendRequest>(
  (ref) => AcceptFriendRequest(ref.watch(friendsRepositoryProvider)),
);

final _declineFriendRequestProvider = Provider<DeclineFriendRequest>(
  (ref) => DeclineFriendRequest(ref.watch(friendsRepositoryProvider)),
);

final _removeFriendProvider = Provider<RemoveFriend>(
  (ref) => RemoveFriend(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendPresenceProvider = Provider<WatchFriendPresence>(
  (ref) => WatchFriendPresence(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendLastMessageProvider = Provider<WatchFriendLastMessage>(
  (ref) => WatchFriendLastMessage(ref.watch(friendsRepositoryProvider)),
);

final _getUnreadMessageCountProvider = Provider<GetUnreadMessageCount>(
  (ref) => GetUnreadMessageCount(ref.watch(friendsRepositoryProvider)),
);

final _setChatReadProvider = Provider<SetChatRead>(
  (ref) => SetChatRead(ref.watch(friendsRepositoryProvider)),
);

final _watchChatReadProvider = Provider<WatchChatRead>(
  (ref) => WatchChatRead(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendRoomProvider = Provider<WatchFriendRoom>(
  (ref) => WatchFriendRoom(ref.watch(friendsRepositoryProvider)),
);

final friendsNotifierProvider = NotifierProvider<FriendsNotifier, FriendsState>(
  FriendsNotifier.new,
);

/// Family argument is a **sorted comma-joined UID string** so that the same
/// set of UIDs always maps to the same cache entry regardless of list identity.
/// Callers: sort uids and join with ',' before passing.
final getUsersByIdsProvider = FutureProvider.autoDispose
    .family<List<AppUser>, String>((ref, uidsCsv) {
      if (uidsCsv.isEmpty) return Future.value([]);
      return GetUsersByIds(ref.watch(friendsRepositoryProvider))(
        uidsCsv.split(','),
      );
    });

const _sentinel = Object();

class FriendsState {
  final List<AppUser> allUsers;
  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final bool isLoading;
  final String? error;
  // keyed by friendUid
  final Map<String, bool> presenceMap;
  // keyed by chatRoomId
  final Map<String, String> lastMessageMap;
  // keyed by chatRoomId — timestamp of the most recent message
  final Map<String, DateTime?> lastMessageTimestampMap;
  // keyed by friendUid
  final Map<String, FriendRoomStatus?> roomMap;
  // keyed by chatRoomId — count of unread messages from the friend (not self)
  final Map<String, int> unreadCountMap;

  const FriendsState({
    this.allUsers = const [],
    this.friends = const [],
    this.incomingRequests = const [],
    this.isLoading = false,
    this.error,
    this.presenceMap = const {},
    this.lastMessageMap = const {},
    this.lastMessageTimestampMap = const {},
    this.roomMap = const {},
    this.unreadCountMap = const {},
  });

  FriendsState copyWith({
    List<AppUser>? allUsers,
    List<Friend>? friends,
    List<FriendRequest>? incomingRequests,
    bool? isLoading,
    Object? error = _sentinel,
    Map<String, bool>? presenceMap,
    Map<String, String>? lastMessageMap,
    Map<String, DateTime?>? lastMessageTimestampMap,
    Map<String, FriendRoomStatus?>? roomMap,
    Map<String, int>? unreadCountMap,
  }) => FriendsState(
    allUsers: allUsers ?? this.allUsers,
    friends: friends ?? this.friends,
    incomingRequests: incomingRequests ?? this.incomingRequests,
    isLoading: isLoading ?? this.isLoading,
    error: error == _sentinel ? this.error : error as String?,
    presenceMap: presenceMap ?? this.presenceMap,
    lastMessageMap: lastMessageMap ?? this.lastMessageMap,
    lastMessageTimestampMap:
        lastMessageTimestampMap ?? this.lastMessageTimestampMap,
    roomMap: roomMap ?? this.roomMap,
    unreadCountMap: unreadCountMap ?? this.unreadCountMap,
  );
}

class FriendsNotifier extends Notifier<FriendsState> {
  StreamSubscription<List<Friend>>? _friendsSub;
  StreamSubscription<List<FriendRequest>>? _requestsSub;
  StreamSubscription<List<AppUser>>? _usersSub;

  final Map<String, StreamSubscription<bool>> _presenceSubs = {};
  final Map<
    String,
    StreamSubscription<({String text, DateTime? timestamp, String senderId})>
  >
  _lastMessageSubs = {};
  final Map<String, StreamSubscription<FriendRoomStatus?>> _roomSubs = {};
  // Per-room subscription to the server-side read marker (reads/{uid}.lastReadAt).
  final Map<String, StreamSubscription<DateTime?>> _readSubs = {};
  // Latest read marker per room, fed by _readSubs; drives unread recompute.
  final Map<String, DateTime?> _lastReadMap = {};
  // Tracks chatRoomIds whose first lastMessage emission has been processed.
  final Set<String> _initializedRooms = {};

  // chatRoomId the user is currently viewing; messages arriving in it are read.
  String? _activeChatRoomId;

  bool _disposed = false;

  @override
  FriendsState build() {
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
      _friendsSub?.cancel();
      _requestsSub?.cancel();
      _usersSub?.cancel();
      for (final sub in _presenceSubs.values) {
        sub.cancel();
      }
      for (final sub in _lastMessageSubs.values) {
        sub.cancel();
      }
      for (final sub in _readSubs.values) {
        sub.cancel();
      }
      for (final sub in _roomSubs.values) {
        sub.cancel();
      }
    });

    _friendsSub = ref.read(_watchFriendsProvider)().listen(
      (friends) {
        state = state.copyWith(friends: friends);
        _updateEnrichmentSubscriptions(friends);
      },
      onError: (Object e) => state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      ),
    );

    _requestsSub = ref
        .read(_watchIncomingRequestsProvider)()
        .listen(
          (requests) => state = state.copyWith(incomingRequests: requests),
          onError: (Object e) => state = state.copyWith(
            error: e.toString().replaceFirst('Exception: ', ''),
          ),
        );

    _usersSub = ref
        .read(_watchAllUsersProvider)()
        .listen(
          (users) => state = state.copyWith(allUsers: users),
          onError: (Object e) => state = state.copyWith(
            error: e.toString().replaceFirst('Exception: ', ''),
          ),
        );

    return const FriendsState();
  }

  void _updateEnrichmentSubscriptions(List<Friend> friends) {
    final currentUids = {for (final f in friends) f.friendUid};
    final currentRoomIds = {for (final f in friends) f.chatRoomId};

    final removedUids = _presenceSubs.keys.toSet().difference(currentUids);
    for (final uid in removedUids) {
      _presenceSubs.remove(uid)?.cancel();
      _roomSubs.remove(uid)?.cancel();
    }

    final removedRoomIds = _lastMessageSubs.keys.toSet().difference(
      currentRoomIds,
    );
    for (final roomId in removedRoomIds) {
      _lastMessageSubs.remove(roomId)?.cancel();
      _readSubs.remove(roomId)?.cancel();
      _lastReadMap.remove(roomId);
    }

    if (removedUids.isNotEmpty || removedRoomIds.isNotEmpty) {
      final newPresence = Map<String, bool>.from(state.presenceMap)
        ..removeWhere((k, _) => removedUids.contains(k));
      final newRoom = Map<String, FriendRoomStatus?>.from(state.roomMap)
        ..removeWhere((k, _) => removedUids.contains(k));
      final newLastMsg = Map<String, String>.from(state.lastMessageMap)
        ..removeWhere((k, _) => removedRoomIds.contains(k));
      final newLastMsgTs = Map<String, DateTime?>.from(
        state.lastMessageTimestampMap,
      )..removeWhere((k, _) => removedRoomIds.contains(k));
      final newUnread = Map<String, int>.from(state.unreadCountMap)
        ..removeWhere((k, _) => removedRoomIds.contains(k));
      state = state.copyWith(
        presenceMap: newPresence,
        roomMap: newRoom,
        lastMessageMap: newLastMsg,
        lastMessageTimestampMap: newLastMsgTs,
        unreadCountMap: newUnread,
      );
    }

    for (final f in friends) {
      if (!_presenceSubs.containsKey(f.friendUid)) {
        _presenceSubs[f.friendUid] = ref
            .read(_watchFriendPresenceProvider)(f.friendUid)
            .listen((isOnline) {
              state = state.copyWith(
                presenceMap: Map<String, bool>.from(state.presenceMap)
                  ..[f.friendUid] = isOnline,
              );
            }, onError: (_) {});
      }

      if (!_lastMessageSubs.containsKey(f.chatRoomId)) {
        // Authoritative unread count: recompute whenever the server-side read
        // marker changes — initial load, this device marking read, or another
        // device marking read (cross-device sync).
        _readSubs[f.chatRoomId] = ref
            .read(_watchChatReadProvider)(f.chatRoomId)
            .listen((lastRead) {
              _lastReadMap[f.chatRoomId] = lastRead;
              _recomputeUnread(f.chatRoomId, f.friendUid);
            }, onError: (_) {});

        _lastMessageSubs[f.chatRoomId] = ref
            .read(_watchFriendLastMessageProvider)(f.chatRoomId)
            .listen((event) {
              final isSubsequent = _initializedRooms.contains(f.chatRoomId);
              _initializedRooms.add(f.chatRoomId);
              final newLastMsg = Map<String, String>.from(state.lastMessageMap)
                ..[f.chatRoomId] = event.text;
              final newLastMsgTs = Map<String, DateTime?>.from(
                state.lastMessageTimestampMap,
              )..[f.chatRoomId] = event.timestamp;
              final currentUid = ref.read(friendsDatasourceProvider).currentUid;
              final fromFriend =
                  event.text.isNotEmpty &&
                  event.senderId.isNotEmpty &&
                  event.senderId != currentUid;

              // Only count new in-session messages (subsequent stream events).
              // Startup count is handled by the Firestore query above.
              // Skip the chat the user is currently viewing: messages arriving
              // while it's open are read immediately, so they must not bump the
              // badge. leaveChat() persists the read marker on exit.
              if (isSubsequent &&
                  fromFriend &&
                  f.chatRoomId != _activeChatRoomId) {
                final newCount = (state.unreadCountMap[f.chatRoomId] ?? 0) + 1;
                state = state.copyWith(
                  lastMessageMap: newLastMsg,
                  lastMessageTimestampMap: newLastMsgTs,
                  unreadCountMap: Map<String, int>.from(state.unreadCountMap)
                    ..[f.chatRoomId] = newCount,
                );
              } else {
                state = state.copyWith(
                  lastMessageMap: newLastMsg,
                  lastMessageTimestampMap: newLastMsgTs,
                );
              }
            }, onError: (_) {});
      }

      if (!_roomSubs.containsKey(f.friendUid)) {
        _roomSubs[f.friendUid] = ref
            .read(_watchFriendRoomProvider)(f.friendUid)
            .listen((room) {
              state = state.copyWith(
                roomMap: Map<String, FriendRoomStatus?>.from(state.roomMap)
                  ..[f.friendUid] = room,
              );
            }, onError: (_) {});
      }
    }
  }

  // Counts friend messages newer than the read marker. The marker (server
  // timestamp) and message timestamps share the server clock, so there is no
  // client skew at the boundary. sinceMs = 0 when no marker exists yet (counts
  // the trailing run of the friend's messages — see getUnreadMessageCount).
  void _recomputeUnread(String chatRoomId, String friendUid) {
    ref
        .read(_getUnreadMessageCountProvider)(
          chatRoomId,
          sinceMs: _lastReadMap[chatRoomId]?.millisecondsSinceEpoch ?? 0,
          friendUid: friendUid,
        )
        .then((n) {
          if (_disposed) return;
          if ((state.unreadCountMap[chatRoomId] ?? 0) != n) {
            state = state.copyWith(
              unreadCountMap: Map<String, int>.from(state.unreadCountMap)
                ..[chatRoomId] = n,
            );
          }
        })
        .catchError((_) {});
  }

  Future<void> sendFriendRequest(AppUser toUser) async {
    if (state.isLoading) return;
    final authUser = ref.read(authNotifierProvider).user;
    if (authUser?.email == null) {
      state = state.copyWith(
        error: 'Please sign in with an account to add friends.',
      );
      return;
    }
    final profileName = ref
        .read(profileNotifierProvider)
        .profile
        ?.displayName
        ?.trim();
    final authName = authUser?.displayName?.trim();
    final myDisplayName = (profileName?.isNotEmpty ?? false)
        ? profileName!
        : (authName?.isNotEmpty ?? false)
        ? authName!
        : 'Anonymous';
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_sendFriendRequestProvider)(
        toUid: toUser.uid,
        toDisplayName: toUser.displayName,
        fromDisplayName: myDisplayName,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> acceptRequest(FriendRequest request) async {
    if (state.isLoading) return;
    final myDisplayName =
        ref.read(authNotifierProvider).user?.displayName ?? 'Anonymous';
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_acceptFriendRequestProvider)(
        requestId: request.id,
        fromUid: request.fromUid,
        fromDisplayName: request.fromDisplayName,
        myDisplayName: myDisplayName,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> declineRequest(String requestId) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_declineFriendRequestProvider)(requestId: requestId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> removeFriend(String friendshipId) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_removeFriendProvider)(friendshipId: friendshipId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearError() => state = state.copyWith(error: null);

  // Called when the user opens a chat. Tracks it as active so messages arriving
  // while it's open don't bump the badge, and writes the read marker.
  void setActiveChat(String chatRoomId) {
    _activeChatRoomId = chatRoomId;
    markChatRead(chatRoomId);
  }

  // Called when the user leaves the chat. Writes the read marker again so
  // messages received during the session count as read, then drops the flag.
  void clearActiveChat() {
    final id = _activeChatRoomId;
    _activeChatRoomId = null;
    if (id != null) markChatRead(id);
  }

  // Optimistic, in-memory clear only. Used on a friend-card tap before the chat
  // screen mounts; the chat screen's setActiveChat writes the marker.
  void clearBadgeLocally(String chatRoomId) => _clearBadge(chatRoomId);

  // Writes a server-authoritative read marker (reads/{uid}.lastReadAt via
  // serverTimestamp) and clears the badge optimistically. watchChatRead echoes
  // the new marker back, which recomputes the exact count cross-device.
  void markChatRead(String chatRoomId) {
    _clearBadge(chatRoomId);
    ref.read(_setChatReadProvider)(chatRoomId).catchError((_) {});
  }

  void _clearBadge(String chatRoomId) {
    if ((state.unreadCountMap[chatRoomId] ?? 0) != 0) {
      state = state.copyWith(
        unreadCountMap: Map<String, int>.from(state.unreadCountMap)
          ..[chatRoomId] = 0,
      );
    }
  }
}
