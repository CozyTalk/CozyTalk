import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/offline_chip.dart';
import '../shared/fake_network_info.dart';

void main() {
  testWidgets('OfflineChip golden – offline state renders pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkInfoProvider.overrideWithValue(
            FakeNetworkInfo(isOnline: false),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: OfflineChip())),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(OfflineChip),
      matchesGoldenFile('goldens/offline_chip.png'),
    );
  });
}
