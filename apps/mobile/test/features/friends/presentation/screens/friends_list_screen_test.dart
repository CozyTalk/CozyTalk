import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/friends/presentation/screens/friends_list_screen.dart';

class _FakeFriendsNotifier extends FriendsNotifier {
  int acceptRequestCount = 0;
  FriendRequest? lastAcceptedRequest;
  int declineRequestCount = 0;
  String? lastDeclinedRequestId;
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
  Future<void> acceptRequest(FriendRequest request) async {
    acceptRequestCount++;
    lastAcceptedRequest = request;
  }

  @override
  Future<void> declineRequest(String requestId) async {
    declineRequestCount++;
    lastDeclinedRequestId = requestId;
  }

  @override
  Future<void> removeFriend(String friendshipId) async {
    removeFriendCount++;
    lastRemovedFriendshipId = friendshipId;
  }

  @override
  void clearError() {}
}

Widget _buildScreen(_FakeFriendsNotifier fake) {
  return ProviderScope(
    overrides: [friendsNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: FriendsListScreen()),
  );
}

void main() {
  group('FriendsListScreen', () {
    testWidgets('renders Friends and Requests tabs', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.text('Friends'), findsWidgets);
      expect(find.text('Requests'), findsOneWidget);
    });

    testWidgets('shows empty state when friends list is empty', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.text('No friends yet — send some requests!'), findsOneWidget);
    });

    testWidgets('shows friend display name in friends tab', (tester) async {
      final friend = Friend(
        friendshipId: 'f1',
        friendUid: 'u2',
        friendDisplayName: 'Alice',
        chatRoomId: 'f1',
        friendedAt: DateTime(2024),
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [friend]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('shows badge on Requests tab when there are pending requests', (
      tester,
    ) async {
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
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.byType(Badge), findsOneWidget);
    });

    testWidgets('shows empty state in Requests tab when no pending requests', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('No pending friend requests.'), findsOneWidget);
    });

    testWidgets('tapping Accept calls acceptRequest with the request', (
      tester,
    ) async {
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
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();
      expect(fake.acceptRequestCount, 1);
      expect(fake.lastAcceptedRequest?.id, 'r1');
    });

    testWidgets('tapping Decline calls declineRequest with request id', (
      tester,
    ) async {
      final request = FriendRequest(
        id: 'r2',
        fromUid: 'u4',
        fromDisplayName: 'Dave',
        toUid: 'current-uid',
        toDisplayName: 'Me',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2024),
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pump();
      expect(fake.declineRequestCount, 1);
      expect(fake.lastDeclinedRequestId, 'r2');
    });

    testWidgets('Accept and Decline buttons are disabled when isLoading', (
      tester,
    ) async {
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
        initial: FriendsState(incomingRequests: [request], isLoading: true),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      final acceptBtn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.check_circle_outline),
          matching: find.byType(IconButton),
        ),
      );
      final declineBtn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.cancel_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(acceptBtn.onPressed, isNull);
      expect(declineBtn.onPressed, isNull);
    });
  });
}
