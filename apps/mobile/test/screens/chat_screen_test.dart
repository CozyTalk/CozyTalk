import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart'
    as chat_entity;
import 'package:mobile/features/chat/domain/entities/session_status.dart';
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/features/jukebox/presentation/providers/jukebox_provider.dart';
import 'package:mobile/screens/chat_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';
import 'package:mobile/shared/layered_avatar.dart';
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
  MatchmakingState _initial;

  _FakeMatchmakingNotifier({
    MatchmakingState initial = const MatchmakingState(),
  }) : _initial = initial;

  @override
  MatchmakingState build() => _initial;

  void setStateForTest(MatchmakingState s) {
    _initial = s;
    state = s;
  }

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
  Future<void> setRoomLock({required bool isLocked}) async {}

  @override
  Future<void> leaveRoom() async {}

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

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileState _initial;
  int loadCount = 0;
  String? lastLoadedUid;

  _FakeProfileNotifier({ProfileState initial = const ProfileState()})
    : _initial = initial;

  @override
  ProfileState build() => _initial;

  @override
  Future<void> load(String uid) async {
    loadCount++;
    lastLoadedUid = uid;
  }
}

class _FakeFriendsNotifierForChat extends FriendsNotifier {
  final FriendsState _initial;
  int sendFriendRequestCount = 0;
  AppUser? lastRequestedUser;

