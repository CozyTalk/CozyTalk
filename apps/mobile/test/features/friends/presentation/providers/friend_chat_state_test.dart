import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_message.dart';
import 'package:mobile/features/friends/presentation/providers/friend_chat_provider.dart';

void main() {
  group('FriendChatState', () {
    test('initial state has empty messages, no active chat, no loading', () {
      const state = FriendChatState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isSending, isFalse);
      expect(state.chatRoomId, isNull);
      expect(state.friendDisplayName, isNull);
      expect(state.error, isNull);
    });

    test('copyWith sets chatRoomId', () {
      const state = FriendChatState();
      final updated = state.copyWith(chatRoomId: 'room-1');
      expect(updated.chatRoomId, 'room-1');
      expect(updated.friendDisplayName, isNull);
    });

    test('copyWith clears chatRoomId with explicit null (sentinel)', () {
      const state = FriendChatState(chatRoomId: 'room-1');
      final cleared = state.copyWith(chatRoomId: null);
      expect(cleared.chatRoomId, isNull);
    });

    test(
      'copyWith without chatRoomId argument preserves existing value (sentinel)',
      () {
        const state = FriendChatState(chatRoomId: 'room-kept');
        final copy = state.copyWith(isLoading: true);
        expect(copy.chatRoomId, 'room-kept');
      },
    );

    test('copyWith sets friendDisplayName', () {
      const state = FriendChatState();
      final updated = state.copyWith(friendDisplayName: 'Alice');
      expect(updated.friendDisplayName, 'Alice');
    });

    test('copyWith clears friendDisplayName with explicit null (sentinel)', () {
      const state = FriendChatState(friendDisplayName: 'Alice');
      final cleared = state.copyWith(friendDisplayName: null);
      expect(cleared.friendDisplayName, isNull);
    });

    test('copyWith sets error and clears with null', () {
      const state = FriendChatState();
      final withError = state.copyWith(error: 'send failed');
      expect(withError.error, 'send failed');

      final cleared = withError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test(
      'copyWith without error argument preserves existing error (sentinel)',
      () {
        const state = FriendChatState(error: 'kept error');
        final copy = state.copyWith(isSending: true);
        expect(copy.error, 'kept error');
      },
    );

    test('copyWith replaces messages list', () {
      final msg = FriendMessage(
        id: 'm1',
        senderId: 'u1',
        senderDisplayName: 'Alice',
        text: 'hello',
        timestamp: DateTime(2024),
      );
      const state = FriendChatState();
      final updated = state.copyWith(messages: [msg]);
      expect(updated.messages, hasLength(1));
      expect(updated.messages[0].text, 'hello');
    });

    test('copyWith toggles isLoading', () {
      const state = FriendChatState();
      expect(state.copyWith(isLoading: true).isLoading, isTrue);
      expect(
        state.copyWith(isLoading: true).copyWith(isLoading: false).isLoading,
        isFalse,
      );
    });

    test('copyWith toggles isSending', () {
      const state = FriendChatState();
      expect(state.copyWith(isSending: true).isSending, isTrue);
      expect(state.copyWith(isSending: false).isSending, isFalse);
    });

    test('copyWith without arguments preserves all fields', () {
      final msg = FriendMessage(
        id: 'm2',
        senderId: 'u2',
        senderDisplayName: 'Bob',
        text: 'hi',
        timestamp: DateTime(2024),
      );
      final state = FriendChatState(
        messages: [msg],
        isLoading: true,
        isSending: true,
        chatRoomId: 'room-2',
        friendDisplayName: 'Bob',
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.messages, hasLength(1));
      expect(copy.isLoading, isTrue);
      expect(copy.isSending, isTrue);
      expect(copy.chatRoomId, 'room-2');
      expect(copy.friendDisplayName, 'Bob');
      expect(copy.error, 'e');
    });
  });
}
