import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/widgets.dart';

void main() {
  testWidgets('CozyCard golden – renders rounded card with child content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: CozyCard(child: Text('Hello, CozyTalk')),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(CozyCard),
      matchesGoldenFile('goldens/cozy_card.png'),
    );
  });
}
