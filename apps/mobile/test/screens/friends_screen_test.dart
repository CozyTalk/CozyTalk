import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';
import 'package:mobile/features/block/presentation/providers/block_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart' as domain;
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/screens/friends_screen.dart';
import 'package:mobile/screens/widgets.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/layered_avatar.dart';
import 'package:mobile/shared/network_info.dart';
import 'package:mobile/shared/offline_card.dart';
import '../shared/fake_network_info.dart';

class _FakeFriendsNotifier extends FriendsNotifier {
  final FriendsState _initial;
  int removeCount = 0;

  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> removeFriend(String friendshipId) async => removeCount++;

  @override
  void clearError() {}
}

class _LoadingToIdleFriendsNotifier extends FriendsNotifier {
  @override
  FriendsState build() => FriendsState(
    friends: [
      domain.Friend(
        friendshipId: 'fship1',
        friendUid: 'uid1',
        friendDisplayName: 'Alice',
        chatRoomId: 'room1',
        friendedAt: DateTime(2024),
      ),
    ],
  );

  @override
  Future<void> removeFriend(String friendshipId) async {
    state = state.copyWith(isLoading: true);
    await Future.microtask(() {});
    state = state.copyWith(isLoading: false);
  }

  @override
  void clearError() {}
}

class _FakeBlockNotifier extends BlockNotifier {
  final BlockState _initial;

  _FakeBlockNotifier({BlockState initial = const BlockState()})
    : _initial = initial;

  @override
  BlockState build() => _initial;

  @override
  Future<void> block(String targetUid, {String? displayName}) async {}

  @override
  Future<void> unblock(String targetUid) async {}
}

final _fakeDomainFriend = domain.Friend(
  friendshipId: 'fship1',
  friendUid: 'uid1',
  friendDisplayName: 'Alice',
  chatRoomId: 'room1',
  friendedAt: DateTime(2024),
);

Widget _build({
  required NetworkInfo networkInfo,
  _FakeFriendsNotifier? notifier,
  _FakeBlockNotifier? blockNotifier,
  bool isBlockedByFriend = false,
}) {
  final fake = notifier ?? _FakeFriendsNotifier();
  final blockFake = blockNotifier ?? _FakeBlockNotifier();
  return ProviderScope(
    overrides: [
      networkInfoProvider.overrideWithValue(networkInfo),
      friendsNotifierProvider.overrideWith(() => fake),
      avatarDecorationByUidProvider.overrideWith((ref, uid) async => null),
      getUsersByIdsProvider.overrideWith((ref, csv) async => []),
      blockNotifierProvider.overrideWith(() => blockFake),
      profileByUidProvider.overrideWith((ref, uid) async => null),
      isBlockedByProvider.overrideWith(
        (ref, uid) => Stream.value(isBlockedByFriend),
      ),
    ],
    child: const MaterialApp(home: FriendsScreen()),
  );
}