  _FakeFriendsNotifierForChat({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {
    sendFriendRequestCount++;
    lastRequestedUser = toUser;
  }

  @override
  Future<void> cancelFriendRequest(String toUid) async {}

  @override
  void clearError() {}
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

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kArgs = {
  'roomId': 'TEST1',
  'roomName': 'Test Room',
  'bgImage': 'assets/images/backgrounds/red_lotus_lake.png',
  'roomType': '1v1',
};

/// Pumps one frame to execute [addPostFrameCallback], then advances 400 ms to
/// drain the non-cancellable [Future.delayed(350ms)] created inside
/// [_scrollToBottom]. Without this the test framework reports a pending timer.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _buildScreen(
  _FakeChatNotifier chatFake, {
  _FakeMatchmakingNotifier? matchFake,
  _FakeProfileNotifier? profileFake,
  _FakeFriendsNotifierForChat? friendsFake,
  // Per-uid profile overrides for partner/other users.
  // Keys are UIDs; values are the ProfileUser to return from profileByUidProvider.
  Map<String, ProfileUser>? partnerProfilesByUid,
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
      profileNotifierProvider.overrideWith(
        () => profileFake ?? _FakeProfileNotifier(),
      ),
      friendsNotifierProvider.overrideWith(
        () => friendsFake ?? _FakeFriendsNotifierForChat(),
      ),
      jukeboxNotifierProvider.overrideWith(() => _FakeJukeboxNotifier()),
      // Prevent real Firestore calls for per-uid decoration in tests.
      avatarDecorationByUidProvider.overrideWith((ref, uid) async => null),
      // Inject partner profile data so tests don't need Firebase.
      if (partnerProfilesByUid != null)
        ...partnerProfilesByUid.entries.map(
          (e) =>
              profileByUidProvider(e.key).overrideWith((ref) async => e.value),
        ),
    ],
    child: MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            settings: RouteSettings(name: '/', arguments: _kArgs),
            builder: (_) => const ChatScreen(),
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
  group('ChatScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
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
      expect(find.text('Test Room'), findsOneWidget);
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

    testWidgets('clearing text field calls setTyping false', (tester) async {
      final chatFake = _FakeChatNotifier();
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      expect(chatFake.lastTypingValue, false);
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

    testWidgets('empty text does not call sendMessage', (tester) async {
      final chatFake = _FakeChatNotifier();
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

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

    testWidgets('partner leaving triggers forceDisconnect', (tester) async {
      final chatFake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 's1',
        ),
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(status: MatchmakingStatus.matched),
      );
      await tester.pumpWidget(_buildScreen(chatFake, matchFake: matchFake));
      await _pump(tester);

      matchFake.setStateForTest(const MatchmakingState());
      await tester.pump();

      expect(chatFake.forceDisconnectCount, 1);
    });

    testWidgets(
      'partner displayName from profileByUidProvider appears in avatar dialog',
      (tester) async {
        final matchFake = _FakeMatchmakingNotifier(
          initial: MatchmakingState(
            roomId: 'room1',
            currentRoom: Room(
              roomId: 'room1',
              roomType: RoomType.public,
              mode: RoomMode.oneToOne,
              status: RoomStatus.active,
              maxUsers: 2,
              memberCount: 2,
              users: const ['u1', 'u2'],
              isLocked: false,
              createdAt: DateTime(2025),
            ),
          ),
        );
        await tester.pumpWidget(
          _buildScreen(
            _FakeChatNotifier(),
            matchFake: matchFake,
            partnerProfilesByUid: {
              'u2': ProfileUser(uid: 'u2', displayName: 'Alice'),
            },
          ),
        );
        await _pump(tester);

        // The partner avatar in the banner opens a UserProfileDialog on tap.
        // profileByUidProvider('u2') is overridden to return Alice immediately
        // so the dialog should show 'Alice' once the future resolves.
        await tester.tap(find.byType(LayeredAvatar).first);
        await tester.pump();

        expect(find.text('Alice'), findsWidgets);
      },
    );

    testWidgets(
      'shows partner thoughts from profileByUidProvider in thought bubble',
      (tester) async {
        final matchFake = _FakeMatchmakingNotifier(
          initial: MatchmakingState(
            roomId: 'room1',
            currentRoom: Room(
              roomId: 'room1',
              roomType: RoomType.public,
              mode: RoomMode.oneToOne,
              status: RoomStatus.active,
              maxUsers: 2,
              memberCount: 2,
              users: const ['u1', 'u2'],
              isLocked: false,
              createdAt: DateTime(2025),
            ),
          ),
        );
        await tester.pumpWidget(
          _buildScreen(
            _FakeChatNotifier(),
            matchFake: matchFake,
            partnerProfilesByUid: {
              'u2': ProfileUser(
                uid: 'u2',
                displayName: 'Bob',
                thoughts: 'Love hiking!',
              ),
            },
          ),
        );
        await _pump(tester);
        expect(find.text('Love hiking!'), findsWidgets);
      },
    );

    testWidgets("gif_other message renders left-aligned, not right", (
      tester,
    ) async {
      final chatFake = _FakeChatNotifier(
        initial: ChatState(
          currentUserId: 'u1',
          messages: [
            chat_entity.ChatMessage(
              id: 'msg1',
              senderId: 'other_user',
              displayName: 'Brave Bear',
              text: 'https://media.giphy.com/test.gif',
              timestamp: DateTime(2025),
            ),
          ],
        ),
      );
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      // A gif from another user must not produce an end-aligned row (which
      // would place the bubble on the "me" / right side).
      expect(
        find.byWidgetPredicate(
          (w) => w is Row && w.mainAxisAlignment == MainAxisAlignment.end,
        ),
        findsNothing,
      );
    });

    testWidgets('uses currentRoom backgroundTheme over route arg bgImage', (
      tester,
    ) async {
      final room = Room(
        roomId: 'TEST1',
        roomType: RoomType.public,
        mode: RoomMode.oneToOne,
        status: RoomStatus.active,
        maxUsers: 2,
        memberCount: 2,
        users: const ['u1', 'u2'],
        isLocked: false,
        createdAt: DateTime(2025),
        backgroundTheme: 'sea_of_cloud',
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'TEST1',
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
                  'assets/images/backgrounds/sea_of_cloud.png',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/backgrounds/red_lotus_lake.png',
        ),
        findsNothing,
      );
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
          await _pump(tester);
          expect(find.bySemanticsLabel('Send message'), findsOneWidget);
          expect(find.bySemanticsLabel('End chat'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });

    group('Add Friend', () {
      _FakeMatchmakingNotifier matchWithPartnerFake() =>
          _FakeMatchmakingNotifier(
            initial: MatchmakingState(
              status: MatchmakingStatus.matched,
              roomId: 'room-1',
              partnerUids: const ['partner-uid'],
              currentRoom: Room(
                roomId: 'room-1',
                roomType: RoomType.public,
                mode: RoomMode.oneToOne,
                status: RoomStatus.active,
                maxUsers: 2,
                memberCount: 2,
                users: const ['u1', 'partner-uid'],
                isLocked: false,
                createdAt: DateTime(2025),
              ),
            ),
          );

      testWidgets('partner avatar dialog exposes Add friend semantic button', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        try {
          final friendsFake = _FakeFriendsNotifierForChat();
          await tester.pumpWidget(
            _buildScreen(
              _FakeChatNotifier(),
              matchFake: matchWithPartnerFake(),
              friendsFake: friendsFake,
            ),
          );
          await _pump(tester);
          await tester.pump(); // settle FutureProvider
          final partnerAvatars = find.bySemanticsLabel('View user profile');
          expect(partnerAvatars, findsWidgets);
          await tester.tap(partnerAvatars.first);
          await tester.pump(); // show dialog
          await tester.pump(const Duration(milliseconds: 250)); // animation
          expect(find.bySemanticsLabel('Add friend'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });

      testWidgets(
        'tapping Add Friend calls friendsNotifierProvider.sendFriendRequest with partner UID',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            final friendsFake = _FakeFriendsNotifierForChat();
            await tester.pumpWidget(
              _buildScreen(
                _FakeChatNotifier(),
                matchFake: matchWithPartnerFake(),
                friendsFake: friendsFake,
              ),
            );
            await _pump(tester);
            await tester.pump(); // settle FutureProvider
            await tester.tap(find.bySemanticsLabel('View user profile').first);
            await tester.pump(); // show dialog
            await tester.pump(const Duration(milliseconds: 250)); // animation
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

      testWidgets(
        'sendFriendRequest not called a second time while isLoading',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            final friendsFake = _FakeFriendsNotifierForChat(
              initial: const FriendsState(isLoading: true),
            );
            await tester.pumpWidget(
              _buildScreen(
                _FakeChatNotifier(),
                matchFake: matchWithPartnerFake(),
                friendsFake: friendsFake,
              ),
            );
            await _pump(tester);
            await tester.pump(); // settle FutureProvider
            await tester.tap(find.bySemanticsLabel('View user profile').first);
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
        },
      );

      testWidgets(
        'error SnackBar shown when friendsNotifierProvider.error is non-null',
        (tester) async {
          final friendsFake = _FakeFriendsNotifierForChat();
          await tester.pumpWidget(
            _buildScreen(_FakeChatNotifier(), friendsFake: friendsFake),
          );
          await _pump(tester);
          // Simulate error state transition
          friendsFake.state = friendsFake.state.copyWith(
            error: 'Request failed',
          );
          await tester.pump();
          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.text('Request failed'), findsOneWidget);
        },
      );

      testWidgets(
        'add-friend button updates reactively when outgoingRequests state changes',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            final friendsFake = _FakeFriendsNotifierForChat();
            await tester.pumpWidget(
              _buildScreen(
                _FakeChatNotifier(),
                matchFake: matchWithPartnerFake(),
                friendsFake: friendsFake,
              ),
            );
            await _pump(tester);
            await tester.pump(); // settle FutureProvider

            // Initial state: no outgoing request → "Add friend"
            await tester.tap(find.bySemanticsLabel('View user profile').first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            expect(find.bySemanticsLabel('Add friend'), findsOneWidget);
            await tester.tapAt(
              const Offset(10, 10),
            ); // dismiss dialog via barrier
            await tester.pump(); // close dialog

            // Simulate outgoing request added to state (proves ref.watch triggers rebuild)
            friendsFake.state = friendsFake.state.copyWith(
              outgoingRequests: [
                FriendRequest(
                  id: 'req-1',
                  fromUid: 'u1',
                  fromDisplayName: 'Me',
                  toUid: 'partner-uid',
                  toDisplayName: 'Partner',
                  status: FriendRequestStatus.pending,
                  createdAt: DateTime(2025),
                ),
              ],
            );
            await tester.pump();

            // Reopen dialog — button must now reflect the updated state
            await tester.tap(find.bySemanticsLabel('View user profile').first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            expect(
              find.bySemanticsLabel('Cancel friend request'),
              findsOneWidget,
            );
          } finally {
            handle.dispose();
          }
        },
      );
    });
  });
}
