import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/friends_datasource.dart';
import '../../data/repositories/friends_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/repositories/friends_repository.dart';
import '../../domain/usecases/accept_friend_request.dart';
import '../../domain/usecases/decline_friend_request.dart';
import '../../domain/usecases/remove_friend.dart';
import '../../domain/usecases/send_friend_request.dart';
import '../../domain/usecases/watch_all_users.dart';
import '../../domain/usecases/watch_friends.dart';
import '../../domain/usecases/watch_incoming_requests.dart';

final friendsDatasourceProvider = Provider<FriendsDatasource>(
  (ref) =>
      FriendsDatasourceImpl(FirebaseFirestore.instance, FirebaseAuth.instance),
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

final friendsNotifierProvider = NotifierProvider<FriendsNotifier, FriendsState>(
  FriendsNotifier.new,
);

const _sentinel = Object();

class FriendsState {
  final List<AppUser> allUsers;
  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final bool isLoading;
  final String? error;

  const FriendsState({
    this.allUsers = const [],
    this.friends = const [],
    this.incomingRequests = const [],
    this.isLoading = false,
    this.error,
  });

  FriendsState copyWith({
    List<AppUser>? allUsers,
    List<Friend>? friends,
    List<FriendRequest>? incomingRequests,
    bool? isLoading,
    Object? error = _sentinel,
  }) => FriendsState(
    allUsers: allUsers ?? this.allUsers,
    friends: friends ?? this.friends,
    incomingRequests: incomingRequests ?? this.incomingRequests,
    isLoading: isLoading ?? this.isLoading,
    error: error == _sentinel ? this.error : error as String?,
  );
}

class FriendsNotifier extends Notifier<FriendsState> {
  StreamSubscription<List<Friend>>? _friendsSub;
  StreamSubscription<List<FriendRequest>>? _requestsSub;
  StreamSubscription<List<AppUser>>? _usersSub;

  @override
  FriendsState build() {
    ref.onDispose(() {
      _friendsSub?.cancel();
      _requestsSub?.cancel();
      _usersSub?.cancel();
    });

    _friendsSub = ref
        .read(_watchFriendsProvider)()
        .listen(
          (friends) => state = state.copyWith(friends: friends),
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

  Future<void> sendFriendRequest(AppUser toUser) async {
    if (state.isLoading) return;
    final myDisplayName =
        ref.read(authNotifierProvider).user?.displayName ?? 'Anonymous';
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
}
