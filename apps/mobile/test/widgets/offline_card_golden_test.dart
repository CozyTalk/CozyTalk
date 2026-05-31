import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/offline_card.dart';

void main() {
  testWidgets('OfflineCard golden – renders icon, heading, subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: OfflineCard())),
        ),
      ),
    );
    await expectLater(
      find.byType(OfflineCard),
      matchesGoldenFile('goldens/offline_card.png'),
    );
  });
}
