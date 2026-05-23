import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart' as domain;
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/screens/friends_screen.dart';
import 'package:mobile/shared/connectivity_provider.dart';
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
}) {
  final fake = notifier ?? _FakeFriendsNotifier();
  return ProviderScope(
    overrides: [
      networkInfoProvider.overrideWithValue(networkInfo),
      friendsNotifierProvider.overrideWith(() => fake),
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
  });
}
