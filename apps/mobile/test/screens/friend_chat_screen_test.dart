import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/features/block/presentation/providers/block_provider.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend_message.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friend_chat_provider.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/models/friend.dart';
import 'package:mobile/screens/friend_chat_screen.dart';
import 'package:mobile/theme/app_routes.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signInWithGoogle() async {}
}

class _FakeFriendChatNotifier extends FriendChatNotifier {
  int enterChatCount = 0;
  String? lastChatRoomId;
  String? lastFriendDisplayName;
  int leaveChatCount = 0;
  int sendMessageCount = 0;
  String? lastMessageText;
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

class _FakeFriendsNotifier extends FriendsNotifier {
  @override
  FriendsState build() => const FriendsState();

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {}
  @override
  Future<void> acceptRequest(FriendRequest request) async {}
  @override
  Future<void> declineRequest(String requestId) async {}
  @override
  Future<void> removeFriend(String friendshipId) async {}
  @override
  void clearError() {}
  @override
  Future<void> markChatAsRead(String chatRoomId) async {}
}

class _FakeFriendChatNotifierWithError extends FriendChatNotifier {
  @override
  FriendChatState build() => const FriendChatState();

  @override
  Future<void> enterChat(String chatRoomId, String friendDisplayName) async {}

  @override
  Future<void> sendMessage(String text) async {
    state = state.copyWith(error: 'Send failed');
  }

  @override
  void leaveChat() {}
}

class _FakeBlockNotifier extends BlockNotifier {
  @override
  BlockState build() => const BlockState();

  @override
  Future<void> block(String targetUid, {String? displayName}) async {}

  @override
  Future<void> unblock(String targetUid) async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

final _onlineFriend = Friend(
  friendshipId: 'fship1',
  chatRoomId: 'room-1',
  name: 'Alice',
  username: 'alice99',
  lastMessage: 'Hey!',
  isOnline: true,
);

final _offlineFriend = Friend(
  friendshipId: 'fship2',
  chatRoomId: 'room-2',
  name: 'Bob',
  username: 'bob77',
  lastMessage: 'Bye',
  isOnline: false,
);

Widget _buildScreen(
  _FakeFriendChatNotifier chatFake, {
  _FakeAuthNotifier? authFake,
  Friend? friend,
  bool simulateBlocked = false,
}) {
  friend ??= _onlineFriend;
  final auth =
      authFake ??
      _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'current-uid', displayName: 'Me'),
        ),
      );
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => auth),
      friendChatNotifierProvider.overrideWith(() => chatFake),
      friendsNotifierProvider.overrideWith(() => _FakeFriendsNotifier()),
      avatarDecorationByUidProvider.overrideWith((ref, uid) async => null),
      profileByUidProvider.overrideWith((ref, uid) async => null),
      blockNotifierProvider.overrideWith(() => _FakeBlockNotifier()),
      isBlockedByProvider.overrideWith(
        (ref, uid) => Stream.value(simulateBlocked),
      ),
    ],
    child: MaterialApp(
      routes: {
        '/': (ctx) => Builder(
          builder: (innerCtx) => TextButton(
            onPressed: () => Navigator.pushNamed(
              innerCtx,
              AppRoutes.friendChat,
              arguments: friend,
            ),
            child: const Text('go'),
          ),
        ),
        AppRoutes.friendChat: (_) => const FriendChatScreen(),
        AppRoutes.groupChatScreen: (_) =>
            const Scaffold(body: Text('group-chat')),
      },
    ),
  );
}

Widget _buildScreenWithErrorNotifier(Friend? friend) {
  friend ??= _onlineFriend;
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(
        () => _FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: const AuthUser(uid: 'current-uid', displayName: 'Me'),
          ),
        ),
      ),
      friendChatNotifierProvider.overrideWith(
        () => _FakeFriendChatNotifierWithError(),
      ),
      friendsNotifierProvider.overrideWith(() => _FakeFriendsNotifier()),
      avatarDecorationByUidProvider.overrideWith((ref, uid) async => null),
      profileByUidProvider.overrideWith((ref, uid) async => null),
      blockNotifierProvider.overrideWith(() => _FakeBlockNotifier()),
      isBlockedByProvider.overrideWith((ref, uid) => Stream.value(false)),
    ],
    child: MaterialApp(
      routes: {
        '/': (ctx) => Builder(
          builder: (innerCtx) => TextButton(
            onPressed: () => Navigator.pushNamed(
              innerCtx,
              AppRoutes.friendChat,
              arguments: friend,
            ),
            child: const Text('go'),
          ),
        ),
        AppRoutes.friendChat: (_) => const FriendChatScreen(),
      },
    ),
  );
}

