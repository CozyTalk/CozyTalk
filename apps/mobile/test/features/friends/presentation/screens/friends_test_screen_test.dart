import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/screens/friends_test_screen.dart';

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
  int sendFriendRequestCount = 0;
  AppUser? lastAddedUser;
  int clearErrorCount = 0;
  final FriendsState _initial;

  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {
    sendFriendRequestCount++;
    lastAddedUser = toUser;
  }

  @override
  Future<void> acceptRequest(FriendRequest request) async {}

  @override
  Future<void> declineRequest(String requestId) async {}

  @override
  Future<void> removeFriend(String friendshipId) async {}

  @override
  void clearError() => clearErrorCount++;
}

Widget _buildScreen(
  _FakeFriendsNotifier friendsFake, {
  _FakeAuthNotifier? authFake,
}) {
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
      friendsNotifierProvider.overrideWith(() => friendsFake),
    ],
    child: const MaterialApp(home: FriendsTestScreen()),
  );
}

void main() {
  group('FriendsTestScreen', () {
    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.text('Friends — Dev Test'), findsOneWidget);
    });

    testWidgets('renders current user display name from auth state', (
      tester,
    ) async {
      final auth = _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'uid-42', displayName: 'Cozy Bear'),
        ),
      );
      await tester.pumpWidget(
        _buildScreen(_FakeFriendsNotifier(), authFake: auth),
      );
      expect(find.text('Cozy Bear'), findsOneWidget);
    });

    testWidgets('renders My Friends & Requests button', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.textContaining('My Friends & Requests'), findsOneWidget);
    });

    testWidgets('shows friend/request counts in button label', (tester) async {
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u2',
        friendDisplayName: 'Bob',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      final request = FriendRequest(
        id: 'r1',
        fromUid: 'u3',
        fromDisplayName: 'Carol',
        toUid: 'current-uid',
        toDisplayName: 'Me',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2024),
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [friend], incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.textContaining('1 friends'), findsOneWidget);
      expect(find.textContaining('1 pending'), findsOneWidget);
    });

    testWidgets('renders user list when allUsers is populated', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          allUsers: [
            const AppUser(uid: 'u1', displayName: 'Alice'),
            const AppUser(uid: 'u2', displayName: 'Bob'),
          ],
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('shows Add button for users who are not friends', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('shows Friends chip for users already in friend list', (
      tester,
    ) async {
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u1',
        friendDisplayName: 'Alice',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
          friends: [friend],
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
    });

    testWidgets('tapping Add button calls sendFriendRequest', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(fake.sendFriendRequestCount, 1);
      expect(fake.lastAddedUser?.uid, 'u1');
    });

    testWidgets('Add button is disabled when isLoading is true', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          allUsers: [const AppUser(uid: 'u1', displayName: 'Alice')],
          isLoading: true,
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Add'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows no users message when list is empty', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.text('No other users found.'), findsOneWidget);
    });
  });
}
