import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/screens/group_chat_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';
import 'package:mobile/shared/press_bounce_btn.dart';
import 'package:mobile/shared/user_profile.dart';

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

class _FakeChatNotifier extends ChatNotifier {
  final ChatState _initial;
  final List<String> sentMessages = [];
  int setTypingCount = 0;
  bool? lastTypingValue;
  int forceDisconnectCount = 0;

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
  Future<void> sendMessage(String text) async => sentMessages.add(text);

  @override
  Future<void> setTyping(bool isTyping) async {
    setTypingCount++;
    lastTypingValue = isTyping;
  }

  @override
  Future<void> endSession() async {}

  @override
  void forceDisconnect() => forceDisconnectCount++;
}

class _FakeMatchmakingNotifier extends MatchmakingNotifier {
  final MatchmakingState _initial;
  bool? lastLockValue;
  int leaveRoomCount = 0;

  _FakeMatchmakingNotifier({
    MatchmakingState initial = const MatchmakingState(),
  }) : _initial = initial;

  @override
  MatchmakingState build() => _initial;

  @override
  Future<void> join1v1Pool() async {}

  @override
  Future<void> joinGroupRoom() async {}

  @override
  Future<void> createCustomRoom() async {}

  @override
  Future<void> joinRoomById(String roomId) async {}

  @override
  Future<void> cancelSearch() async {}

  @override
  Future<void> setRoomLock({required bool isLocked}) async =>
      lastLockValue = isLocked;

  @override
  Future<void> leaveRoom() async => leaveRoomCount++;

  @override
  void setInterestText(String text) {}

  @override
  Future<void> loadSavedInterestText() async {}
}

class _FakeAvatarNotifier extends AvatarNotifier {
  @override
  AvatarState build() => AvatarState();
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

class _FakeFriendsNotifier extends FriendsNotifier {
  int sendFriendRequestCount = 0;
  AppUser? lastRequestedUser;
  final FriendsState _initial;

  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {
    sendFriendRequestCount++;
    lastRequestedUser = toUser;
  }

  @override
  Future<void> acceptRequest(FriendRequest request) async {}

  @override
  Future<void> declineRequest(String requestId) async {}

  @override
  Future<void> removeFriend(String friendshipId) async {}