void main() {
  group('FriendsScreen', () {
    testWidgets('renders without crash when online', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true)),
      );
      expect(find.byType(FriendsScreen), findsOneWidget);
    });

    testWidgets('shows OfflineCard when offline', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: false)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsOneWidget);
    });

    testWidgets('does not show OfflineCard when online', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsNothing);
    });

    testWidgets('shows friend display name when provider has friends', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.text('Alice', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows no friend cards when provider returns empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsNothing);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('calls removeFriend on notifier after confirming Unfriend', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unfriend'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(fake.removeCount, 1);
    });

    testWidgets('shows last message text from lastMessageMap', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          friends: [_fakeDomainFriend],
          lastMessageMap: {'room1': 'hey there'},
        ),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.text('hey there'), findsOneWidget);
    });

    testWidgets('shows FriendRoomCard when friend is online and in a room', (
      tester,
    ) async {
      const roomStatus = FriendRoomStatus(
        roomId: 'abc12',
        memberCount: 3,
        maxUsers: 5,
        isLocked: false,
        mode: 'group',
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          friends: [_fakeDomainFriend],
          presenceMap: {'uid1': true},
          roomMap: {'uid1': roomStatus},
        ),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.byType(FriendRoomCard), findsOneWidget);
      expect(find.text('Group Room'), findsOneWidget);
    });

    testWidgets(
      'Join button is disabled when current user has blocked the friend',
      (tester) async {
        const roomStatus = FriendRoomStatus(
          roomId: 'abc12',
          memberCount: 2,
          maxUsers: 5,
          isLocked: false,
          mode: 'group',
        );
        final ts = DateTime(2024);
        final fake = _FakeFriendsNotifier(
          initial: FriendsState(
            friends: [_fakeDomainFriend],
            presenceMap: {'uid1': true},
            roomMap: {'uid1': roomStatus},
          ),
        );
        final blockFake = _FakeBlockNotifier(
          initial: BlockState(
            status: BlockStatus.loaded,
            blockedUsers: [BlockedUser(uid: 'uid1', blockedAt: ts)],
          ),
        );
        await tester.pumpWidget(
          _build(
            networkInfo: FakeNetworkInfo(isOnline: true),
            notifier: fake,
            blockNotifier: blockFake,
          ),
        );
        await tester.pump();
        expect(find.byType(FriendRoomCard), findsOneWidget);
        final joinFinder = find.text('Join');
        expect(joinFinder, findsOneWidget);
        final container = tester.widget<Container>(
          find.ancestor(of: joinFinder, matching: find.byType(Container)).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, Colors.grey.shade200);
      },
    );

    testWidgets(
      'Join button is disabled when friend has blocked the current user',
      (tester) async {
        const roomStatus = FriendRoomStatus(
          roomId: 'abc12',
          memberCount: 2,
          maxUsers: 5,
          isLocked: false,
          mode: 'group',
        );
        final fake = _FakeFriendsNotifier(
          initial: FriendsState(
            friends: [_fakeDomainFriend],
            presenceMap: {'uid1': true},
            roomMap: {'uid1': roomStatus},
          ),
        );
        await tester.pumpWidget(
          _build(
            networkInfo: FakeNetworkInfo(isOnline: true),
            notifier: fake,
            isBlockedByFriend: true,
          ),
        );
        await tester.pump();
        expect(find.byType(FriendRoomCard), findsOneWidget);
        final joinFinder = find.text('Join');
        expect(joinFinder, findsOneWidget);
        final container = tester.widget<Container>(
          find.ancestor(of: joinFinder, matching: find.byType(Container)).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, Colors.grey.shade200);
      },
    );

    testWidgets(
      'does not show FriendRoomCard when friend is offline even with room data',
      (tester) async {
        const roomStatus = FriendRoomStatus(
          roomId: 'abc12',
          memberCount: 3,
          maxUsers: 5,
          isLocked: false,
          mode: 'group',
        );
        final fake = _FakeFriendsNotifier(
          initial: FriendsState(
            friends: [_fakeDomainFriend],
            presenceMap: {'uid1': false},
            roomMap: {'uid1': roomStatus},
          ),
        );
        await tester.pumpWidget(
          _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
        );
        await tester.pump();
        expect(find.byType(FriendRoomCard), findsNothing);
      },
    );

    testWidgets('does not show FriendRoomCard when friend has no room', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          friends: [_fakeDomainFriend],
          presenceMap: {'uid1': true},
        ),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.byType(FriendRoomCard), findsNothing);
    });

    testWidgets('shows LayeredAvatar for each friend card', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.byType(LayeredAvatar), findsOneWidget);
    });

    testWidgets(
      'shows success dialog after removeFriend loading state clears',
      (tester) async {
        final notifier = _LoadingToIdleFriendsNotifier();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              networkInfoProvider.overrideWithValue(
                FakeNetworkInfo(isOnline: true),
              ),
              friendsNotifierProvider.overrideWith(() => notifier),
              avatarDecorationByUidProvider.overrideWith(
                (ref, uid) async => null,
              ),
              getUsersByIdsProvider.overrideWith((ref, csv) async => []),
              blockNotifierProvider.overrideWith(() => _FakeBlockNotifier()),
              profileByUidProvider.overrideWith((ref, uid) async => null),
            ],
            child: const MaterialApp(home: FriendsScreen()),
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Unfriend'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Friend Removed'), findsOneWidget);
      },
    );

    testWidgets('block dialog message does not promise server enforcement', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('will no longer be able to contact'),
        findsNothing,
      );
    });

    group('block limit', () {
      testWidgets(
        'shows confirm block dialog when fewer than 5 users are blocked',
        (tester) async {
          final fake = _FakeFriendsNotifier(
            initial: FriendsState(friends: [_fakeDomainFriend]),
          );
          await tester.pumpWidget(
            _build(
              networkInfo: FakeNetworkInfo(isOnline: true),
              notifier: fake,
            ),
          );
          await tester.pump();

          await tester.tap(find.byType(PopupMenuButton<String>));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Block'));
          await tester.pumpAndSettle();

          expect(find.text('Block "Alice"'), findsOneWidget);
        },
      );

      testWidgets('shows block limit dialog when 5 users are already blocked', (
        tester,
      ) async {
        final ts = DateTime(2024);
        final fake = _FakeFriendsNotifier(
          initial: FriendsState(friends: [_fakeDomainFriend]),
        );
        final blockFake = _FakeBlockNotifier(
          initial: BlockState(
            status: BlockStatus.loaded,
            blockedUsers: [
              BlockedUser(uid: 'b1', blockedAt: ts),
              BlockedUser(uid: 'b2', blockedAt: ts),
              BlockedUser(uid: 'b3', blockedAt: ts),
              BlockedUser(uid: 'b4', blockedAt: ts),
              BlockedUser(uid: 'b5', blockedAt: ts),
            ],
          ),
        );
        await tester.pumpWidget(
          _build(
            networkInfo: FakeNetworkInfo(isOnline: true),
            notifier: fake,
            blockNotifier: blockFake,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Block'));
        await tester.pumpAndSettle();

        expect(find.text('Block limit reached'), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _build(networkInfo: FakeNetworkInfo(isOnline: true)),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
