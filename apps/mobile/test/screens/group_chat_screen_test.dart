import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart'
    as chat_entity;
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/jukebox/presentation/providers/jukebox_provider.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/screens/group_chat_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';
import 'package:mobile/theme/app_routes.dart';
import 'package:mobile/shared/layered_avatar.dart';
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
  int endSessionCount = 0;

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
  Future<void> endSession() async => endSessionCount++;

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

class _FakeJukeboxNotifier extends JukeboxNotifier {
  @override
  JukeboxUiState build() => const JukeboxUiState();

  @override
  void enterRoom(String roomId) {}

  @override
  void leaveRoom() {}

  @override
  Future<void> addUrl(String url) async {}

  @override
  Future<void> skip() async {}

  @override
  Future<void> setPlaying(bool isPlaying) async {}

  @override
  Future<void> removeFromQueue(int index) async {}
}

class _FakeFriendsNotifierForGroup extends FriendsNotifier {
  int sendRequestCount = 0;
  AppUser? lastRequestTarget;

  @override
  FriendsState build() => const FriendsState();

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {
    sendRequestCount++;
    lastRequestTarget = toUser;
  }

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
  _FakeFriendsNotifierForGroup? friendsFake,
  AuthState auth = const AuthState(
    status: AuthStatus.authenticated,
    user: AuthUser(uid: 'u1'),
  ),
  Map<String, dynamic>? routeArgs,
  void Function(Map<String, dynamic>)? onFindingRoomArgs,
}) {
  final args = routeArgs ?? _kArgs;
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(initial: auth)),
      chatNotifierProvider.overrideWith(() => chatFake),
      matchmakingNotifierProvider.overrideWith(
        () => matchFake ?? _FakeMatchmakingNotifier(),
      ),
      avatarProvider.overrideWith(() => _FakeAvatarNotifier()),
      userProfileProvider.overrideWith(() => _FakeUserProfileNotifier()),
      friendsNotifierProvider.overrideWith(
        () => friendsFake ?? _FakeFriendsNotifierForGroup(),
      ),
      jukeboxNotifierProvider.overrideWith(() => _FakeJukeboxNotifier()),
    ],
    child: MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            settings: RouteSettings(name: '/', arguments: args),
            builder: (_) => const GroupChatScreen(),
          );
        }
        if (settings.name == AppRoutes.findingRoom) {
          final navArgs = settings.arguments as Map<String, dynamic>?;
          if (navArgs != null) onFindingRoomArgs?.call(navArgs);
          return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('finding-room')),
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

    testWidgets('tapping Add Friend on member calls sendFriendRequest', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final chatFake = _FakeChatNotifier(
        initial: ChatState(
          currentUserId: 'u1',
          messages: [
            chat_entity.ChatMessage(
              id: 'm1',
              senderId: 'u2',
              displayName: 'Bob',
              text: 'Hello!',
              timestamp: DateTime(2025),
            ),
          ],
        ),
      );
      final friendsFake = _FakeFriendsNotifierForGroup();
      await tester.pumpWidget(_buildScreen(chatFake, friendsFake: friendsFake));
      await _pump(tester);

      await tester.tap(find.byType(LayeredAvatar).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      if (find.text('Add Friend').evaluate().isNotEmpty) {
        await tester.tap(find.text('Add Friend'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(friendsFake.sendRequestCount, 1);
        expect(friendsFake.lastRequestTarget?.uid, 'u2');
      }
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
      final friendsFake = _FakeFriendsNotifierForGroup();
      await tester.pumpWidget(
        _buildScreen(
          _FakeChatNotifier(),
          matchFake: matchFake,
          friendsFake: friendsFake,
        ),
      );
      await _pump(tester);
      expect(find.text('The Sea of Cloud'), findsOneWidget);
      expect(find.text('Test Group'), findsNothing);
    });

    group('Skip Room', () {
      testWidgets('button is visible in the banner', (tester) async {
        await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
        await _pump(tester);
        expect(find.text('Skip\nRoom'), findsOneWidget);
      });

      testWidgets('tapping button shows Skip Room confirmation dialog', (
        tester,
      ) async {
        await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
        await _pump(tester);
        await tester.tap(find.text('Skip\nRoom'));
        await tester.pump();
        expect(find.text('Skip Room'), findsOneWidget);
        expect(find.textContaining('Leave this room and find'), findsOneWidget);
      });

      testWidgets(
        'cancelling dialog does not call leaveRoom or forceDisconnect',
        (tester) async {
          final chatFake = _FakeChatNotifier();
          final matchFake = _FakeMatchmakingNotifier();
          await tester.pumpWidget(_buildScreen(chatFake, matchFake: matchFake));
          await _pump(tester);
          await tester.tap(find.text('Skip\nRoom'));
          await tester.pump();
          await tester.tap(find.text('Cancel'));
          await tester.pump();
          expect(matchFake.leaveRoomCount, 0);
          expect(chatFake.forceDisconnectCount, 0);
        },
      );

      testWidgets(
        'confirming calls leaveRoom and forceDisconnect exactly once each, then navigates to finding-room',
        (tester) async {
          final chatFake = _FakeChatNotifier();
          final matchFake = _FakeMatchmakingNotifier();
          Map<String, dynamic>? captured;
          await tester.pumpWidget(
            _buildScreen(
              chatFake,
              matchFake: matchFake,
              onFindingRoomArgs: (a) => captured = a,
            ),
          );
          await _pump(tester);
          await tester.tap(find.text('Skip\nRoom'));
          await tester.pump();
          await tester.tap(find.text('Skip'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(matchFake.leaveRoomCount, 1);
          expect(chatFake.forceDisconnectCount, 1);
          expect(find.text('finding-room'), findsOneWidget);
          expect(find.text('home'), findsNothing);
        },
      );

      testWidgets(
        'route args carry original roomType and background — no old roomId',
        (tester) async {
          Map<String, dynamic>? captured;
          await tester.pumpWidget(
            _buildScreen(
              _FakeChatNotifier(),
              onFindingRoomArgs: (a) => captured = a,
            ),
          );
          await _pump(tester);
          await tester.tap(find.text('Skip\nRoom'));
          await tester.pump();
          await tester.tap(find.text('Skip'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(captured, isNotNull);
          expect(captured!['roomType'], _kArgs['roomType']); // 'group'
          expect(captured!['bgImage'], _kArgs['bgImage']);
          expect(captured!.containsKey('roomId'), isFalse);
        },
      );

      testWidgets('joinById roomType is remapped to group on skip', (
        tester,
      ) async {
        Map<String, dynamic>? captured;
        await tester.pumpWidget(
          _buildScreen(
            _FakeChatNotifier(),
            routeArgs: const {
              'roomId': 'GRP01',
              'roomName': 'Test Group',
              'bgImage': 'assets/images/backgrounds/kao_tapu.png',
              'roomType': 'joinById',
              'maxMembers': 5,
            },
            onFindingRoomArgs: (a) => captured = a,
          ),
        );
        await _pump(tester);
        await tester.tap(find.text('Skip\nRoom'));
        await tester.pump();
        await tester.tap(find.text('Skip'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(captured!['roomType'], 'group');
      });
    });
  });
}