  @override
  void clearError() {}
}

/// Pumps one frame to execute [addPostFrameCallback], then advances 400 ms to
/// drain the non-cancellable [Future.delayed(350ms)] inside [_scrollToBottom].
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Helper ────────────────────────────────────────────────────────────────────

const _kArgs = {
  'roomId': 'GRP01',
  'roomName': 'Test Group',
  'bgImage': 'assets/images/backgrounds/kao_tapu.png',
  'roomType': 'group',
  'maxMembers': 5,
};

Widget _buildScreen(
  _FakeChatNotifier chatFake, {
  _FakeMatchmakingNotifier? matchFake,
  _FakeFriendsNotifier? friendsFake,
  List<AppUser> partnerUsers = const [
    AppUser(uid: 'partner-a', displayName: 'Alice'),
    AppUser(uid: 'partner-b', displayName: 'Bob'),
  ],
  AuthState auth = const AuthState(
    status: AuthStatus.authenticated,
    user: AuthUser(uid: 'u1'),
  ),
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(initial: auth)),
      chatNotifierProvider.overrideWith(() => chatFake),
      matchmakingNotifierProvider.overrideWith(
        () => matchFake ?? _FakeMatchmakingNotifier(),
      ),
      avatarProvider.overrideWith(() => _FakeAvatarNotifier()),
      userProfileProvider.overrideWith(() => _FakeUserProfileNotifier()),
      getUsersByIdsProvider.overrideWith((ref, csv) async => partnerUsers),
      friendsNotifierProvider.overrideWith(
        () => friendsFake ?? _FakeFriendsNotifier(),
      ),
    ],
    child: MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/', arguments: _kArgs),
            builder: (_) => const GroupChatScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('home')),
        );
      },
      initialRoute: '/',
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('GroupChatScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.byType(GroupChatScreen), findsOneWidget);
    });

    testWidgets('shows Keep it friendly warning text', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.textContaining('Keep it friendly'), findsOneWidget);
    });

    testWidgets('shows Type here hint in text field', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.text('Type here ...'), findsOneWidget);
    });

    testWidgets('shows room name from route args', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.text('Test Group'), findsOneWidget);
    });

    testWidgets('shows lock toggle in header', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(
        find.byIcon(Icons.lock_open_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.lock_rounded).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('lock shows locked state when currentRoom.isLocked is true', (
      tester,
    ) async {
      final room = Room(
        roomId: 'GRP01',
        roomType: RoomType.custom,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 1,
        users: const ['u1'],
        isLocked: true,
        createdAt: DateTime(2025),
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'GRP01',
          currentRoom: room,
        ),
      );
      await tester.pumpWidget(
        _buildScreen(_FakeChatNotifier(), matchFake: matchFake),
      );
      await _pump(tester);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('tapping lock toggle calls setRoomLock', (tester) async {
      final room = Room(
        roomId: 'GRP01',
        roomType: RoomType.custom,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 1,
        users: const ['u1'],
        isLocked: false,
        createdAt: DateTime(2025),
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'GRP01',
          currentRoom: room,
        ),
      );
      await tester.pumpWidget(
        _buildScreen(_FakeChatNotifier(), matchFake: matchFake),
      );
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.lock_open_rounded));
      await tester.pump();

      expect(matchFake.lastLockValue, true);
    });

    testWidgets('typing in text field calls setTyping', (tester) async {
      final chatFake = _FakeChatNotifier();
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();

      expect(chatFake.setTypingCount, greaterThanOrEqualTo(1));
      expect(chatFake.lastTypingValue, true);
    });

    testWidgets('isSending=true prevents sendMessage when send tapped', (
      tester,
    ) async {
      final chatFake = _FakeChatNotifier(
        initial: const ChatState(isSending: true),
      );
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();

      final sendBtn = find.ancestor(
        of: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.color ==
                  const Color(0xFFEAC163),
        ),
        matching: find.byType(GestureDetector),
      );
      if (sendBtn.evaluate().isNotEmpty) {
        await tester.tap(sendBtn.first, warnIfMissed: false);
        await tester.pump();
      }

      expect(chatFake.sentMessages, isEmpty);
    });

    testWidgets(
      'tapping Leave header button calls leaveRoom and forceDisconnect',
      (tester) async {
        final chatFake = _FakeChatNotifier();
        final matchFake = _FakeMatchmakingNotifier();
        await tester.pumpWidget(_buildScreen(chatFake, matchFake: matchFake));
        await _pump(tester);

        // First PressBounceBtn in the header is the back/leave button
        await tester.tap(find.byType(PressBounceBtn).first);
        await tester.pump();

        // LeaveRoomDialog is now visible — tap the Leave confirmation
        await tester.tap(find.text('Leave'));
        await tester.pump();

        expect(matchFake.leaveRoomCount, 1);
        expect(chatFake.forceDisconnectCount, 1);
      },
    );

    testWidgets('uses currentRoom backgroundTheme over route arg bgImage', (
      tester,
    ) async {
      final room = Room(
        roomId: 'GRP01',
        roomType: RoomType.public,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 2,
        users: const ['u1', 'u2'],
        isLocked: false,
        createdAt: DateTime(2025),
        backgroundTheme: 'lumphini_park',
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'GRP01',
          currentRoom: room,
        ),
      );
      await tester.pumpWidget(
        _buildScreen(_FakeChatNotifier(), matchFake: matchFake),
      );
      await _pump(tester);

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/backgrounds/lumphini_park.png',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/backgrounds/kao_tapu.png',
        ),
        findsNothing,
      );
    });

    testWidgets('uses currentRoom backgroundTheme for room name', (
      tester,
    ) async {
      final room = Room(
        roomId: 'GRP02',
        roomType: RoomType.public,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 3,
        users: const ['u1', 'u2', 'u3'],
        isLocked: false,
        createdAt: DateTime(2025),
        backgroundTheme: 'sea_of_cloud',
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'GRP02',
          currentRoom: room,
        ),
      );
      await tester.pumpWidget(
        _buildScreen(_FakeChatNotifier(), matchFake: matchFake),
      );
      await _pump(tester);
      expect(find.text('The Sea of Cloud'), findsOneWidget);
      expect(find.text('Test Group'), findsNothing);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
          await _pump(tester);
          expect(find.bySemanticsLabel('Send message'), findsOneWidget);
          expect(find.bySemanticsLabel('End chat'), findsOneWidget);
          expect(find.bySemanticsLabel('Toggle room lock'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });

    group('Add Friend', () {
      Room roomFakeWith(List<String> users) => Room(
        roomId: 'GRP01',
        roomType: RoomType.custom,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: users.length,
        users: users,
        isLocked: false,
        createdAt: DateTime(2025),
      );

      testWidgets('member avatar dialog exposes Add friend semantic button', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          final friendsFake = _FakeFriendsNotifier();
          final matchFake = _FakeMatchmakingNotifier(
            initial: MatchmakingState(
              status: MatchmakingStatus.matched,
              roomId: 'GRP01',
              currentRoom: roomFakeWith(['u1', 'partner-a', 'partner-b']),
              partnerUids: ['partner-a', 'partner-b'],
            ),
          );
          await tester.pumpWidget(
            _buildScreen(
              _FakeChatNotifier(),
              matchFake: matchFake,
              friendsFake: friendsFake,
            ),
          );
          await _pump(tester);
          await tester.pump(); // settle FutureProvider
          // .at(0) is the 'Me' avatar; .at(1) is the first partner avatar
          final avatarBtns = find.bySemanticsLabel('View user profile');
          expect(avatarBtns.evaluate().length, greaterThan(1));
          await tester.tap(avatarBtns.at(1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.bySemanticsLabel('Add friend'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });

      testWidgets(
        'tapping Add Friend for a member calls sendFriendRequest with that member UID',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            final friendsFake = _FakeFriendsNotifier();
            final matchFake = _FakeMatchmakingNotifier(
              initial: MatchmakingState(
                status: MatchmakingStatus.matched,
                roomId: 'GRP01',
                currentRoom: roomFakeWith(['u1', 'partner-a']),
                partnerUids: ['partner-a'],
              ),
            );
            await tester.pumpWidget(
              _buildScreen(
                _FakeChatNotifier(),
                matchFake: matchFake,
                friendsFake: friendsFake,
              ),
            );
            await _pump(tester);
            await tester.pump(); // settle FutureProvider
            // .at(0) is 'Me'; .at(1) is partner
            await tester.tap(find.bySemanticsLabel('View user profile').at(1));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            await tester.tap(find.bySemanticsLabel('Add friend'));
            await tester.pump();
            expect(friendsFake.sendFriendRequestCount, 1);
            expect(friendsFake.lastRequestedUser?.uid, isNot('u1'));
            expect(friendsFake.lastRequestedUser?.uid, isNotNull);
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets('sendFriendRequest not called while isLoading', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          final friendsFake = _FakeFriendsNotifier(
            initial: const FriendsState(isLoading: true),
          );
          final matchFake = _FakeMatchmakingNotifier(
            initial: MatchmakingState(
              status: MatchmakingStatus.matched,
              roomId: 'GRP01',
              currentRoom: roomFakeWith(['u1', 'partner-a']),
              partnerUids: ['partner-a'],
            ),
          );
          await tester.pumpWidget(
            _buildScreen(
              _FakeChatNotifier(),
              matchFake: matchFake,
              friendsFake: friendsFake,
            ),
          );
          await _pump(tester);
          await tester.pump();
          // .at(1) is partner avatar; isLoading=true so onAddFriend should be null
          await tester.tap(find.bySemanticsLabel('View user profile').at(1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          if (find.bySemanticsLabel('Add friend').evaluate().isNotEmpty) {
            await tester.tap(find.bySemanticsLabel('Add friend'));
            await tester.pump();
          }
          expect(friendsFake.sendFriendRequestCount, 0);
        } finally {
          handle.dispose();
        }
      });

      testWidgets(
        'error SnackBar shown when friendsNotifierProvider.error is non-null',
        (tester) async {
          final friendsFake = _FakeFriendsNotifier();
          await tester.pumpWidget(
            _buildScreen(_FakeChatNotifier(), friendsFake: friendsFake),
          );
          await _pump(tester);
          friendsFake.state = friendsFake.state.copyWith(
            error: 'Friend request failed',
          );
          await tester.pump();
          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.text('Friend request failed'), findsOneWidget);
        },
      );
    });
  });
}
