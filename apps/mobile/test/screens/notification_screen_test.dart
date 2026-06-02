import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/screens/notification_screen.dart';

class _FakeFriendsNotifier extends FriendsNotifier {
  final FriendsState _initial;
  int queueAcceptCount = 0;
  FriendRequest? lastQueuedAccept;
  int queueDeclineCount = 0;
  FriendRequest? lastQueuedDecline;
  int undoPendingCount = 0;
  String? lastUndoPendingId;
  int undoCommittedCount = 0;
  FriendRequest? lastUndoCommitted;
  int commitCount = 0;

  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {}

  @override
  void queueAccept(FriendRequest request) {
    queueAcceptCount++;
    lastQueuedAccept = request;
  }

  @override
  void queueDecline(FriendRequest request) {
    queueDeclineCount++;
    lastQueuedDecline = request;
  }

  @override
  void undoPendingAction(String requestId) {
    undoPendingCount++;
    lastUndoPendingId = requestId;
  }

  @override
  Future<void> undoCommittedAction(FriendRequest request) async {
    undoCommittedCount++;
    lastUndoCommitted = request;
  }

  @override
  void commitPendingActions() {
    commitCount++;
  }

  @override
  Future<void> acceptRequest(FriendRequest request) async {}

  @override
  Future<void> declineRequest(FriendRequest request) async {}

  @override
  Future<void> removeFriend(String friendshipId) async {}

  @override
  void clearError() {}
}

Widget _buildScreen(_FakeFriendsNotifier fake) {
  return ProviderScope(
    overrides: [friendsNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: NotificationScreen()),
  );
}

FriendRequest _makeRequest({
  String id = 'req-1',
  String fromUid = 'u1',
  String fromDisplayName = 'Alice',
  FriendRequestStatus status = FriendRequestStatus.pending,
  DateTime? createdAt,
}) => FriendRequest(
  id: id,
  fromUid: fromUid,
  fromDisplayName: fromDisplayName,
  toUid: 'me',
  toDisplayName: 'Me',
  status: status,
  createdAt: createdAt ?? DateTime.now().subtract(const Duration(minutes: 5)),
);

void main() {
  group('NotificationScreen', () {
    testWidgets('renders Notifications title', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('shows friend request card with sender name', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [_makeRequest()]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Alice wants to be friends'), findsOneWidget);
    });

    testWidgets('shows Accept and Decline for pending with no action', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [_makeRequest()]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('tapping Accept calls queueAccept', (tester) async {
      final request = _makeRequest(id: 'req-42');
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(fake.queueAcceptCount, 1);
      expect(fake.lastQueuedAccept?.id, 'req-42');
    });

    testWidgets('tapping Decline calls queueDecline', (tester) async {
      final request = _makeRequest(id: 'req-99');
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(fake.queueDeclineCount, 1);
      expect(fake.lastQueuedDecline?.id, 'req-99');
    });

    testWidgets('shows grey Accept when pendingActions is accepted', (
      tester,
    ) async {
      final request = _makeRequest(id: 'req-1');
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          incomingRequests: [request],
          pendingActions: {request.id: 'accepted'},
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('shows grey Decline when pendingActions is declined', (
      tester,
    ) async {
      final request = _makeRequest(id: 'req-1');
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          incomingRequests: [request],
          pendingActions: {request.id: 'declined'},
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('shows grey Accept for committed accepted request', (
      tester,
    ) async {
      final request = _makeRequest(
        id: 'req-1',
        status: FriendRequestStatus.accepted,
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('tapping grey on queued action calls undoPendingAction', (
      tester,
    ) async {
      final request = _makeRequest(id: 'req-1');
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          incomingRequests: [request],
          pendingActions: {request.id: 'declined'},
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(fake.undoPendingCount, 1);
      expect(fake.lastUndoPendingId, 'req-1');
    });

    testWidgets('tapping grey on committed action calls undoCommittedAction', (
      tester,
    ) async {
      final request = _makeRequest(
        id: 'req-2',
        status: FriendRequestStatus.declined,
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(fake.undoCommittedCount, 1);
      expect(fake.lastUndoCommitted?.id, 'req-2');
    });

    testWidgets('shows multiple request cards', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          incomingRequests: [
            _makeRequest(id: 'r1', fromDisplayName: 'Bob'),
            _makeRequest(id: 'r2', fromDisplayName: 'Carol'),
          ],
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Bob wants to be friends'), findsOneWidget);
      expect(find.text('Carol wants to be friends'), findsOneWidget);
    });

    testWidgets('shows empty state text when no requests', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.text('No notifications'), findsOneWidget);
      expect(find.textContaining('wants to be friends'), findsNothing);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
