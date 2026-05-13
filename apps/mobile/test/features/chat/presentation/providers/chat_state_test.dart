import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/session_status.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';

void main() {
  group('ChatState', () {
    test('initial state has idle status and empty collections', () {
      const state = ChatState();
      expect(state.status, SessionStatus.idle);
      expect(state.sessionId, isNull);
      expect(state.currentUserId, isNull);
      expect(state.currentUserDisplayName, isNull);
      expect(state.messages, isEmpty);
      expect(state.typingUsers, isEmpty);
      expect(state.isSending, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates status', () {
      const state = ChatState();
      final updated = state.copyWith(status: SessionStatus.chatting);
      expect(updated.status, SessionStatus.chatting);
    });

    test('copyWith sets sessionId', () {
      const state = ChatState();
      final updated = state.copyWith(sessionId: 'room-1');
      expect(updated.sessionId, 'room-1');
    });

    test('copyWith clears sessionId with explicit null (sentinel)', () {
      final state = ChatState(
        status: SessionStatus.chatting,
        sessionId: 'room-1',
      );
      final cleared = state.copyWith(sessionId: null);
      expect(cleared.sessionId, isNull);
    });

    test('copyWith sets currentUserId', () {
      const state = ChatState();
      final updated = state.copyWith(currentUserId: 'user-1');
      expect(updated.currentUserId, 'user-1');
    });

    test('copyWith clears currentUserId with explicit null (sentinel)', () {
      final state = ChatState(currentUserId: 'user-1');
      final cleared = state.copyWith(currentUserId: null);
      expect(cleared.currentUserId, isNull);
    });

    test('copyWith sets and clears error (sentinel)', () {
      const state = ChatState();
      final withError = state.copyWith(error: 'oops');
      expect(withError.error, 'oops');
      final cleared = withError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith replaces messages list', () {
      final ts = DateTime.now();
      final msgs = [
        ChatMessage(
          id: 'm1',
          senderId: 'u1',
          displayName: 'Alice',
          text: 'hi',
          timestamp: ts,
        ),
      ];
      const state = ChatState();
      final updated = state.copyWith(messages: msgs);
      expect(updated.messages.length, 1);
      expect(updated.messages[0].text, 'hi');
    });

    test('copyWith replaces typingUsers list', () {
      const users = [TypingUser(uid: 'u1', displayName: 'Bob')];
      const state = ChatState();
      final updated = state.copyWith(typingUsers: users);
      expect(updated.typingUsers.length, 1);
    });

    test('copyWith toggles isSending', () {
      const state = ChatState();
      expect(state.copyWith(isSending: true).isSending, isTrue);
      expect(state.copyWith(isSending: false).isSending, isFalse);
    });

    test('copyWith without arguments preserves all fields', () {
      final ts = DateTime.now();
      final msgs = [
        ChatMessage(
          id: 'm1',
          senderId: 'u1',
          displayName: 'Alice',
          text: 'hi',
          timestamp: ts,
        ),
      ];
      final state = ChatState(
        status: SessionStatus.chatting,
        sessionId: 'room-1',
        currentUserId: 'user-1',
        currentUserDisplayName: 'Alice',
        messages: msgs,
        typingUsers: const [TypingUser(uid: 'u2', displayName: 'Bob')],
        isSending: true,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.status, SessionStatus.chatting);
      expect(copy.sessionId, 'room-1');
      expect(copy.currentUserId, 'user-1');
      expect(copy.messages.length, 1);
      expect(copy.typingUsers.length, 1);
      expect(copy.isSending, isTrue);
      expect(copy.error, 'e');
    });
  });
}
