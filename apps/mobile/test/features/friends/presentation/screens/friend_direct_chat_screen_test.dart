import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend_message.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friend_chat_provider.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/screens/friend_direct_chat_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;
  @override
  AuthState build() => _initial;
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}
}

class _FakeFriendsNotifier extends FriendsNotifier {
  int removeFriendCount = 0;
  String? lastRemovedFriendshipId;
  final FriendsState _initial;

  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {}

  @override
  Future<void> acceptRequest(FriendRequest request) async {}

  @override
  Future<void> declineRequest(FriendRequest request) async {}

  @override
  @override
  Future<void> removeFriend(String friendshipId) async {
    removeFriendCount++;
    lastRemovedFriendshipId = friendshipId;
  }

  @override
  void clearError() {}
}

class _FakeFriendChatNotifier extends FriendChatNotifier {
  int enterChatCount = 0;
  String? lastChatRoomId;
  String? lastFriendDisplayName;
  int sendMessageCount = 0;
  String? lastMessageText;
  int leaveChatCount = 0;
  final FriendChatState _initial;

  _FakeFriendChatNotifier({FriendChatState initial = const FriendChatState()})
    : _initial = initial;

  @override
  FriendChatState build() => _initial;

  @override
  Future<void> enterChat(String chatRoomId, String friendDisplayName) async {
    enterChatCount++;
    lastChatRoomId = chatRoomId;
    lastFriendDisplayName = friendDisplayName;
  }

  @override
  Future<void> sendMessage(String text) async {
    sendMessageCount++;
    lastMessageText = text;
  }

  @override
  void leaveChat() => leaveChatCount++;
}

Widget _buildScreen(
  _FakeFriendChatNotifier chatFake, {
  _FakeAuthNotifier? authFake,
  _FakeFriendsNotifier? friendsFake,
  String chatRoomId = 'room-1',
  String friendDisplayName = 'Alice',
  String friendshipId = 'f1',
}) {
  final auth =
      authFake ??
      _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'current-uid', displayName: 'Me'),
        ),
      );
  final friends = friendsFake ?? _FakeFriendsNotifier();
  return ProviderScope(
    overrides: [
      friendChatNotifierProvider.overrideWith(() => chatFake),
      authNotifierProvider.overrideWith(() => auth),
      friendsNotifierProvider.overrideWith(() => friends),
    ],
    child: MaterialApp(
      home: FriendDirectChatScreen(
        chatRoomId: chatRoomId,
        friendDisplayName: friendDisplayName,
        friendshipId: friendshipId,
      ),
    ),
  );
}

void main() {
  group('FriendDirectChatScreen', () {
    testWidgets('renders friend display name in app bar', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friendDisplayName: 'Bob'));
      final appBarTitle = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Bob'),
      );
      expect(appBarTitle, findsOneWidget);
    });

    testWidgets('calls enterChat with chatRoomId and friendDisplayName', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(
        _buildScreen(fake, chatRoomId: 'room-42', friendDisplayName: 'Alice'),
      );
      await tester.pump(); // trigger addPostFrameCallback
      expect(fake.enterChatCount, 1);
      expect(fake.lastChatRoomId, 'room-42');
      expect(fake.lastFriendDisplayName, 'Alice');
    });

    testWidgets('shows empty state when no messages and not loading', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('No messages yet. Say hello!'), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator when isLoading', (tester) async {
      final fake = _FakeFriendChatNotifier(
        initial: const FriendChatState(isLoading: true),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders message text in chat', (tester) async {
      final msg = FriendMessage(
        id: 'm1',
        senderId: 'u2',
        senderDisplayName: 'Alice',
        text: 'Hello there!',
        timestamp: DateTime(2024),
      );
      final fake = _FakeFriendChatNotifier(
        initial: FriendChatState(messages: [msg]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Hello there!'), findsOneWidget);
    });

    testWidgets('send button shows CircularProgressIndicator when isSending', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier(
        initial: const FriendChatState(isSending: true),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('tapping send button calls sendMessage with typed text', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake));
      await tester.enterText(find.byType(TextField), 'Hey!');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(fake.sendMessageCount, 1);
      expect(fake.lastMessageText, 'Hey!');
    });

    testWidgets('text field is cleared after sending message', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake));
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });
  });
}