Future<void> _navigate(WidgetTester tester) async {
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('FriendChatScreen', () {
    testWidgets('enterChat called with chatRoomId and username on mount', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      expect(fake.enterChatCount, 1);
      expect(fake.lastChatRoomId, 'room-1');
      expect(fake.lastFriendDisplayName, 'alice99');
    });

    testWidgets('leaveChat called when screen is disposed', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      expect(fake.leaveChatCount, 0);
      // Replace widget tree to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(fake.leaveChatCount, 1);
    });

    testWidgets('renders messages from FriendChatState', (tester) async {
      final msg = FriendMessage(
        id: 'm1',
        senderId: 'other-uid',
        senderDisplayName: 'Alice',
        text: 'Real message from backend',
        timestamp: DateTime(2024),
      );
      final fake = _FakeFriendChatNotifier(
        initial: FriendChatState(messages: [msg]),
      );
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      expect(find.text('Real message from backend'), findsOneWidget);
    });

    testWidgets('does not render mock conversation data', (tester) async {
      final fake = _FakeFriendChatNotifier(
        initial: const FriendChatState(messages: []),
      );
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      // Mock data from _mockConversations must not appear
      expect(find.text('Hello 😊🔥💕😊'), findsNothing);
      expect(find.text('How are you?'), findsNothing);
    });

    testWidgets('shows safety notice banner when no messages and not loading', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier(
        initial: const FriendChatState(messages: [], isLoading: false),
      );
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      expect(find.textContaining('Keep it friendly!'), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator when isLoading', (tester) async {
      final fake = _FakeFriendChatNotifier(
        initial: const FriendChatState(isLoading: true),
      );
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await tester.tap(find.text('go'));
      await tester.pump(); // navigate
      await tester.pump(); // layout
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'shows CircularProgressIndicator and hides send icon when isSending',
      (tester) async {
        final fake = _FakeFriendChatNotifier(
          initial: const FriendChatState(isSending: true),
        );
        await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
        await tester.tap(find.text('go'));
        await tester.pump(); // navigate
        await tester.pump(); // layout
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.bySemanticsLabel('Send message'), findsNothing);
      },
    );

    testWidgets('tapping send calls sendMessage with typed text', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      await tester.enterText(find.byType(TextField), 'Hello backend!');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pump();
      expect(fake.sendMessageCount, 1);
      expect(fake.lastMessageText, 'Hello backend!');
    });

    testWidgets('input cleared after send', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text ?? '', isEmpty);
    });

    testWidgets('sendMessage not called when text field is empty', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pump();
      expect(fake.sendMessageCount, 0);
    });

    testWidgets('shows error SnackBar when error transitions to non-null', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreenWithErrorNotifier(_onlineFriend));
      await _navigate(tester);
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Send failed'), findsOneWidget);
    });

    testWidgets('shows blocked bar and no TextField when friend is blocked', (
      tester,
    ) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(
        _buildScreen(fake, friend: _onlineFriend, simulateBlocked: true),
      );
      await _navigate(tester);
      expect(
        find.text('You can no longer send messages in this chat.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows TextField when friend is not blocked', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows friend display name in header', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      expect(find.text('alice99'), findsOneWidget);
    });

    testWidgets('shows Online when friend is online', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
      await _navigate(tester);
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('shows Offline when friend is offline', (tester) async {
      final fake = _FakeFriendChatNotifier();
      await tester.pumpWidget(_buildScreen(fake, friend: _offlineFriend));
      await _navigate(tester);
      expect(find.text('Offline'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('has Send message and Go back semantic labels', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          final fake = _FakeFriendChatNotifier();
          await tester.pumpWidget(_buildScreen(fake, friend: _onlineFriend));
          await _navigate(tester);
          expect(find.bySemanticsLabel('Send message'), findsOneWidget);
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
