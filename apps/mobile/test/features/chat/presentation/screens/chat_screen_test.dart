import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/session_status.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:mobile/features/chat/presentation/screens/chat_screen.dart';
import 'package:mobile/features/jukebox/presentation/providers/jukebox_provider.dart';

class _FakeChatNotifier extends ChatNotifier {
  final ChatState _initial;
  int sendMessageCount = 0;
  String? lastSentText;
  int endSessionCount = 0;
  int setTypingCount = 0;
  bool? lastIsTyping;

  _FakeChatNotifier({ChatState initial = const ChatState()})
    : _initial = initial;

  @override
  ChatState build() => _initial;

  @override
  void enterSession({
    required String sessionId,
    required String currentUserId,
    String? currentUserDisplayName,
    String? currentUserPhotoUrl,
  }) {}

  @override
  Future<void> sendMessage(String text) async {
    sendMessageCount++;
    lastSentText = text;
  }

  @override
  Future<void> setTyping(bool isTyping) async {
    setTypingCount++;
    lastIsTyping = isTyping;
  }

  @override
  Future<void> endSession() async => endSessionCount++;
}

class _FakeJukeboxNotifier extends JukeboxNotifier {
  @override
  JukeboxUiState build() => const JukeboxUiState();
  @override
  void enterRoom(String roomId) {}
}

Widget _buildChatScreen(_FakeChatNotifier fake) {
  return ProviderScope(
    overrides: [
      chatNotifierProvider.overrideWith(() => fake),
      jukeboxNotifierProvider.overrideWith(() => _FakeJukeboxNotifier()),
    ],
    child: const MaterialApp(
      home: ChatScreen(
        sessionId: 'test-session',
        currentUserId: 'user-1',
        currentUserDisplayName: 'Alice',
      ),
    ),
  );
}

void main() {
  group('ChatScreen', () {
    testWidgets('shows "Say hello!" placeholder when messages list is empty', (
      tester,
    ) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      expect(find.text('Say hello!'), findsOneWidget);
    });

    testWidgets('renders message bubbles when messages are present', (
      tester,
    ) async {
      final ts = DateTime.now();
      final fake = _FakeChatNotifier(
        initial: ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
          messages: [
            ChatMessage(
              id: 'm1',
              senderId: 'user-1',
              displayName: 'Alice',
              text: 'hello there',
              timestamp: ts,
            ),
            ChatMessage(
              id: 'm2',
              senderId: 'user-2',
              displayName: 'Bob',
              text: 'hey!',
              timestamp: ts,
            ),
          ],
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      expect(find.text('hello there'), findsOneWidget);
      expect(find.text('hey!'), findsOneWidget);
    });

    testWidgets('shows disconnected screen when status is disconnected', (
      tester,
    ) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(status: SessionStatus.disconnected),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      expect(find.text('Session ended'), findsOneWidget);
      expect(find.text('The conversation has ended.'), findsOneWidget);
    });

    testWidgets('shows typing indicator when other users are typing', (
      tester,
    ) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
          typingUsers: [TypingUser(uid: 'user-2', displayName: 'Bob')],
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));
      await tester.pump();

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(CircleAvatar).first),
        isNot(throwsA(anything)),
      );
    });

    testWidgets('typing indicator shows accessible label for typing user', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final fake = _FakeChatNotifier(
          initial: const ChatState(
            status: SessionStatus.chatting,
            sessionId: 'test-session',
            currentUserId: 'user-1',
            typingUsers: [TypingUser(uid: 'user-2', displayName: 'Bob')],
          ),
        );
        await tester.pumpWidget(_buildChatScreen(fake));
        await tester.pump();

        expect(find.bySemanticsLabel('Bob is typing…'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('typing indicator hidden when no one is typing', (
      tester,
    ) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('tapping send with text calls sendMessage', (tester) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      await tester.enterText(find.byType(TextField), 'test message');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(fake.sendMessageCount, 1);
      expect(fake.lastSentText, 'test message');
    });

    testWidgets('tapping send with empty text does not call sendMessage', (
      tester,
    ) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(fake.sendMessageCount, 0);
    });

    testWidgets('shows error message from state.error', (tester) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
          error: 'Could not send message.',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      expect(find.text('Could not send message.'), findsOneWidget);
    });

    testWidgets('shows send spinner when isSending is true', (tester) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
          isSending: true,
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('typing indicator shows several-people label for 3+ users', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final fake = _FakeChatNotifier(
          initial: const ChatState(
            status: SessionStatus.chatting,
            sessionId: 'test-session',
            currentUserId: 'user-1',
            typingUsers: [
              TypingUser(uid: 'u2', displayName: 'Alice'),
              TypingUser(uid: 'u3', displayName: 'Bob'),
              TypingUser(uid: 'u4', displayName: 'Carol'),
            ],
          ),
        );
        await tester.pumpWidget(_buildChatScreen(fake));
        await tester.pump();

        expect(
          find.bySemanticsLabel('Several people are typing…'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('typing indicator shows two names in accessibility label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final fake = _FakeChatNotifier(
          initial: const ChatState(
            status: SessionStatus.chatting,
            sessionId: 'test-session',
            currentUserId: 'user-1',
            typingUsers: [
              TypingUser(uid: 'u2', displayName: 'Bob'),
              TypingUser(uid: 'u3', displayName: 'Carol'),
            ],
          ),
        );
        await tester.pumpWidget(_buildChatScreen(fake));
        await tester.pump();

        expect(
          find.bySemanticsLabel('Bob and Carol are typing…'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('entering text calls setTyping(true)', (tester) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(fake.setTypingCount, greaterThan(0));
      expect(fake.lastIsTyping, isTrue);
    });

    testWidgets('clearing text calls setTyping(false)', (tester) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(fake.lastIsTyping, isFalse);
    });

    testWidgets('sending a message calls setTyping(false)', (tester) async {
      final fake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 'test-session',
          currentUserId: 'user-1',
        ),
      );
      await tester.pumpWidget(_buildChatScreen(fake));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(fake.lastIsTyping, isFalse);
      expect(fake.sendMessageCount, 1);
    });
  });
}
