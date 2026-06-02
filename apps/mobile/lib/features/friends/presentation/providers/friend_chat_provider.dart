import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/friend_message.dart';
import '../../domain/usecases/send_friend_message.dart';
import '../../domain/usecases/set_friend_typing.dart';
import '../../domain/usecases/watch_friend_messages.dart';
import '../../domain/usecases/watch_friend_typing.dart';
import 'friends_provider.dart';

final _watchFriendMessagesProvider = Provider<WatchFriendMessages>(
  (ref) => WatchFriendMessages(ref.watch(friendsRepositoryProvider)),
);

final _sendFriendMessageProvider = Provider<SendFriendMessage>(
  (ref) => SendFriendMessage(ref.watch(friendsRepositoryProvider)),
);

final _setFriendTypingProvider = Provider<SetFriendTyping>(
  (ref) => SetFriendTyping(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendTypingProvider = Provider<WatchFriendTyping>(
  (ref) => WatchFriendTyping(ref.watch(friendsRepositoryProvider)),
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
  final bool isPartnerTyping;
  final String? chatRoomId;
  final String? friendDisplayName;
  final String? error;

  const FriendChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isPartnerTyping = false,
    this.chatRoomId,
    this.friendDisplayName,
    this.error,
  });

  FriendChatState copyWith({
    List<FriendMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isPartnerTyping,
    Object? chatRoomId = _chatSentinel,
    Object? friendDisplayName = _chatSentinel,
    Object? error = _chatSentinel,
  }) => FriendChatState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    isPartnerTyping: isPartnerTyping ?? this.isPartnerTyping,
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
  StreamSubscription<bool>? _typingSub;

  @override
  FriendChatState build() {
    ref.onDispose(() {
      _messagesSub?.cancel();
      _typingSub?.cancel();
    });
    return const FriendChatState();
  }

  Future<void> enterChat(String chatRoomId, String friendDisplayName) async {
    _messagesSub?.cancel();
    _typingSub?.cancel();
    state = FriendChatState(
      isLoading: true,
      chatRoomId: chatRoomId,
      friendDisplayName: friendDisplayName,
    );
    // Mark read and track as the active chat so incoming messages stay read.
    ref.read(friendsNotifierProvider.notifier).setActiveChat(chatRoomId);

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

    _typingSub = ref
        .read(_watchFriendTypingProvider)(chatRoomId)
        .listen(
          (isTyping) => state = state.copyWith(isPartnerTyping: isTyping),
          onError: (_) {},
        );
  }

  Future<void> setTyping(bool isTyping) async {
    final chatRoomId = state.chatRoomId;
    if (chatRoomId == null) return;
    try {
      await ref.read(_setFriendTypingProvider)(chatRoomId, isTyping);
    } catch (_) {}
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
      // Clear our own typing indicator after sending.
      setTyping(false);
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void leaveChat() {
    // Clear our typing indicator so partner doesn't see us as typing after we leave.
    setTyping(false);
    // Write the read marker for messages received during the session and drop
    // the active flag.
    ref.read(friendsNotifierProvider.notifier).clearActiveChat();
    _messagesSub?.cancel();
    _typingSub?.cancel();
    _messagesSub = null;
    _typingSub = null;
    // Defer state reset: leaveChat() is called from FriendChatScreen.dispose()
    // which fires during widget unmount. Riverpod forbids synchronous state
    // modification during that phase — schedule it for the next microtask.
    Future.microtask(() => state = const FriendChatState());
  }
}
