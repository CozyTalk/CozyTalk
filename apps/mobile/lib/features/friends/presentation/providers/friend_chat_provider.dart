import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/friend_message.dart';
import '../../domain/usecases/send_friend_message.dart';
import '../../domain/usecases/watch_friend_messages.dart';
import 'friends_provider.dart';

final _watchFriendMessagesProvider = Provider<WatchFriendMessages>(
  (ref) => WatchFriendMessages(ref.watch(friendsRepositoryProvider)),
);

final _sendFriendMessageProvider = Provider<SendFriendMessage>(
  (ref) => SendFriendMessage(ref.watch(friendsRepositoryProvider)),
);

final friendChatNotifierProvider =
    NotifierProvider<FriendChatNotifier, FriendChatState>(
      FriendChatNotifier.new,
    );

const _chatSentinel = Object();

class FriendChatState {
  final List<FriendMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? chatRoomId;
  final String? friendDisplayName;
  final String? error;

  const FriendChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.chatRoomId,
    this.friendDisplayName,
    this.error,
  });

  FriendChatState copyWith({
    List<FriendMessage>? messages,
    bool? isLoading,
    bool? isSending,
    Object? chatRoomId = _chatSentinel,
    Object? friendDisplayName = _chatSentinel,
    Object? error = _chatSentinel,
  }) => FriendChatState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    chatRoomId: chatRoomId == _chatSentinel
        ? this.chatRoomId
        : chatRoomId as String?,
    friendDisplayName: friendDisplayName == _chatSentinel
        ? this.friendDisplayName
        : friendDisplayName as String?,
    error: error == _chatSentinel ? this.error : error as String?,
  );
}

class FriendChatNotifier extends Notifier<FriendChatState> {
  StreamSubscription<List<FriendMessage>>? _messagesSub;

  @override
  FriendChatState build() {
    ref.onDispose(() => _messagesSub?.cancel());
    return const FriendChatState();
  }

  Future<void> enterChat(String chatRoomId, String friendDisplayName) async {
    _messagesSub?.cancel();
    state = FriendChatState(
      isLoading: true,
      chatRoomId: chatRoomId,
      friendDisplayName: friendDisplayName,
    );

    _messagesSub = ref
        .read(_watchFriendMessagesProvider)(chatRoomId)
        .listen(
          (messages) =>
              state = state.copyWith(isLoading: false, messages: messages),
          onError: (Object e) => state = state.copyWith(
            isLoading: false,
            error: e.toString().replaceFirst('Exception: ', ''),
          ),
        );
  }

  Future<void> sendMessage(String text) async {
    final chatRoomId = state.chatRoomId;
    if (chatRoomId == null || state.isSending) return;

    final myDisplayName =
        ref.read(authNotifierProvider).user?.displayName ?? 'Anonymous';
    state = state.copyWith(isSending: true, error: null);
    try {
      await ref.read(_sendFriendMessageProvider)(
        chatRoomId: chatRoomId,
        text: text,
        senderDisplayName: myDisplayName,
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void leaveChat() {
    _messagesSub?.cancel();
    _messagesSub = null;
    state = const FriendChatState();
  }
}
