import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/offline_card.dart';

import 'golden_tolerance.dart';

void main() {
  testWidgets('OfflineCard golden – renders icon, heading, subtitle', (
    tester,
  ) async {
    useGoldenTolerance('test/widgets/offline_card_golden_test.dart');
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
