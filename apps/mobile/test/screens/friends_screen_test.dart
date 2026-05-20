import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/friends_screen.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';
import 'package:mobile/shared/offline_card.dart';

class _FakeNetworkInfo implements NetworkInfo {
  final bool _isOnline;
  _FakeNetworkInfo({required bool isOnline}) : _isOnline = isOnline;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(_isOnline);

  @override
  Future<bool> get isConnected async => _isOnline;
}

Widget _build({required NetworkInfo networkInfo}) => ProviderScope(
  overrides: [networkInfoProvider.overrideWithValue(networkInfo)],
  child: const MaterialApp(home: FriendsScreen()),
);

void main() {
  group('FriendsScreen', () {
    testWidgets('renders without crash when online', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: _FakeNetworkInfo(isOnline: true)),
      );
      expect(find.byType(FriendsScreen), findsOneWidget);
    });

    testWidgets('shows OfflineCard when offline', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: _FakeNetworkInfo(isOnline: false)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsOneWidget);
    });

    testWidgets('does not show OfflineCard when online', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: _FakeNetworkInfo(isOnline: true)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsNothing);
    });

    testWidgets('mock friend entries visible when online', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: _FakeNetworkInfo(isOnline: true)),
      );
      await tester.pump();
      // Friend.displayName returns username, not name — first mock has username 'kaitom'.
      expect(find.text('kaitom', skipOffstage: false), findsOneWidget);
    });
  });
}
